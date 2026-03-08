const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const cors = require('cors');
const path = require('path');
const fs = require('fs');

const app = express();
app.use(cors());

// Раздача статики для APK-файлов (OTA обновления)
app.use('/download', express.static(path.join(__dirname, 'public')));

// Эндпоинт для проверки версии API
app.get('/api/version', (req, res) => {
  try {
    const versionPath = path.join(__dirname, 'version.json');
    if (fs.existsSync(versionPath)) {
      const versionData = JSON.parse(fs.readFileSync(versionPath, 'utf8'));
      // Добавляем URL на скачивание базируясь на текущем хосте (ngrok url)
      const downloadUrl = `https://${req.get('host')}/download/app-release.apk`;
      res.json({ ...versionData, url: downloadUrl });
    } else {
      res.json({ version: 1, url: `https://${req.get('host')}/download/app-release.apk` });
    }
  } catch (error) {
    console.error("Error reading version.json:", error);
    res.status(500).json({ error: "Could not read version" });
  }
});

const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST']
  }
});

// Хранилище игроков и монстров в оперативной памяти сервера
const players = {};
let monsters = [];
let clouds = [];
let monsterIdCounter = 1;
let cloudIdCounter = 1;

// Настройки генерации
const MAX_MONSTERS = 10;
const MAX_CLOUDS = 5;
const SPAWN_RADIUS = 0.002; // Радиус спавна около игрока в градусах (~200 метров)

// Простой генератор случайных чисел в заданном диапазоне
function randomOffset(radius) {
  return (Math.random() - 0.5) * radius * 2;
}

// Игровой цикл на сервере (запускается каждые 5 секунд)
setInterval(() => {
  const activePlayers = Object.values(players);
  if (activePlayers.length === 0) return; // Если никого нет, ничего не делаем

  // 1. Спавн монстров (если их меньше максимума)
  if (monsters.length < MAX_MONSTERS) {
    // Выбираем случайного игрока для спавна монстра
    const targetPlayer = activePlayers[Math.floor(Math.random() * activePlayers.length)];

    // Выдаем монстру случайную фигуру для победы над ним
    const shapes = ['circle', 'square', 'triangle'];
    const randomShape = shapes[Math.floor(Math.random() * shapes.length)];
    const energyCost = Math.floor(Math.random() * 3) * 10 + 10; // 10, 20, or 30

    // Создаем монстра чуть в стороне от игрока
    const newMonster = {
      id: `monster_${monsterIdCounter++}`,
      type: 'wild_bug',
      hp: 100,
      requiredShape: randomShape,
      energyCost: energyCost,
      timeLimit: 15, // 15 секунд на рисование
      lat: targetPlayer.lat + randomOffset(SPAWN_RADIUS),
      lng: targetPlayer.lng + randomOffset(SPAWN_RADIUS)
    };
    monsters.push(newMonster);
    console.log(`[GAME ENGINE] Spawned ${randomShape} monster ${newMonster.id} (Cost: ${energyCost}) near ${targetPlayer.email || targetPlayer.uid}`);
  }

  // Спавн облаков энергии
  if (clouds.length < MAX_CLOUDS) {
    const targetPlayer = activePlayers[Math.floor(Math.random() * activePlayers.length)];
    const capacity = Math.floor(Math.random() * 120) + 30; // 30 to 149

    const newCloud = {
      id: `cloud_${cloudIdCounter++}`,
      type: 'energy_cloud',
      capacity: capacity,
      lat: targetPlayer.lat + randomOffset(SPAWN_RADIUS),
      lng: targetPlayer.lng + randomOffset(SPAWN_RADIUS)
    };
    clouds.push(newCloud);
    console.log(`[GAME ENGINE] Spawned energy cloud ${newCloud.id} (Cap: ${capacity}) near ${targetPlayer.email || targetPlayer.uid}`);
  }

  // Блуждание существующих монстров (ИИ двигает их на крошечные шаги)
  monsters.forEach(monster => {
    monster.lat += randomOffset(0.00002); // маленькие шаги ~2м
    monster.lng += randomOffset(0.00002);
  });

  // Облака тоже могут медленно дрейфовать
  clouds.forEach(cloud => {
    cloud.lat += randomOffset(0.00001); // очень медленный дрейф ~1м
    cloud.lng += randomOffset(0.00001);
  });

  // 3. Рассылка обновленной карты всем игрокам
  io.emit('mapElementsUpdate', [...monsters, ...clouds]);

}, 5000); // 5 секундный тик сервера

io.on('connection', (socket) => {
  console.log(`Player connected: ${socket.id}`);

  // Когда игрок подключается, мы пока не знаем его координат.
  // Просто добавляем его в объект, когда он пришлет первую позицию.

  socket.on('updateLocation', (data) => {
    // data.lat, data.lng, data.uid, data.email, data.username, data.avatarBase64
    players[socket.id] = {
      id: socket.id,
      uid: data.uid || socket.id,
      email: data.email,
      username: data.username,
      avatarBase64: data.avatarBase64,
      lat: data.lat,
      lng: data.lng,
      lastUpdated: Date.now()
    };

    // Рассылаем обновленный список всех игроков всем подключенным клиентам
    io.emit('playersUpdate', Object.values(players));
    // Сразу посылаем список элементов при обновлении локации, чтобы вновь зашедший их увидел
    socket.emit('mapElementsUpdate', [...monsters, ...clouds]);
  });

  socket.on('logActivity', (data) => {
    // data.uid, data.email, data.action, data.value
    const timestamp = new Date().toLocaleTimeString();
    const identifier = data.email || data.uid || socket.id;
    console.log(`[ACTIVITY ${timestamp}] Player ${identifier} performed '${data.action}': +${data.value} XP`);
  });

  // Событие добычи энергии
  socket.on('mineEnergy', (data) => {
    // data.cloudId, data.amount
    const cloudIndex = clouds.findIndex(c => c.id === data.cloudId);
    if (cloudIndex !== -1) {
      clouds[cloudIndex].capacity -= data.amount;
      if (clouds[cloudIndex].capacity <= 0) {
        console.log(`[GAME ENGINE] Player ${socket.id} depleted cloud ${data.cloudId}!`);
        clouds.splice(cloudIndex, 1);
      }
      io.emit('mapElementsUpdate', [...monsters, ...clouds]);
    }
  });

  // Событие уничтожения монстра игроком
  socket.on('killMonster', (data) => {
    const startCount = monsters.length;
    monsters = monsters.filter(m => m.id !== data.monsterId);
    if (monsters.length < startCount) {
      console.log(`[GAME ENGINE] Player ${socket.id} killed monster ${data.monsterId}!`);
      io.emit('mapElementsUpdate', [...monsters, ...clouds]);
    }
  });

  socket.on('disconnect', () => {
    console.log(`Player disconnected: ${socket.id}`);
    delete players[socket.id];
    // Обновляем список для оставшихся
    io.emit('playersUpdate', Object.values(players));
  });
});

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(`Game Server running on port ${PORT}`);
});
