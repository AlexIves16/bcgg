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

const MAX_MONSTERS = 20;
const MAX_CLOUDS = 10;
const SPAWN_RADIUS = 0.001;
const DESPAWN_DISTANCE = 2000; // Despawn if > 2km from any player

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

// Clear old map entities on start to prevent "Moscow monsters" blocking spawns
db.ref('map').remove();

// Игровой цикл на сервере (запускается каждые 5 секунд)
setInterval(async () => {
  // Try to get active players from RTDB to spawn things near them
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
    return; // Don't spawn fallback entities
  }

  // 0. Despawn far entities
  monsters = monsters.filter(monster => {
    return activePlayers.some(p => getDistance(monster.lat, monster.lng, p.lat, p.lng) < DESPAWN_DISTANCE);
  });

  clouds = clouds.filter(cloud => {
    return activePlayers.some(p => getDistance(cloud.lat, cloud.lng, p.lat, p.lng) < DESPAWN_DISTANCE);
  });

  // 1. Спавн монстров
  if (monsters.length < MAX_MONSTERS) {
    const target = activePlayers[Math.floor(Math.random() * activePlayers.length)];

    const shapes = ['circle', 'square', 'triangle'];
    const randomShape = shapes[Math.floor(Math.random() * shapes.length)];
    const energyCost = Math.floor(Math.random() * 3) * 10 + 10;

    const newMonster = {
      id: `monster_${monsterIdCounter++}`,
      type: 'wild_bug',
      hp: 100,
      requiredShape: randomShape,
      energyCost: energyCost,
      timeLimit: 15,
      lat: target.lat + randomOffset(SPAWN_RADIUS),
      lng: target.lng + randomOffset(SPAWN_RADIUS)
    };
    monsters.push(newMonster);
  }

  // 2. Спавн облаков
  if (clouds.length < MAX_CLOUDS) {
    const target = activePlayers[Math.floor(Math.random() * activePlayers.length)];

    const newCloud = {
      id: `cloud_${cloudIdCounter++}`,
      type: 'energy_cloud',
      capacity: Math.floor(Math.random() * 120) + 30,
      lat: target.lat + randomOffset(SPAWN_RADIUS),
      lng: target.lng + randomOffset(SPAWN_RADIUS)
    };
    clouds.push(newCloud);
  }

  // 3. AI Movement
  monsters.forEach(monster => {
    monster.lat += randomOffset(0.00003);
    monster.lng += randomOffset(0.00003);
  });

  clouds.forEach(cloud => {
    cloud.lat += randomOffset(0.00001);
    cloud.lng += randomOffset(0.00001);
  });

  // 4. Sync to DB
  await syncToFirebase();

  // Also keep Socket.IO for debugging
  io.emit('mapElementsUpdate', [...monsters, ...clouds]);

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
});

db.ref('players').on('child_changed', (snapshot) => {
  const p = snapshot.val();
  console.log(`[PLAYER] Updated: ${p.email} at ${p.lat}, ${p.lng}`);
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
