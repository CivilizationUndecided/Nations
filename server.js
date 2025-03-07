/* server.js: Basic multiplayer server using Socket.io */

const express = require('express');
const http = require('http');
const socketIo = require('socket.io');

const app = express();
const server = http.createServer(app);
const io = socketIo(server);

const port = process.env.PORT || 3000;

// Serve static files (e.g., index.html, game.js) from the current directory
app.use(express.static(__dirname));

let players = {};
let globalTiles = null; // Global tile map state to sync across clients

/* Added global tile map constants and helper functions */
const TILE_SIZE = 50;
const MAP_WIDTH = TILE_SIZE * 64;
const MAP_HEIGHT = TILE_SIZE * 64;
const numTilesX = Math.ceil(MAP_WIDTH / TILE_SIZE);
const numTilesY = Math.ceil(MAP_HEIGHT / TILE_SIZE);

class SimplexNoise {
  constructor(random = Math.random) {
    this.grad3 = [[1,1,0],[-1,1,0],[1,-1,0],[-1,-1,0],
                  [1,0,1],[-1,0,1],[1,0,-1],[-1,0,-1],
                  [0,1,1],[0,-1,1],[0,1,-1],[0,-1,-1]];
    this.p = [];
    for (let i = 0; i < 256; i++) {
      this.p[i] = Math.floor(random()*256);
    }
    this.perm = [];
    for (let i = 0; i < 512; i++) {
      this.perm[i] = this.p[i & 255];
    }
  }

  dot(g, x, y) {
    return g[0]*x + g[1]*y;
  }

  noise(xin, yin) {
    let n0, n1, n2;
    const F2 = 0.5*(Math.sqrt(3.0)-1.0);
    const s = (xin+yin)*F2;
    const i = Math.floor(xin+s);
    const j = Math.floor(yin+s);
    const G2 = (3.0-Math.sqrt(3.0))/6.0;
    const t = (i+j)*G2;
    const X0 = i-t;
    const Y0 = j-t;
    const x0 = xin - X0;
    const y0 = yin - Y0;
    let i1, j1;
    if(x0>y0) { i1=1; j1=0; } else { i1=0; j1=1; }
    const x1 = x0 - i1 + G2;
    const y1 = y0 - j1 + G2;
    const x2 = x0 - 1.0 + 2.0 * G2;
    const y2 = y0 - 1.0 + 2.0 * G2;
    const ii = i & 255;
    const jj = j & 255;
    const gi0 = this.perm[ii+this.perm[jj]] % 12;
    const gi1 = this.perm[ii+i1+this.perm[jj+j1]] % 12;
    const gi2 = this.perm[ii+1+this.perm[jj+1]] % 12;
    let t0 = 0.5 - x0*x0 - y0*y0;
    if(t0<0) n0 = 0.0;
    else {
      t0 *= t0;
      n0 = t0 * t0 * this.dot(this.grad3[gi0], x0, y0);
    }
    let t1 = 0.5 - x1*x1 - y1*y1;
    if(t1<0) n1 = 0.0;
    else {
      t1 *= t1;
      n1 = t1 * t1 * this.dot(this.grad3[gi1], x1, y1);
    }
    let t2 = 0.5 - x2*x2 - y2*y2;
    if(t2<0) n2 = 0.0;
    else {
      t2 *= t2;
      n2 = t2 * t2 * this.dot(this.grad3[gi2], x2, y2);
    }
    return 70.0 * (n0 + n1 + n2);
  }
}

function colorsEqual(c1, c2) {
  return Math.abs(c1[0] - c2[0]) < 0.01 &&
         Math.abs(c1[1] - c2[1]) < 0.01 &&
         Math.abs(c1[2] - c2[2]) < 0.01;
}

