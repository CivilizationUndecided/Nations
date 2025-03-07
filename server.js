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

    // If a global tile map exists, send it to the new client
    if (globalTiles) {
        socket.emit('mapUpdate', { tiles: globalTiles });
    }

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
            // If trying to claim but tile is already claimed, ignore duplicate
            if (data.claimed && tile.claimed) {
                return;
            }
            // If trying to erase but tile is already not claimed, ignore duplicate
            if (!data.claimed && !tile.claimed) {
                return;
            }
            // Update the tile state
            tile.claimed = data.claimed;
            tile.claimedBy = data.claimedBy;
            // Broadcast the update to all clients
            io.emit('tileUpdate', data);
        }
    });

    // Listen for map update events (for regenerating the tile map)
    socket.on('mapUpdate', (data) => {
        // data.tiles contains the new tile map
        globalTiles = data.tiles;
        io.emit('mapUpdate', { tiles: globalTiles });
    });

    // Listen for chat messages from clients
    socket.on('chatMessage', (data) => {
        // data should have: { message, name }
        io.emit('chatMessage', { name: data.name, message: data.message });
    });

    // Handle disconnection
    socket.on('disconnect', () => {
        console.log('User disconnected:', socket.id);
        delete players[socket.id];
        io.emit('playerDisconnected', { playerId: socket.id });
    });
});

server.listen(port, () => {
    console.log(`Server listening on port ${port}`);
}); 