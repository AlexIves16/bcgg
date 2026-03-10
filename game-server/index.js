const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const cors = require('cors');
const path = require('path');
const fs = require('fs');
const admin = require('firebase-admin');

const app = express();
app.use(cors());

// Initialize Firebase Admin
const serviceAccount = require("./firebase-service-account.json");
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: "https://game26-base-default-rtdb.europe-west1.firebasedatabase.app/"
});

const db = admin.database();
const firestore = admin.firestore();

/**
 * Ensures player exists in Firestore 'users' collection (persistent Player Table)
 */
async function registerPlayerInFirestore(player) {
  if (!player || !player.uid || !player.email) return;
  try {
    const emailLower = player.email.toLowerCase();
    const userRef = firestore.collection('users').doc(player.uid);
    const doc = await userRef.get();

    if (!doc.exists) {
      console.log(`[FIRESTORE] Creating NEW registry entry for: ${emailLower}`);
      await userRef.set({
        email: emailLower,
        username: player.username || player.email.split('@')[0],
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        lastSeen: admin.firestore.FieldValue.serverTimestamp(),
        source: 'server_auto_reg'
      });
    } else {
      // Update email to lowercase if needed and refresh lastSeen
      await userRef.update({
        email: emailLower,
        lastSeen: admin.firestore.FieldValue.serverTimestamp()
      });
    }
  } catch (err) {
    console.error(`[FIRESTORE] Sync error for ${player.email}:`, err);
  }
}

// Раздача статики для APK-файлов (OTA обновления)
app.use('/download', express.static(path.join(__dirname, 'public')));

// Health check root
app.get('/', (req, res) => res.json({ status: 'ok', name: 'Digital Ether Game Server (RTDB Sync Active)' }));

const server = http.createServer(app);
const io = new Server(server, {
  cors: { origin: '*', methods: ['GET', 'POST'] },
  transports: ['polling', 'websocket']
});

// Хранилище монстров и облаков
let monsters = [];
let clouds = [];
let monsterIdCounter = Date.now();
let cloudIdCounter = Date.now();

// Default values (will be overridden by RTDB)
let configs = {
  maxMonsters: 20,
  maxClouds: 10,
  spawnRadius: 0.001,
  despawnDistance: 1000,
  visibilityRadius: 300,
  basicMobsEnabled: true,
  sonicMobsEnabled: true,
  vocalMobsEnabled: true
};

// Listen for admin settings
db.ref('admin_settings').on('value', (snapshot) => {
  const newConfig = snapshot.val();
  if (newConfig) {
    configs = { ...configs, ...newConfig };
    console.log('[CONFIG] Updated settings:', configs);

    // Handle immediate reset
    if (newConfig.resetTrigger) {
      console.log('[CONFIG] Reset triggered!');
      monsters = [];
      clouds = [];
      db.ref('admin_settings/resetTrigger').set(false);
      syncToFirebase();
    }
  }
});

function randomOffset(radius) {
  return (Math.random() - 0.5) * radius * 2;
}

