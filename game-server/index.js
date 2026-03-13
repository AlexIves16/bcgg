const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const cors = require('cors');
const path = require('path');
const fs = require('fs');
const admin = require('firebase-admin');
const { fetchOSMFeatures, resolveBiomeFromOSM } = require('./osm-service');

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
let objects = [];
let bases = [];
let monsterIdCounter = Date.now();
let cloudIdCounter = Date.now();
let objectIdCounter = Date.now();

// Default values (will be overridden by RTDB)
let configs = {
  maxMonsters: 20,
  maxClouds: 10,
  maxObjects: 30,
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
      objects = [];
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

    const objectsObj = {};
    objects.forEach(o => objectsObj[o.id] = o);

    const basesObj = {};
    bases.forEach(b => basesObj[b.id] = b);

    await db.ref('map').set({
      monsters: monstersObj,
      clouds: cloudsObj,
      objects: objectsObj,
      bases: basesObj,
      lastUpdate: Date.now()
    });
  } catch (err) {
    console.error('[FIREBASE] Sync error:', err);
  }
}

// Clear old map entities on start
db.ref('map').remove();

// Admin Spawn Settings (Weights)
let spawnSettings = {
  tree: 50,
  rock: 30,
  plant: 40,
  ore: 10,
  animal: 20,
  artifact: 5,
  structure: 15
};

