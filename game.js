/* Constants */
const TILE_SIZE = 50;
const PLAYER_SPEED = 300;
const PLAYER_SIZE = 40;
const OUTLINE_OPACITY = 0.8;
const HOVER_BRIGHTNESS = 1.2;
const UI_PADDING = 20;
const UI_BACKGROUND_OPACITY = 0.8;
const UI_BORDER_OPACITY = 0.3;

const FONT_SIZE_SMALL = 14;
const FONT_SIZE_NORMAL = 18;
const FONT_SIZE_LARGE = 24;
const FONT_SIZE_TITLE = 32;

/* Game State Variables */
let gameState = "joining"; // "joining" or "playing"
let actionMode = "claim"; // "claim" or "erase"

let windowWidth = window.innerWidth;
let windowHeight = window.innerHeight;

const MAP_WIDTH = TILE_SIZE * 128;
const MAP_HEIGHT = TILE_SIZE * 128;
const numTilesX = Math.ceil(MAP_WIDTH / TILE_SIZE);
const numTilesY = Math.ceil(MAP_HEIGHT / TILE_SIZE);

/* Canvas Setup */
const canvas = document.getElementById("gameCanvas");
canvas.width = windowWidth;
canvas.height = windowHeight;
const ctx = canvas.getContext("2d");

/* Add global smoothing variables and lerp function near the top, after canvas setup */

// Global camera smoothing variables
let smoothedCamX = 0, smoothedCamY = 0;

function lerp(a, b, t) {
  return a + (b - a) * t;
}

/* Utility Functions */
function colorToString(color, alpha = 1) {
  // color is [r, g, b] with components in 0..1
  return "rgba(" + Math.floor(color[0]*255) + "," + Math.floor(color[1]*255) + "," + Math.floor(color[2]*255) + "," + alpha + ")";
}

function adjustColor(color, factor) {
  return [Math.min(color[0] * factor, 1), Math.min(color[1] * factor, 1), Math.min(color[2] * factor, 1)];
}

function colorsEqual(c1, c2) {
  return Math.abs(c1[0] - c2[0]) < 0.01 && Math.abs(c1[1] - c2[1]) < 0.01 && Math.abs(c1[2] - c2[2]) < 0.01;
}

function fract(x) { return x - Math.floor(x); }

/* Global Variables for Game Objects */
let tiles = [];

let playerColors = [
  { name: "Blue", color: [0.2, 0.6, 1.0] },
  { name: "Red", color: [1.0, 0.2, 0.2] },
  { name: "Green", color: [0.2, 1.0, 0.2] },
  { name: "Yellow", color: [1.0, 1.0, 0.2] },
  { name: "Magenta", color: [1.0, 0.2, 1.0] },
  { name: "Cyan", color: [0.2, 1.0, 1.0] }
];

let player = {
  x: windowWidth / 2,
  y: windowHeight / 2,
  width: PLAYER_SIZE,
  height: PLAYER_SIZE,
  speed: PLAYER_SPEED,
  color: null,
  colorIndex: null,
  claimedTiles: 0,
  name: "Guest",
  wealth: 25,
  wealthAccumulator: 0
};

let leaderboard = {
  x: windowWidth - 300,
  y: 20,
  width: 280,
  padding: 15,
  entryHeight: 35,
  entries: []
};

let textInput = {
  x: windowWidth / 2 - 100,
  y: windowHeight / 3 + 30,
  width: 200,
  height: 40,
  active: false,
  cursor: 0,
  blinkTime: 0,
  blinkRate: 0.5
};

let baseplate = {
  x: 0,
  y: 0,
  width: MAP_WIDTH,
  height: MAP_HEIGHT,
  color: [0.2, 0.2, 0.2]
};

let currentHoveredTileX = null, currentHoveredTileY = null;

/* Add SimplexNoise implementation */
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
    const x0 = xin-X0;
    const y0 = yin-Y0;
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

// Instantiate simplex noise
const simplex = new SimplexNoise();