function generateTilemap() {
  const tiles = [];
  const noiseScale = 0.03;
  const offsetX = Math.floor(Math.random() * 10000);
  const offsetY = Math.floor(Math.random() * 10000);
  const simplex = new SimplexNoise();
  for (let y = 0; y < numTilesY; y++) {
    tiles[y] = [];
    for (let x = 0; x < numTilesX; x++) {
      const tileX = x * TILE_SIZE;
      const tileY = y * TILE_SIZE;
      const tileWidth = (x === numTilesX - 1) ? (MAP_WIDTH - tileX) : TILE_SIZE;
      const tileHeight = (y === numTilesY - 1) ? (MAP_HEIGHT - tileY) : TILE_SIZE;
      let tileType, color, claimable;
      const noiseValue = simplex.noise(x * noiseScale + offsetX, y * noiseScale + offsetY);
      if (noiseValue < -0.5) {
         tileType = "water";
      } else if (noiseValue < -0.3) {
         tileType = "sand";
      } else {
         tileType = "ground";
      }
      if (tileType === "water") {
         color = [0.0, 0.0, 1.0];
         claimable = false;
      } else if (tileType === "sand") {
         color = [0.96, 0.87, 0.70];
         claimable = true;
      } else if (tileType === "ground") {
         color = [0.2, 0.5, 0.2];
         claimable = true;
      } else {
         color = [0.4, 0.4, 0.4];
         claimable = true;
      }
      tiles[y][x] = {
         x: tileX,
         y: tileY,
         width: tileWidth,
         height: tileHeight,
         color: color,
         claimed: false,
         claimable: claimable,
         claimedBy: null,
         hovered: false,
         type: tileType
      };
    }
  }
  // Additional pass: force sand on the sides of water for interior tiles
  for (let y = 1; y < numTilesY - 1; y++) {
    for (let x = 1; x < numTilesX - 1; x++) {
      if (tiles[y][x].type !== "water") {
        if (tiles[y-1][x].type === "water" || tiles[y+1][x].type === "water" ||
            tiles[y][x-1].type === "water" || tiles[y][x+1].type === "water") {
          tiles[y][x].type = "sand";
          tiles[y][x].color = [0.96, 0.87, 0.70];
          tiles[y][x].claimable = true;
        }
      }
    }
  }
  return tiles;
}

/* End of added global map generation code */

io.on('connection', (socket) => {
    console.log('A user connected:', socket.id);
    
    // Add the new player with default state
    players[socket.id] = {
        x: 0,
        y: 0,
        name: 'Guest',
        color: [1, 1, 1],
        claimedTiles: 0,
        wealth: 25
    };

    // Send all current players to the new connection
    socket.emit('currentPlayers', players);

    // Generate the global tile map if it doesn't exist (i.e. first player joins) and send it
    if (!globalTiles) {
      globalTiles = generateTilemap();
    }
    socket.emit('mapUpdate', { tiles: globalTiles });

    // Notify all other players about the new player
    socket.broadcast.emit('newPlayer', { playerId: socket.id, playerData: players[socket.id] });

    // Listen for player movement updates
    socket.on('playerMovement', (data) => {
        if (players[socket.id]) {
            players[socket.id].x = data.x;
            players[socket.id].y = data.y;
            players[socket.id].name = data.name;
            players[socket.id].color = data.color;
            players[socket.id].claimedTiles = data.claimedTiles;
            players[socket.id].wealth = data.wealth;
            
            // Broadcast the movement update to all other clients
            socket.broadcast.emit('playerMoved', { playerId: socket.id, playerData: players[socket.id] });
        }
    });

    // Listen for tile update events from clients
    socket.on('tileUpdate', (data) => {
        // data should have: { tileX, tileY, claimed, claimedBy }
        if (!globalTiles) {
            // If no tile map is stored, simply broadcast the update
            io.emit('tileUpdate', data);
            return;
        }
        if (globalTiles[data.tileY] && globalTiles[data.tileY][data.tileX]) {
            const tile = globalTiles[data.tileY][data.tileX];
            if (data.claimed) {
                // If trying to claim but tile is already claimed, ignore duplicate
                if (tile.claimed) return;
                tile.claimed = true;
                tile.claimedBy = data.claimedBy; // player's color
                tile.owner = socket.id;         // store player's socket id
            } else {
                // If trying to erase but tile is already not claimed, ignore duplicate
                if (!tile.claimed) return;
                // Only allow the owner to erase their own claim
                if (tile.owner !== socket.id) return;
                tile.claimed = false;
                tile.claimedBy = null;
                tile.owner = null;
            }
            io.emit('tileUpdate', { tileX: data.tileX, tileY: data.tileY, claimed: tile.claimed, claimedBy: tile.claimedBy });
        }
    });

    // Listen for map update events (for regenerating the tile map)
    socket.on('mapUpdate', (data) => {
      // Map regeneration is disabled to keep the persistent map
    });

    // Listen for chat messages from clients
    socket.on('chatMessage', (data) => {
        // data should have: { message, name }
        io.emit('chatMessage', { name: data.name, message: data.message });
    });

    // Handle disconnection
    socket.on('disconnect', () => {
        console.log('User disconnected:', socket.id);
        if (globalTiles) {
            for (let y = 0; y < numTilesY; y++) {
                for (let x = 0; x < numTilesX; x++) {
                    if (globalTiles[y][x] && globalTiles[y][x].owner === socket.id) {
                        globalTiles[y][x].claimed = false;
                        globalTiles[y][x].claimedBy = null;
                        globalTiles[y][x].owner = null;
                        io.emit('tileUpdate', { tileX: x, tileY: y, claimed: false, claimedBy: null });
                    }
                }
            }
        }
        delete players[socket.id];
        io.emit('playerDisconnected', { playerId: socket.id });
    });
});

server.listen(port, () => {
    console.log(`Server listening on port ${port}`);
}); 