// Distance helper
function getDistance(lat1, lon1, lat2, lon2) {
  const R = 6371000;
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

// Sync entities to Firebase RTDB
async function syncToFirebase() {
  try {
    const monstersObj = {};
    monsters.forEach(m => monstersObj[m.id] = m);

    const cloudsObj = {};
    clouds.forEach(c => cloudsObj[c.id] = c);

    await db.ref('map').set({
      monsters: monstersObj,
      clouds: cloudsObj,
      lastUpdate: Date.now()
    });
  } catch (err) {
    console.error('[FIREBASE] Sync error:', err);
  }
}

// Clear old map entities on start
db.ref('map').remove();

// Игровой цикл на сервере (запускается каждые 5 секунд)
setInterval(async () => {
  let activePlayers = [];
  try {
    const snapshot = await db.ref('players').once('value');
    if (snapshot.exists()) {
      activePlayers = Object.values(snapshot.val());
    }
  } catch (err) {
    console.error('[FIREBASE] Error fetching players:', err);
  }

  if (activePlayers.length === 0) {
    console.log('[GAME] Waiting for players to join...');
    return;
  }

  console.log(`[GAME] Heartbeat: ${activePlayers.length} players active.`);

  // 0. Despawn far entities
  monsters = monsters.filter(monster => {
    return activePlayers.some(p => getDistance(monster.lat, monster.lng, p.lat, p.lng) < configs.despawnDistance);
  });

  clouds = clouds.filter(cloud => {
    return activePlayers.some(p => getDistance(cloud.lat, cloud.lng, p.lat, p.lng) < configs.despawnDistance);
  });

  // 1. Spawning strategy: Ensure each player has at least 5 monsters near them if possible
  activePlayers.forEach(player => {
    const monstersNear = monsters.filter(m => getDistance(m.lat, m.lng, player.lat, player.lng) < 500).length;
    const cloudsNear = clouds.filter(c => getDistance(c.lat, c.lng, player.lat, player.lng) < 500).length;

    // Spawn monsters near this player if under cap
    if (monsters.length < configs.maxMonsters && monstersNear < 5) {
      const availableTypes = [];
      const bEnabled = configs.basicMobsEnabled !== false;
      const sEnabled = configs.sonicMobsEnabled === true || configs.sonicMobsEnabled === undefined;
      const vEnabled = configs.vocalMobsEnabled === true || configs.vocalMobsEnabled === undefined;

      if (bEnabled) availableTypes.push({ type: 'wild_bug', name: 'Wild Bug', isSound: false });
      if (sEnabled) availableTypes.push({ type: 'banshee', name: 'Sonic Banshee', isSound: true });
      if (vEnabled) availableTypes.push({ type: 'siren', name: 'Vocal Siren', isSound: true });

      // Fallback if none enabled
      if (availableTypes.length === 0) availableTypes.push({ type: 'wild_bug', name: 'Wild Bug', isSound: false });

      const mob = availableTypes[Math.floor(Math.random() * availableTypes.length)];

      const shapes = ['circle', 'square', 'triangle'];
      const randomShape = shapes[Math.floor(Math.random() * shapes.length)];

      monsters.push({
        id: `monster_${monsterIdCounter++}`,
        type: mob.type,
        name: mob.name,
        isSound: mob.isSound,
        hp: 100,
        requiredShape: randomShape,
        energyCost: Math.floor(Math.random() * 3) * 10 + 10,
        timeLimit: 15,
        lat: player.lat + randomOffset(configs.spawnRadius),
        lng: player.lng + randomOffset(configs.spawnRadius)
      });
      console.log(`[GAME] Spawned ${mob.type} (B:${bEnabled}, S:${sEnabled}, V:${vEnabled}) near ${player.email}`);
    }

    // Spawn clouds near this player if under cap
    if (clouds.length < configs.maxClouds && cloudsNear < 3) {
      clouds.push({
        id: `cloud_${cloudIdCounter++}`,
        type: 'energy_cloud',
        capacity: Math.floor(Math.random() * 120) + 30,
        lat: player.lat + randomOffset(configs.spawnRadius),
        lng: player.lng + randomOffset(configs.spawnRadius)
      });
      console.log(`[GAME] Spawned cloud near ${player.email}`);
    }
  });

  // 2. AI Movement
  monsters.forEach(monster => {
    monster.lat += randomOffset(0.00003);
    monster.lng += randomOffset(0.00003);
  });

  clouds.forEach(cloud => {
    cloud.lat += randomOffset(0.00001);
    cloud.lng += randomOffset(0.00001);
  });

  // 3. Sync to DB
  await syncToFirebase();

}, 5000);

// Listen for action requests via RTDB (fallback for sockets)
db.ref('actions').on('child_added', async (snapshot) => {
  const action = snapshot.val();
  if (!action) return;

  console.log(`[ACTION] Received ${action.type} from ${action.uid}`);

  if (action.type === 'killMonster') {
    monsters = monsters.filter(m => m.id !== action.monsterId);
    await syncToFirebase();
  } else if (action.type === 'mineEnergy') {
    const idx = clouds.findIndex(c => c.id === action.cloudId);
    if (idx !== -1) {
      clouds[idx].capacity -= action.amount;
      if (clouds[idx].capacity <= 0) clouds.splice(idx, 1);
      await syncToFirebase();
    }
  }

  // Delete action after processing
  await snapshot.ref.remove();
});

// Listen for player updates in RTDB
db.ref('players').on('child_added', (snapshot) => {
  const p = snapshot.val();
  console.log(`[PLAYER] Joined: ${p.email} (${p.uid})`);
  registerPlayerInFirestore(p);
});

db.ref('players').on('child_changed', (snapshot) => {
  const p = snapshot.val();
  // We don't log every move to avoid spam, but we register periodically
  if (Math.random() < 0.1) { // 10% chance to sync on update to avoid heavy traffic
    registerPlayerInFirestore(p);
  }
});

db.ref('players').on('child_removed', (snapshot) => {
  console.log(`[PLAYER] Left: ${snapshot.key}`);
});

io.on('connection', (socket) => {
  console.log(`Socket Debug Connection: ${socket.id}`);
});

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(`Game Server running on port ${PORT}`);
});