/* Modify generateTilemap to use simplex.noise() */
function generateTilemap() {
  tiles = [];
  const noiseScale = 0.03;
  const offsetX = Math.floor(Math.random() * 10000);
  const offsetY = Math.floor(Math.random() * 10000);

  for (let y = 0; y < numTilesY; y++) {
    tiles[y] = [];
    for (let x = 0; x < numTilesX; x++) {
      const tileX = x * TILE_SIZE;
      const tileY = y * TILE_SIZE;
      const tileWidth = (x === numTilesX - 1) ? (MAP_WIDTH - tileX) : TILE_SIZE;
      const tileHeight = (y === numTilesY - 1) ? (MAP_HEIGHT - tileY) : TILE_SIZE;
      let tileType, color, claimable;
      // Use simplex noise instead of the previous noise function
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
}

/* Ensure player spawns on a walkable tile */
function ensurePlayerSpawnIsWalkable() {
  if (!isPositionWalkable(player.x, player.y)) {
    const startTileX = Math.floor(player.x / TILE_SIZE);
    const startTileY = Math.floor(player.y / TILE_SIZE);
    const maxSearchRadius = 10;
    for (let r = 0; r <= maxSearchRadius; r++) {
      for (let dy = -r; dy <= r; dy++) {
        for (let dx = -r; dx <= r; dx++) {
          const tileX = startTileX + dx;
          const tileY = startTileY + dy;
          if (tileX >= 0 && tileX < numTilesX && tileY >= 0 && tileY < numTilesY) {
            const candidateX = tileX * TILE_SIZE;
            const candidateY = tileY * TILE_SIZE;
            if (isPositionWalkable(candidateX, candidateY)) {
              player.x = candidateX;
              player.y = candidateY;
              return;
            }
          }
        }
      }
    }
  }
}

function isPositionWalkable(newX, newY) {
  const corners = [
    { x: newX, y: newY },
    { x: newX + player.width, y: newY },
    { x: newX, y: newY + player.height },
    { x: newX + player.width, y: newY + player.height }
  ];
  for (let corner of corners) {
    const tileX = Math.floor(corner.x / TILE_SIZE);
    const tileY = Math.floor(corner.y / TILE_SIZE);
    if (tileX < 0 || tileX >= numTilesX || tileY < 0 || tileY >= numTilesY) return false;
    const tile = tiles[tileY][tileX];
    if (tile.type === "water") return false;
  }
  return true;
}

/* Player Movement */
let keys = {};
window.addEventListener("keydown", (e) => {
  keys[e.key] = true;
  handleKeyDown(e);
});
window.addEventListener("keyup", (e) => { keys[e.key] = false; });

function updatePlayerMovement(dt) {
  let newX = player.x;
  let newY = player.y;

  if (keys["a"]) {
    newX -= player.speed * dt;
  }
  if (keys["d"]) {
    newX += player.speed * dt;
  }
  if (isPositionWalkable(newX, player.y)) {
    player.x = newX;
  }

  if (keys["w"]) {
    newY -= player.speed * dt;
  }
  if (keys["s"]) {
    newY += player.speed * dt;
  }
  if (isPositionWalkable(player.x, newY)) {
    player.y = newY;
  }

  player.x = Math.max(0, Math.min(MAP_WIDTH - player.width, player.x));
  player.y = Math.max(0, Math.min(MAP_HEIGHT - player.height, player.y));
}

/* Camera and Visible Range */
function getCameraOffset() {
  const camX = Math.max(0, Math.min(player.x + player.width / 2 - windowWidth / 2, MAP_WIDTH - windowWidth));
  const camY = Math.max(0, Math.min(player.y + player.height / 2 - windowHeight / 2, MAP_HEIGHT - windowHeight));
  return [camX, camY];
}

function getVisibleTileRange(camX, camY) {
  const startX = Math.floor(camX / TILE_SIZE);
  const startY = Math.floor(camY / TILE_SIZE);
  const endX = Math.min(numTilesX - 1, Math.ceil((camX + windowWidth) / TILE_SIZE));
  const endY = Math.min(numTilesY - 1, Math.ceil((camY + windowHeight) / TILE_SIZE));
  return [startX, startY, endX, endY];
}

/* Tile Hover Update */
function updateTileHoverStates(mouseX, mouseY) {
  const [camX, camY] = getCameraOffset();
  const worldX = mouseX + camX;
  const worldY = mouseY + camY;
  const tileX = Math.floor(worldX / TILE_SIZE);
  const tileY = Math.floor(worldY / TILE_SIZE);
  if (tileX < 0 || tileX >= numTilesX || tileY < 0 || tileY >= numTilesY) return;
  if (currentHoveredTileX !== tileX || currentHoveredTileY !== tileY) {
    if (currentHoveredTileX !== null && currentHoveredTileY !== null && tiles[currentHoveredTileY] && tiles[currentHoveredTileY][currentHoveredTileX]) {
      tiles[currentHoveredTileY][currentHoveredTileX].hovered = false;
    }
    tiles[tileY][tileX].hovered = true;
    currentHoveredTileX = tileX;
    currentHoveredTileY = tileY;
  }
}

/* Drawing Functions */
function drawTile(tile) {
  if (tile.hovered && !tile.claimed) {
    ctx.fillStyle = colorToString(adjustColor(tile.color, HOVER_BRIGHTNESS));
  } else {
    ctx.fillStyle = colorToString(tile.color);
  }
  ctx.fillRect(tile.x, tile.y, tile.width, tile.height);
  if (!tile.claimed) {
    ctx.strokeStyle = "rgb(77,77,77)";
    ctx.strokeRect(tile.x, tile.y, tile.width, tile.height);
  }
  if (tile.claimed) {
    ctx.fillStyle = colorToString(tile.claimedBy);
    ctx.fillRect(tile.x, tile.y, tile.width, tile.height);
    const tileX = Math.floor(tile.x / TILE_SIZE);
    const tileY = Math.floor(tile.y / TILE_SIZE);
    let shouldOutline = false;
    if (tileY > 0 && !tiles[tileY - 1][tileX].claimed) shouldOutline = true;
    if (tileY < numTilesY - 1 && !tiles[tileY + 1][tileX].claimed) shouldOutline = true;
    if (tileX > 0 && !tiles[tileY][tileX - 1].claimed) shouldOutline = true;
    if (tileX < numTilesX - 1 && !tiles[tileY][tileX + 1].claimed) shouldOutline = true;
    if (shouldOutline) {
      ctx.strokeStyle = "rgba(255,255,255," + OUTLINE_OPACITY + ")";
      ctx.lineWidth = 2;
      if (tileY > 0 && !tiles[tileY - 1][tileX].claimed) {
        ctx.beginPath();
        ctx.moveTo(tile.x, tile.y);
        ctx.lineTo(tile.x + tile.width, tile.y);
        ctx.stroke();
      }
      if (tileY < numTilesY - 1 && !tiles[tileY + 1][tileX].claimed) {
        ctx.beginPath();
        ctx.moveTo(tile.x, tile.y + tile.height);
        ctx.lineTo(tile.x + tile.width, tile.y + tile.height);
        ctx.stroke();
      }
      if (tileX > 0 && !tiles[tileY][tileX - 1].claimed) {
        ctx.beginPath();
        ctx.moveTo(tile.x, tile.y);
        ctx.lineTo(tile.x, tile.y + tile.height);
        ctx.stroke();
      }
      if (tileX < numTilesX - 1 && !tiles[tileY][tileX + 1].claimed) {
        ctx.beginPath();
        ctx.moveTo(tile.x + tile.width, tile.y);
        ctx.lineTo(tile.x + tile.width, tile.y + tile.height);
        ctx.stroke();
      }
    }
  }
}

function drawLeaderboard() {
  const padding = leaderboard.padding;
  const x = leaderboard.x, y = leaderboard.y, width = leaderboard.width;
  const totalEntries = leaderboard.entries.length;
  const rowHeight = leaderboard.entryHeight;
  const headerHeight = 40;
  const totalHeight = headerHeight + totalEntries * rowHeight + padding * 2;

  ctx.fillStyle = "rgba(0,0,0," + UI_BACKGROUND_OPACITY + ")";
  ctx.fillRect(x, y, width, totalHeight);
  ctx.strokeStyle = "rgba(255,255,255," + UI_BORDER_OPACITY + ")";
  ctx.strokeRect(x, y, width, totalHeight);

  ctx.fillStyle = "rgba(51,51,51,0.8)";
  ctx.fillRect(x, y, width, headerHeight);

  ctx.font = FONT_SIZE_LARGE + "px sans-serif";
  ctx.fillStyle = "white";
  const headerText = "Leaderboard";
  const textWidth = ctx.measureText(headerText).width;
  ctx.fillText(headerText, x + width/2 - textWidth/2, y + headerHeight/2 + FONT_SIZE_LARGE/3);

  const colHeaderY = y + headerHeight;
  ctx.fillStyle = "rgba(77,77,77,0.8)";
  ctx.fillRect(x, colHeaderY, width, leaderboard.entryHeight);

  ctx.font = FONT_SIZE_NORMAL + "px sans-serif";
  ctx.fillStyle = "white";
  ctx.fillText("Rank", x + padding, colHeaderY + leaderboard.entryHeight/2 + FONT_SIZE_NORMAL/3);
  ctx.fillText("Player", x + padding + 50, colHeaderY + leaderboard.entryHeight/2 + FONT_SIZE_NORMAL/3);
  ctx.fillText("Wealth", x + width - padding - 120, colHeaderY + leaderboard.entryHeight/2 + FONT_SIZE_NORMAL/3);
  ctx.fillText("Tiles", x + width - padding - 50, colHeaderY + leaderboard.entryHeight/2 + FONT_SIZE_NORMAL/3);

  const startY = colHeaderY + leaderboard.entryHeight;
  ctx.font = FONT_SIZE_SMALL + "px sans-serif";
  for (let i = 0; i < leaderboard.entries.length; i++) {
    const entry = leaderboard.entries[i];
    const rowY = startY + i * leaderboard.entryHeight;
    if (i % 2 === 1) {
      ctx.fillStyle = "rgba(255,255,255,0.05)";
      ctx.fillRect(x, rowY, width, leaderboard.entryHeight);
    }
    ctx.fillStyle = "white";
    ctx.fillText((i+1).toString(), x + padding, rowY + leaderboard.entryHeight/2 + FONT_SIZE_SMALL/3);
    ctx.fillStyle = colorToString(entry.color);
    ctx.fillRect(x + padding + 30, rowY + 5, leaderboard.entryHeight - 10, leaderboard.entryHeight - 10);
    ctx.fillStyle = "white";
    ctx.fillText(entry.name, x + padding + 30 + leaderboard.entryHeight, rowY + leaderboard.entryHeight/2 + FONT_SIZE_SMALL/3);
    ctx.fillText((entry.wealth || 0).toString(), x + width - padding - 120, rowY + leaderboard.entryHeight/2 + FONT_SIZE_SMALL/3);
    ctx.fillText((entry.score || 0).toString(), x + width - padding - 50, rowY + leaderboard.entryHeight/2 + FONT_SIZE_SMALL/3);
  }
}

function drawColorSelection(dt) {
  ctx.fillStyle = "rgba(0,0,0," + UI_BACKGROUND_OPACITY + ")";
  ctx.fillRect(0, 0, windowWidth, windowHeight);

  ctx.font = FONT_SIZE_TITLE + "px sans-serif";
  ctx.fillStyle = "white";
  const titleText = "Select Your Color";
  const titleWidth = ctx.measureText(titleText).width;
  ctx.fillText(titleText, windowWidth/2 - titleWidth/2, windowHeight/4);

  ctx.font = FONT_SIZE_LARGE + "px sans-serif";
  ctx.fillText("Enter your name:", windowWidth/2 - 100, windowHeight/3);

  ctx.fillStyle = "rgba(51,51,51,1)";
  ctx.fillRect(textInput.x, textInput.y, textInput.width, textInput.height);
  if (textInput.active) {
    ctx.strokeStyle = "rgba(51,204,51,1)";
  } else {
    ctx.strokeStyle = "rgba(128,128,128,1)";
  }
  ctx.strokeRect(textInput.x, textInput.y, textInput.width, textInput.height);

  ctx.font = FONT_SIZE_NORMAL + "px sans-serif";
  ctx.fillStyle = "white";
  ctx.fillText(player.name, textInput.x + 10, textInput.y + 25);

  if (textInput.active) {
    textInput.blinkTime += dt;
    if (Math.floor(textInput.blinkTime / textInput.blinkRate) % 2 === 0) {
      const cursorX = textInput.x + 10 + ctx.measureText(player.name.substring(0, textInput.cursor)).width;
      ctx.beginPath();
      ctx.moveTo(cursorX, textInput.y + 5);
      ctx.lineTo(cursorX, textInput.y + textInput.height - 5);
      ctx.strokeStyle = "white";
      ctx.stroke();
    }
  }

  const paletteSize = 60;
  const paletteSpacing = 20;
  const totalPaletteWidth = (playerColors.length * (paletteSize + paletteSpacing)) - paletteSpacing;
  const startX = windowWidth / 2 - totalPaletteWidth / 2;
  const startY = windowHeight / 2 - paletteSize / 2;
  for (let i = 0; i < playerColors.length; i++) {
    const x = startX + i * (paletteSize + paletteSpacing);
    const y = startY;
    if (player.colorIndex === i + 1) {
      ctx.strokeStyle = "white";
      ctx.lineWidth = 4;
      ctx.strokeRect(x - 5, y - 5, paletteSize + 10, paletteSize + 10);
    }
    ctx.fillStyle = colorToString(playerColors[i].color);
    ctx.fillRect(x, y, paletteSize, paletteSize);
    ctx.font = FONT_SIZE_SMALL + "px sans-serif";
    ctx.fillStyle = "white";
    const nameWidth = ctx.measureText(playerColors[i].name).width;
    ctx.fillText(playerColors[i].name, x + paletteSize/2 - nameWidth/2, y + paletteSize + 15);
  }

  const buttonWidth = 200;
  const buttonHeight = 50;
  const buttonX = windowWidth / 2 - buttonWidth / 2;
  const buttonY = startY + paletteSize + 50;
  if (player.colorIndex) {
    ctx.fillStyle = "rgba(51,204,51,0.8)";
  } else {
    ctx.fillStyle = "rgba(128,128,128,0.8)";
  }
  ctx.fillRect(buttonX, buttonY, buttonWidth, buttonHeight);
  ctx.strokeStyle = "rgba(255,255,255,0.3)";
  ctx.strokeRect(buttonX, buttonY, buttonWidth, buttonHeight);
  ctx.font = FONT_SIZE_LARGE + "px sans-serif";
  ctx.fillStyle = "white";
  const buttonText = "Start Game";
  const buttonTextWidth = ctx.measureText(buttonText).width;
  ctx.fillText(buttonText, buttonX + buttonWidth/2 - buttonTextWidth/2, buttonY + buttonHeight/2 + FONT_SIZE_LARGE/3);
}

function drawGameUI() {
  const padding = UI_PADDING;
  const lineHeight = 30;
  const instructions = [
    "Use WASD to move",
    "Click to claim tiles",
    "Press Q for Claim mode",
    "Press E for Erase mode",
    "Claimed tiles: " + player.claimedTiles,
    "Press R to regenerate map"
  ];
  const boxHeight = padding * 2 + (instructions.length * lineHeight);
  ctx.fillStyle = "rgba(0,0,0," + UI_BACKGROUND_OPACITY + ")";
  ctx.fillRect(0, 0, 300, boxHeight);
  ctx.strokeStyle = "rgba(255,255,255," + UI_BORDER_OPACITY + ")";
  ctx.strokeRect(0, 0, 300, boxHeight);
  ctx.font = FONT_SIZE_NORMAL + "px sans-serif";
  ctx.fillStyle = "white";
  for (let i = 0; i < instructions.length; i++) {
    ctx.fillText(instructions[i], padding, padding + i * lineHeight + lineHeight/2);
  }
}

function drawMinimap() {
  const minimapSize = 200;
  const minimapMargin = 20;
  const minimapX = windowWidth - minimapSize - minimapMargin;
  const minimapY = windowHeight - minimapSize - minimapMargin;
  const scale = minimapSize / MAP_WIDTH;

  ctx.fillStyle = "rgba(25,25,25,0.8)";
  ctx.fillRect(minimapX, minimapY, minimapSize, minimapSize);
  ctx.strokeStyle = "white";
  ctx.strokeRect(minimapX, minimapY, minimapSize, minimapSize);

  for (let j = 0; j < numTilesY; j++) {
    for (let i = 0; i < numTilesX; i++) {
      const tile = tiles[j][i];
      const col = tile.claimed ? tile.claimedBy : tile.color;
      ctx.fillStyle = colorToString(col);
      ctx.fillRect(minimapX + tile.x * scale, minimapY + tile.y * scale, tile.width * scale, tile.height * scale);
    }
  }

  ctx.fillStyle = "white";
  const playerCenterX = minimapX + (player.x + player.width/2) * scale;
  const playerCenterY = minimapY + (player.y + player.height/2) * scale;
  ctx.beginPath();
  ctx.arc(playerCenterX, playerCenterY, Math.max(3, player.width * scale/2), 0, 2 * Math.PI);
  ctx.fill();
}

function drawGame() {
  const camX = smoothedCamX, camY = smoothedCamY;
  ctx.save();
  ctx.translate(-camX, -camY);
  ctx.fillStyle = colorToString(baseplate.color);
  ctx.fillRect(baseplate.x, baseplate.y, baseplate.width, baseplate.height);
  const [startTileX, startTileY, endTileX, endTileY] = getVisibleTileRange(camX, camY);
  for (let j = startTileY; j <= endTileY; j++) {
    for (let i = startTileX; i <= endTileX; i++) {
      const tile = tiles[j][i];
      if (tile.type === "water") {
        ctx.fillStyle = colorToString(tile.color);
        ctx.fillRect(tile.x, tile.y, tile.width, tile.height);
        // Optionally add border effects for water
      } else {
        ctx.fillStyle = colorToString(tile.color);
        ctx.fillRect(tile.x, tile.y, tile.width, tile.height);
        ctx.strokeStyle = "rgb(77,77,77)";
        ctx.strokeRect(tile.x, tile.y, tile.width, tile.height);
      }
    }
  }
  for (let j = startTileY; j <= endTileY; j++) {
    for (let i = startTileX; i <= endTileX; i++) {
      const tile = tiles[j][i];
      if (tile.claimed) {
        ctx.fillStyle = colorToString(tile.claimedBy);
        ctx.fillRect(tile.x, tile.y, tile.width, tile.height);
        const tileX = i;
        const tileY = j;
        ctx.strokeStyle = "rgba(255,255,255," + OUTLINE_OPACITY + ")";
        if (tileY > 0 && !tiles[tileY - 1][tileX].claimed) {
          ctx.beginPath();
          ctx.moveTo(tile.x, tile.y);
          ctx.lineTo(tile.x + tile.width, tile.y);
          ctx.stroke();
        }
        if (tileY < numTilesY - 1 && !tiles[tileY + 1][tileX].claimed) {
          ctx.beginPath();
          ctx.moveTo(tile.x, tile.y + tile.height);
          ctx.lineTo(tile.x + tile.width, tile.y + tile.height);
          ctx.stroke();
        }
        if (tileX > 0 && !tiles[tileY][tileX - 1].claimed) {
          ctx.beginPath();
          ctx.moveTo(tile.x, tile.y);
          ctx.lineTo(tile.x, tile.y + tile.height);
          ctx.stroke();
        }
        if (tileX < numTilesX - 1 && !tiles[tileY][tileX + 1].claimed) {
          ctx.beginPath();
          ctx.moveTo(tile.x + tile.width, tile.y);
          ctx.lineTo(tile.x + tile.width, tile.y + tile.height);
          ctx.stroke();
        }
      }
    }
  }
  if (currentHoveredTileX !== null && currentHoveredTileY !== null) {
    const tile = tiles[currentHoveredTileY][currentHoveredTileX];
    ctx.strokeStyle = "rgba(255,255,255,0.7)";
    ctx.strokeRect(tile.x, tile.y, tile.width, tile.height);
  }
  if (player.color) {
    ctx.fillStyle = colorToString(player.color);
    ctx.fillRect(player.x, player.y, player.width, player.height);
    ctx.strokeStyle = "rgba(255,255,255,0.5)";
    ctx.strokeRect(player.x, player.y, player.width, player.height);
    ctx.font = FONT_SIZE_SMALL + "px sans-serif";
    ctx.fillStyle = "white";
    const nameWidth = ctx.measureText(player.name).width;
    ctx.fillText(player.name, player.x + (player.width - nameWidth)/2, player.y - 20);
  }
  ctx.restore();

  if (gameState === "joining") {
    // Pass dt for blinking
    drawColorSelection(dtGlobal);
  } else {
    drawGameUI();
    drawLeaderboard();
  }

  ctx.font = FONT_SIZE_SMALL + "px sans-serif";
  ctx.fillStyle = "white";
  ctx.fillText("FPS: " + Math.round(fps), 10, windowHeight - FONT_SIZE_SMALL - 10);
  drawMinimap();
}

/* Leaderboard Update */
function updateLeaderboard() {
  let found = false;
  for (let i = 0; i < leaderboard.entries.length; i++) {
    const entry = leaderboard.entries[i];
    if (entry.name === player.name) {
      entry.score = player.claimedTiles;
      entry.wealth = player.wealth;
      entry.color = player.color;
      found = true;
      break;
    }
  }
  if (!found) {
    leaderboard.entries.push({
      name: player.name,
      score: player.claimedTiles,
      wealth: player.wealth,
      color: player.color
    });
  }
  leaderboard.entries.sort((a, b) => (b.wealth || 0) - (a.wealth || 0));
}

/* Mouse and Keyboard Handling */
canvas.addEventListener("mousedown", (e) => {
  const rect = canvas.getBoundingClientRect();
  const mouseX = e.clientX - rect.left;
  const mouseY = e.clientY - rect.top;
  if (gameState === "joining") {
    handleJoiningStateClick(mouseX, mouseY);
  } else {
    handlePlayingStateClick(mouseX, mouseY);
  }
});

canvas.addEventListener("mousemove", (e) => {
  const rect = canvas.getBoundingClientRect();
  const mouseX = e.clientX - rect.left;
  const mouseY = e.clientY - rect.top;
  updateTileHoverStates(mouseX, mouseY);
  if (gameState === "playing" && e.buttons === 1) {
    handlePlayingStateClick(mouseX, mouseY);
  }
});

function handleJoiningStateClick(x, y) {
  if (x >= textInput.x && x <= textInput.x + textInput.width && y >= textInput.y && y <= textInput.y + textInput.height) {
    textInput.active = true;
    textInput.cursor = player.name.length;
  } else {
    textInput.active = false;
  }

  const paletteSize = 60;
  const paletteSpacing = 20;
  const totalPaletteWidth = (playerColors.length * (paletteSize + paletteSpacing)) - paletteSpacing;
  const startX = windowWidth / 2 - totalPaletteWidth / 2;
  const startY = windowHeight / 2 - paletteSize / 2;
  for (let i = 0; i < playerColors.length; i++) {
    if (x >= startX + i * (paletteSize + paletteSpacing) && x <= startX + i * (paletteSize + paletteSpacing) + paletteSize &&
        y >= startY && y <= startY + paletteSize) {
      player.colorIndex = i + 1;
      player.color = playerColors[i].color;
    }
  }

  const buttonWidth = 200;
  const buttonHeight = 50;
  const buttonX = windowWidth / 2 - buttonWidth / 2;
  const buttonY = startY + paletteSize + 50;
  if (player.colorIndex &&
      x >= buttonX && x <= buttonX + buttonWidth &&
      y >= buttonY && y <= buttonY + buttonHeight) {
    gameState = "playing";
    ensurePlayerSpawnIsWalkable();
  }
}

function handlePlayingStateClick(x, y) {
  const [camX, camY] = getCameraOffset();
  const worldX = x + camX;
  const worldY = y + camY;
  const tileX = Math.floor(worldX / TILE_SIZE);
  const tileY = Math.floor(worldY / TILE_SIZE);
  if (tileY >= 0 && tileY < numTilesY && tileX >= 0 && tileX < numTilesX) {
    const tile = tiles[tileY][tileX];
    if (actionMode === "claim") {
      if (tile && tile.claimable && !tile.claimed && player.wealth >= 1) {
        if (player.claimedTiles === 0 || isTileAdjacentToOwner(tileX, tileY, player.color)) {
          tile.claimed = true;
          tile.claimedBy = player.color;
          player.claimedTiles++;
          player.wealth -= 1;
        }
      }
    } else if (actionMode === "erase") {
      if (tile && tile.claimed && tile.claimedBy && colorsEqual(tile.claimedBy, player.color)) {
        tile.claimed = false;
        tile.claimedBy = null;
        player.claimedTiles = Math.max(0, player.claimedTiles - 1);
        player.wealth += 1;
      }
    }
  }
}

function isTileAdjacentToOwner(tileX, tileY, ownerColor) {
  const directions = [
    { x: -1, y: 0 },
    { x: 1, y: 0 },
    { x: 0, y: -1 },
    { x: 0, y: 1 }
  ];
  for (let dir of directions) {
    const nx = tileX + dir.x;
    const ny = tileY + dir.y;
    if (nx >= 0 && nx < numTilesX && ny >= 0 && ny < numTilesY) {
      const neighbor = tiles[ny][nx];
      if (neighbor && neighbor.claimed && neighbor.claimedBy && colorsEqual(neighbor.claimedBy, ownerColor)) {
        return true;
      }
    }
  }
  return false;
}

function handleKeyDown(e) {
  if (gameState === "playing") {
    if (e.key === "q") {
      actionMode = "claim";
    } else if (e.key === "e") {
      actionMode = "erase";
    } else if (e.key === "r") {
      player.claimedTiles = 0;
      generateTilemap();
      ensurePlayerSpawnIsWalkable();
    }
  }
  if (gameState === "joining") {
    if (/^[1-9]$/.test(e.key)) {
      const num = parseInt(e.key);
      if (num >= 1 && num <= playerColors.length) {
        player.colorIndex = num;
        player.color = playerColors[num - 1].color;
      }
    }
    if (textInput.active) {
      if (e.key === "Backspace") {
        if (textInput.cursor > 0) {
          player.name = player.name.substring(0, textInput.cursor - 1) + player.name.substring(textInput.cursor);
          textInput.cursor--;
        }
      } else if (e.key === "ArrowLeft") {
        textInput.cursor = Math.max(0, textInput.cursor - 1);
      } else if (e.key === "ArrowRight") {
        textInput.cursor = Math.min(player.name.length, textInput.cursor + 1);
      } else if (e.key === "Enter") {
        textInput.active = false;
      } else if (e.key.length === 1) {
        player.name = player.name.substring(0, textInput.cursor) + e.key + player.name.substring(textInput.cursor);
        textInput.cursor++;
      }
    }
  }
  if (e.key === "Escape") {
    // Optionally handle exit
  }
}

/* Game Loop */
let lastTime = performance.now();
let fps = 60;
let dtGlobal = 0;

function gameLoop(timestamp) {
  const dt = (timestamp - lastTime) / 1000;
  lastTime = timestamp;
  dtGlobal = dt;
  if (gameState === "playing") {
    updatePlayerMovement(dt);
    player.wealthAccumulator += dt;
    if (player.wealthAccumulator >= 1) {
      const add = Math.floor(player.wealthAccumulator);
      player.wealth += add;
      player.wealthAccumulator -= add;
    }
    updateLeaderboard();
  }
  ctx.clearRect(0, 0, windowWidth, windowHeight);
  ctx.lineWidth = 1;  // Reset lineWidth to default
  // Update smoothed camera position
  let targetCam = getCameraOffset();
  smoothedCamX = lerp(smoothedCamX, targetCam[0], 0.1);
  smoothedCamY = lerp(smoothedCamY, targetCam[1], 0.1);
  drawGame();
  fps = 1 / dt;
  requestAnimationFrame(gameLoop);
}

requestAnimationFrame(gameLoop);

window.addEventListener("resize", () => {
  windowWidth = window.innerWidth;
  windowHeight = window.innerHeight;
  canvas.width = windowWidth;
  canvas.height = windowHeight;
});

/* Initialization */
generateTilemap();
ensurePlayerSpawnIsWalkable();