// Sync spawnSettings from RTDB so it persists across server restarts
db.ref('admin/spawnSettings').once('value').then(snap => {
  if (snap.exists()) {
    spawnSettings = { ...spawnSettings, ...snap.val() };
  } else {
    // Write defaults if not existing
    db.ref('admin/spawnSettings').set(spawnSettings);
  }
});

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

  // Load Bases from RTDB
  try {
    const baseSnap = await db.ref('bases').once('value');
    if (baseSnap.exists()) {
      bases = Object.values(baseSnap.val());
    } else {
      bases = [];
    }
  } catch (err) {
    console.error('[FIREBASE] Error fetching bases:', err);
  }

  // Load OSM data for player areas (optimized with grid-snapping in service)
  for (const player of activePlayers) {
    player.osmData = await fetchOSMFeatures(player.lat, player.lng);
  }

  // 0. Despawn far entities
  monsters = monsters.filter(monster => {
    return activePlayers.some(p => getDistance(monster.lat, monster.lng, p.lat, p.lng) < configs.despawnDistance);
  });

  clouds = clouds.filter(cloud => {
    return activePlayers.some(p => getDistance(cloud.lat, cloud.lng, p.lat, p.lng) < configs.despawnDistance);
  });

  // 1. Aggro Check
  for (const monster of monsters) {
    if (monster.aggressiveness > 0) {
      for (const player of activePlayers) {
        const dist = getDistance(monster.lat, monster.lng, player.lat, player.lng);
        if (dist <= (monster.aggroRadius || 20)) {
          // Check for cooldown to avoid spamming ambushes
          const lastAmbush = player.lastAmbushTime || 0;
          
          // --- SAFE ZONE CHECK ---
          const inSafeZone = bases.some(b => getDistance(player.lat, player.lng, b.lat, b.lng) < (b.safeRadius || 50));
          
          if (!inSafeZone && (Date.now() - lastAmbush > 30000)) { // 30s cooldown
            console.log(`[AGGRO] Monster ${monster.name} (${monster.rank}) ambushing ${player.email}!`);
            db.ref(`players/${player.uid}/ambush`).set({
              monsterId: monster.id,
              timestamp: Date.now(),
              monster: monster.getData()
            });
            player.lastAmbushTime = Date.now();
          }
        }
      }
    }
  }

  objects = objects.filter(obj => {
    return activePlayers.some(p => getDistance(obj.lat, obj.lng, p.lat, p.lng) < configs.despawnDistance);
  });

  // 2. Spawning strategy
  activePlayers.forEach(player => {
    const monstersNear = monsters.filter(m => getDistance(m.lat, m.lng, player.lat, player.lng) < 500).length;
    const cloudsNear = clouds.filter(c => getDistance(c.lat, c.lng, player.lat, player.lng) < 500).length;

    // Spawn monsters near this player if under cap
    const inSafeZone = bases.some(b => getDistance(player.lat, player.lng, b.lat, b.lng) < (b.safeRadius || 50));

    if (monsters.length < configs.maxMonsters && monstersNear < 5 && !inSafeZone) {
      const availableTypes = [];
      const bEnabled = configs.basicMobsEnabled !== false;
      const sEnabled = configs.sonicMobsEnabled === true || configs.sonicMobsEnabled === undefined;
      const vEnabled = configs.vocalMobsEnabled === true || configs.vocalMobsEnabled === undefined;

      if (bEnabled) {
          availableTypes.push({ type: 'wild-bug', name: 'Wild Bug', isSound: false });
          availableTypes.push({ type: 'golem', name: 'Stone Golem', isSound: false });
      }
      if (sEnabled) {
          availableTypes.push({ type: 'banshee', name: 'Sonic Banshee', isSound: true, subtype: 'note' });
          availableTypes.push({ type: 'wraith', name: 'Ghostly Wraith', isSound: true, subtype: 'note' });
      }
      if (vEnabled) {
          availableTypes.push({ type: 'siren', name: 'Vocal Siren', isSound: true, subtype: 'vowel' });
          availableTypes.push({ type: 'elemental', name: 'Wind Elemental', isSound: true, subtype: 'vowel' });
      }

      // Fallback if none enabled
      if (availableTypes.length === 0) availableTypes.push({ type: 'wild-bug', name: 'Wild Bug', isSound: false });

      const mob = availableTypes[Math.floor(Math.random() * availableTypes.length)];

      const shapes = ['circle', 'square', 'triangle'];
      const randomShape = shapes[Math.floor(Math.random() * shapes.length)];
      
      // Determine Rank
      const roll = Math.random();
      let rank = 'normal';
      let hpMult = 1;
      let seqLength = 1;
      let powerMult = 1;
      if (roll > 0.98) { rank = 'epic'; hpMult = 5; seqLength = 3; powerMult = 3; }
      else if (roll > 0.90) { rank = 'ancient'; hpMult = 3; seqLength = 2; powerMult = 2; }
      else if (roll > 0.75) { rank = 'strong'; hpMult = 1.5; seqLength = 1; powerMult = 1.5; }

      // Assign Attack Pattern
      let attackType = 'projectile';
      let attackPower = 10 * powerMult;
      let attackInterval = 3000; // ms

      // Re-evaluate attackInterval and attackPower based on rank
      attackInterval = rank == 'epic' ? 2000 : (rank == 'ancient' ? 3000 : 4000);
      attackPower = rank == 'epic' ? 30 : (rank == 'ancient' ? 20 : 10);
      
      // Aggressiveness: 0.1 (low) to 0.8 (high)
      const aggressiveness = rank == 'epic' ? 0.8 : (rank == 'ancient' ? 0.5 : (Math.random() > 0.8 ? 0.3 : 0.05));
      const aggroRadius = rank == 'epic' ? 50 : (rank == 'ancient' ? 35 : 20);

      if (mob.type === 'golem') {
          attackType = 'burst';
          attackInterval = 5000;
          attackPower = 25 * powerMult;
      } else if (mob.type === 'wraith') {
          attackType = 'proximity_aura';
          attackInterval = 1000;
          attackPower = 5 * powerMult;
      } else if (mob.type === 'banshee' || mob.type === 'siren') {
          attackType = 'gaze';
          attackInterval = 4000;
      }

      // Generate Multi-Gesture Sequence
      const sequence = [];
      for (let i = 0; i < seqLength; i++) {
          sequence.push(shapes[Math.floor(Math.random() * shapes.length)]);
      }

      monsters.push({
        id: `monster_${monsterIdCounter++}`,
        type: mob.type, // uses 'wild-bug', 'banshee', etc. from shared
        name: `${rank.toUpperCase()} ${mob.name}`,
        rank: rank,
        isSound: mob.isSound,
        hp: Math.floor(100 * hpMult),
        requiredShape: sequence[0], // current active shape
        combatSequence: sequence,
        attackType: attackType,
        subtype: mob.subtype || null,
        attackPower: Math.floor(attackPower),
        attackInterval: attackInterval,
        energyCost: Math.floor((Math.random() * 3 + 1) * 10 * hpMult),
        timeLimit: rank === 'normal' ? 15 : (rank === 'strong' ? 20 : 30), // More time for longer sequences
        lat: player.lat + randomOffset(configs.spawnRadius),
        lng: player.lng + randomOffset(configs.spawnRadius)
      });
      console.log(`[GAME] Spawned ${rank} ${mob.type} (${attackType}) near ${player.email}`);
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

    // Spawn objects near this player if under cap
    const objectsNear = objects.filter(o => getDistance(o.lat, o.lng, player.lat, player.lng) < 500).length;
    if (objects.length < configs.maxObjects && objectsNear < 10) {
      const playerLat = player.lat + randomOffset(configs.spawnRadius);
      const playerLng = player.lng + randomOffset(configs.spawnRadius);
      const biome = resolveBiomeFromOSM(playerLat, playerLng, player.osmData);

      const biomeMapping = {
        'B_FOREST': [
          { type: 'tree', id: 'oak-001', name: 'Oak Tree' },
          { type: 'tree', id: 'pine-001', name: 'Pine Tree' },
          { type: 'animal', id: 'rabbit-001', name: 'Rabbit' }
        ],
        'B_OCEAN': [
          { type: 'plant', id: 'reed-001', name: 'Reeds' },
          { type: 'animal', id: 'fish-001', name: 'Fish' }
        ],
        'B_MOUNTAINS': [
          { type: 'ore', id: 'iron-001', name: 'Iron Ore' },
          { type: 'rock', id: 'large-rock-001', name: 'Large Rock' },
          { type: 'animal', id: 'wolf-001', name: 'Wolf' }
        ],
        'B_PLAINS': [
          { type: 'structure', id: 'ruins-001', name: 'Old Ruins' },
          { type: 'plant', id: 'grass-001', name: 'Wild Grass' },
          { type: 'artifact', id: 'ancient-relic-001', name: 'Ancient Relic' }
        ]
      };

      const templates = biomeMapping[biome] || biomeMapping['B_PLAINS'];
      
      // Calculate total weight
      let totalWeight = 0;
      templates.forEach(t => { 
        totalWeight += (spawnSettings[t.type] !== undefined ? spawnSettings[t.type] : 10);
      });

      // Select template based on weights
      let randomVal = Math.random() * totalWeight;
      let template = templates[0];
      for (let t of templates) {
        let weight = (spawnSettings[t.type] !== undefined ? spawnSettings[t.type] : 10);
        if (randomVal < weight) {
          template = t;
          break;
        }
        randomVal -= weight;
      }
      
      objects.push({
        id: `obj_${objectIdCounter++}`,
        type: template.type,
        objectTypeId: template.id,
        name: template.name,
        lat: playerLat,
        lng: playerLng,
        biome: biome
      });
      console.log(`[GAME] Spawned ${template.name} in ${biome} near ${player.email}`);
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
    const killedMonster = monsters.find(m => m.id === action.monsterId);
    if (killedMonster) {
      console.log(`[GAME] ${action.uid} killed ${killedMonster.type} (${killedMonster.rank || 'normal'})`);
      
      // Update Persistent Kill Counter in Firestore
      try {
        const userRef = firestore.collection('users').doc(action.uid);
        const rankField = killedMonster.rank || 'normal';
        const typeField = killedMonster.type || 'unknown';

        await userRef.update({
          [`stats.killsByRank.${rankField}`]: admin.firestore.FieldValue.increment(1),
          [`stats.killsByType.${typeField}`]: admin.firestore.FieldValue.increment(1),
          'stats.totalKills': admin.firestore.FieldValue.increment(1),
          'lastActivity': admin.firestore.FieldValue.serverTimestamp()
        });

        // Check for Achievements
        const doc = await userRef.get();
        const stats = doc.data().stats || {};
        const total = stats.totalKills || 0;
        
        const badges = [];
        if (total >= 10) badges.push('Slayer V');
        if (total >= 100) badges.push('Monster Hunter IV');
        if (total >= 1000) badges.push('Legendary Warrior III');

        if (badges.length > 0) {
          await userRef.update({ achievements: admin.firestore.FieldValue.arrayUnion(...badges) });
        }

        console.log(`[LOOT] Spawning loot bundle for ${action.uid} from ${killedMonster.name}`);
        objects.push({
          id: `loot_${objectIdCounter++}`,
          type: 'loot',
          objectTypeId: 'loot-bundle',
          name: 'Monster Loot',
          lat: killedMonster.lat,
          lng: killedMonster.lng,
          items: [
            { itemId: drop, amount: amount }
          ],
          ownerId: action.uid,
          createdAt: Date.now()
        });

      } catch (err) {
        console.error('[FIRESTORE] Kill track error:', err);
      }
    }

    monsters = monsters.filter(m => m.id !== action.monsterId);
    await syncToFirebase();
  } else if (action.type === 'mineEnergy') {
    const idx = clouds.findIndex(c => c.id === action.cloudId);
    if (idx !== -1) {
      clouds[idx].capacity -= action.amount;
      if (clouds[idx].capacity <= 0) clouds.splice(idx, 1);
      await syncToFirebase();
    }
  } else if (action.type === 'establishBase') {
    // Check if player already has a base
    const existingBaseIdx = bases.findIndex(b => b.ownerId === action.uid);
    if (existingBaseIdx !== -1) {
      console.log(`[BASE] ${action.username} already has a base.`);
      return; // Prevent multiple bases
    }
    
    bases.push({
      id: `base_${action.uid}`,
      type: 'base',
      name: `${action.username}'s Home`,
      ownerId: action.uid,
      ownerEmail: action.email,
      lat: action.lat,
      lng: action.lng,
      level: 1, // Start at level 1 (Camp)
      safeRadius: 50
    });
    
    // Persistent storage for bases
    await db.ref(`bases/base_${action.uid}`).set(bases[bases.length - 1]);
    await syncToFirebase();
    console.log(`[BASE] ${action.username} established Primary Camp at ${action.lat}, ${action.lng}`);
  } else if (action.type === 'upgradeBase') {
    const base = bases.find(b => b.ownerId === action.uid);
    if (base) {
      const currentLevel = base.level || 1;
      if (currentLevel < 3) {
        try {
          // Check inventory for materials
          const reqWood = currentLevel === 1 ? 10 : 25;
          const reqStone = currentLevel === 1 ? 5 : 15;
          const userRef = firestore.collection('users').doc(action.uid);
          const doc = await userRef.get();
          const inventory = doc.data().inventory || {};

          if ((inventory['wood'] || 0) >= reqWood && (inventory['stone'] || 0) >= reqStone) {
            // Consume materials
            await userRef.update({
              'inventory.wood': admin.firestore.FieldValue.increment(-reqWood),
              'inventory.stone': admin.firestore.FieldValue.increment(-reqStone)
            });

            base.level = currentLevel + 1;
            base.safeRadius += 10;
            await db.ref(`bases/base_${action.uid}`).update({ level: base.level, safeRadius: base.safeRadius });
            await syncToFirebase();
            console.log(`[BASE] ${action.uid} upgraded base to level ${base.level}`);
          } else {
             console.log(`[BASE] ${action.uid} lacks materials for upgrade.`);
          }
        } catch(err) {
           console.error('[BASE] Upgrade error:', err);
        }
      }
    }
  } else if (action.type === 'inviteToBase') {
    const base = bases.find(b => b.ownerId === action.uid);
    if (base) {
      try {
        // Invite by email or username
        const queryStr = action.targetIdentifier.toLowerCase();
        let targetUid = null;
        
        // Search by email first
        let querySnapshot = await firestore.collection('users').where('email', '==', queryStr).limit(1).get();
        if (querySnapshot.empty) {
          // Search by username
          querySnapshot = await firestore.collection('users').where('username', '==', action.targetIdentifier).limit(1).get();
        }

        if (!querySnapshot.empty) {
          targetUid = querySnapshot.docs[0].id;
        }

        if (targetUid) {
          if (!base.allowedPlayers) base.allowedPlayers = [];
          if (!base.allowedPlayers.includes(targetUid)) {
            base.allowedPlayers.push(targetUid);
            // Persist to specific base node
            await db.ref(`bases/base_${action.uid}/allowedPlayers`).set(base.allowedPlayers);
            await syncToFirebase();
            console.log(`[BASE] ${action.uid} invited ${targetUid} to base.`);
          }
        } else {
          console.log(`[BASE] User ${action.targetIdentifier} not found for invite.`);
        }
      } catch (err) {
        console.error('[BASE] Invite error:', err);
      }
    }
  } else if (action.type === 'collectLoot') {
    const lootIdx = objects.findIndex(o => o.id === action.lootId);
    if (lootIdx !== -1) {
      const loot = objects[lootIdx];
      // Distance check (5m)
      const dist = getDistance(action.lat, action.lng, loot.lat, loot.lng);
      if (dist <= 10) { // 10m range
        try {
          const userRef = firestore.collection('users').doc(action.uid);
          const updates = {};
          loot.items.forEach(item => {
            updates[`inventory.${item.itemId}`] = admin.firestore.FieldValue.increment(item.amount);
          });
          await userRef.update(updates);
          console.log(`[LOOT] ${action.uid} collected loot ${action.lootId}`);
          objects.splice(lootIdx, 1);
          await syncToFirebase();
        } catch (err) {
          console.error('[LOOT] Collection error:', err);
        }
      } else {
        console.log(`[LOOT] ${action.uid} too far from loot: ${dist.toFixed(1)}m`);
      }
    }
  } else if (action.type === 'craftItem') {
    // Recipe logic (using the one defined in shared-library)
    // For simplicity, we define the recipes here as well or import them
    const recipes = [
      { id: 'craft_wall_wood', ingredients: { 'fiber': 5, 'shard': 2 }, output: 'wall-wood', isBuilding: true },
      { id: 'craft_torch', ingredients: { 'essence': 3, 'shard': 1 }, output: 'torch-ether', isBuilding: true },
      { id: 'craft_workbench', ingredients: { 'fiber': 10, 'shard': 5, 'meat': 2 }, output: 'workbench', isBuilding: true },
      { id: 'craft_axe_wood', ingredients: { 'fiber': 5, 'shard': 3 }, output: 'axe-wood', isBuilding: false, requiresWorkbench: true },
      { id: 'craft_pickaxe_wood', ingredients: { 'fiber': 5, 'shard': 3 }, output: 'pickaxe-wood', isBuilding: false, requiresWorkbench: true },
    ];
    
    const recipe = recipes.find(r => r.id === action.recipeId);
    if (recipe) {
      try {
        const userRef = firestore.collection('users').doc(action.uid);
        const doc = await userRef.get();
        const inventory = doc.data().inventory || {};
        
        // Check ingredients
        let canCraft = true;
        for (const [itemId, amount] of Object.entries(recipe.ingredients)) {
          if ((inventory[itemId] || 0) < amount) {
            canCraft = false;
            break;
          }
        }
        
        if (canCraft) {
          if (recipe.isBuilding) {
            // Restriction: Must be within 50m of a base owned by player or shared with them
            const nearbyBase = bases.find(b => {
              const dist = getDistance(action.lat, action.lng, b.lat, b.lng);
              const isOwner = b.ownerId === action.uid;
              const isAllowed = (b.allowedPlayers || []).includes(action.uid);
              return dist <= 50 && (isOwner || isAllowed);
            });

            if (!nearbyBase) {
              console.log(`[CRAFT] ${action.uid} building blocked: Not in a safe zone.`);
              return; // Halt crafting
            }
          }

          if (recipe.requiresWorkbench) {
            // Check if player is near a Workbench (10m)
            const nearbyWorkbench = objects.find(o => {
              return o.objectTypeId === 'workbench' && getDistance(action.lat, action.lng, o.lat, o.lng) <= 10;
            });
            if (!nearbyWorkbench) {
              console.log(`[CRAFT] ${action.uid} craft blocked: Workbench required.`);
              return;
            }
          }

          // Consume ingredients
          const consumes = {};
          for (const [itemId, amount] of Object.entries(recipe.ingredients)) {
            consumes[`inventory.${itemId}`] = admin.firestore.FieldValue.increment(-amount);
          }
          await userRef.update(consumes);
          
          if (recipe.isBuilding) {
            // Spawn building at player location
            objects.push({
              id: `build_${objectIdCounter++}`,
              type: 'building',
              objectTypeId: recipe.output,
              name: recipe.output.replace('-', ' '),
              lat: action.lat,
              lng: action.lng,
              ownerId: action.uid,
              health: 500,
              createdAt: Date.now()
            });
            console.log(`[CRAFT] ${action.uid} built ${recipe.output}`);
          } else {
            // Add to inventory
            await userRef.update({
              [`inventory.${recipe.output}`]: admin.firestore.FieldValue.increment(1)
            });
            console.log(`[CRAFT] ${action.uid} crafted ${recipe.output}`);
          }
          await syncToFirebase();
        }
      } catch (err) {
        console.error('[CRAFT] error:', err);
      }
    }
  } else if (action.type === 'equipTool') {
    try {
      const userRef = firestore.collection('users').doc(action.uid);
      await userRef.update({
        'equipment.tool': action.itemId,
        'lastActivity': admin.firestore.FieldValue.serverTimestamp()
      });
      console.log(`[EQUIP] ${action.uid} equipped ${action.itemId}`);
    } catch (err) {
      console.error('[EQUIP] error:', err);
    }
  } else if (action.type === 'harvest') {
    try {
      const userRef = firestore.collection('users').doc(action.uid);
      const doc = await userRef.get();
      const userData = doc.data();
      const equippedTool = userData.equipment?.tool || null;

      // Simple distance check
      const dist = getDistance(action.lat, action.lng, action.targetLat, action.targetLng);
      if (dist > 10) {
        console.log(`[HARVEST] ${action.uid} too far: ${dist.toFixed(1)}m`);
        return;
      }

      let yieldAmount = 1;
      let resourceId = 'fiber';

      if (action.targetType === 'tree') {
        if (equippedTool === 'axe-wood') yieldAmount = 5;
        resourceId = 'wood';
      } else if (action.targetType === 'rock' || action.targetType === 'ore') {
        if (equippedTool === 'pickaxe-wood') yieldAmount = 5;
        resourceId = 'stone';
      }

      await userRef.update({
        [`inventory.${resourceId}`]: admin.firestore.FieldValue.increment(yieldAmount),
        'lastActivity': admin.firestore.FieldValue.serverTimestamp()
      });
      console.log(`[HARVEST] ${action.uid} harvested ${yieldAmount} ${resourceId}`);
    } catch (err) {
      console.error('[HARVEST] error:', err);
    }
  } else if (action.type === 'getSpawnSettings') {
    // Send current spawn settings directly back via RTDB
    db.ref(`admin_responses/${action.uid}/spawnSettings`).set(spawnSettings);
  } else if (action.type === 'updateSpawnSettings') {
    // Expected payload: action.settings is an object mapping types to weights
    if (action.settings) {
      spawnSettings = { ...spawnSettings, ...action.settings };
      console.log(`[ADMIN] Spawn Settings updated by ${action.uid}:`, spawnSettings);
      
      // Persist to RTDB so all admins get real-time UI updates
      db.ref('admin/spawnSettings').set(spawnSettings);
    }
  } else if (action.type === 'regenerateObjects') {
    console.log(`[ADMIN] ${action.uid} requested object regeneration.`);
    // 1. Clear all objects that aren't currently being interacted with / Keep loot separate
    objects = objects.filter(o => o.type === 'loot'); // Keep only loot
    
    // 2. We don't need to manually re-populate here, the very next server Heartbeat
    // will see that objects.length < configs.maxObjects and will re-populate 
    // the areas around active players using the NEW spawnSettings weights.
    
    await syncToFirebase();
    console.log(`[ADMIN] Objects cleared for regeneration.`);
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

// --- NEW: P2P Chat & Signaling Monitor (For Debugging) ---
db.ref('groups').on('child_added', (snapshot) => {
  console.log(`[CONVO] New group created: ${snapshot.key}`);
});

db.ref('groups').on('value', (snapshot) => {
  const groups = snapshot.val();
  if (!groups) return;
  Object.keys(groups).forEach(gid => {
    const peerCount = Object.keys(groups[gid].peers || {}).length;
    if (peerCount > 0) {
      console.log(`[CONVO] Group ${gid} active with ${peerCount} peers.`);
    }
  });
});

db.ref('signaling').on('value', (snapshot) => {
  const val = snapshot.val();
  if (val) {
    const targets = Object.keys(val).length;
    // console.log(`[P2P] Signaling node status: ${targets} targets active.`);
  }
});

db.ref('signaling').on('child_added', (snapshot) => {
  const targetUid = snapshot.key;
  // Listen to each peer's signaling queue under this target
  snapshot.ref.on('child_added', (peerSnapshot) => {
    const senderUid = peerSnapshot.key;
    // Listen to individual pushed messages in the queue
    peerSnapshot.ref.on('child_added', (msgSnapshot) => {
      const data = msgSnapshot.val();
      const type = data.offer ? 'OFFER' : (data.answer ? 'ANSWER' : (data.ice ? 'ICE' : 'DATA'));
      // console.log(`[P2P] HANDSHAKE: ${senderUid.substring(0, 6)} -> ${targetUid.substring(0, 6)} [${type}]`);
    });
  });
});

db.ref('invitations').on('child_added', (snapshot) => {
  const targetUid = snapshot.key;
  snapshot.ref.on('child_added', (innerSnapshot) => {
    const senderUid = innerSnapshot.key;
    console.log(`[P2P] INVITE: ${senderUid.substring(0, 6)} -> ${targetUid.substring(0, 6)}`);
  });
});
// ---------------------------------------------------------

io.on('connection', (socket) => {
  console.log(`Socket Debug Connection: ${socket.id}`);
});

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(`Game Server running on port ${PORT}`);
});
