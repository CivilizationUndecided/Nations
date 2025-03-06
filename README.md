# Nations

A multiplayer territory control game built with LÖVE (Love2D) where players compete to claim tiles and build their wealth.

## Features

- **Multiplayer Support**: Host or join games with other players
- **Territory Control**: Claim tiles to expand your territory
- **Player Customization**: Choose your color and name
- **Real-time Leaderboard**: Track your wealth and territory size
- **Dynamic Map**: Randomly generated terrain with different tile types
- **Smooth Controls**: WASD movement and mouse-based tile claiming
- **Visual Feedback**: Hover effects and territory outlines
- **Responsive UI**: Clean, modern interface with semi-transparent overlays

## Controls

- **WASD**: Move your player
- **Left Click**: Claim tiles
- **R**: Regenerate the map
- **ESC**: Quit game

## Game Rules

1. Choose to host or join a game
2. Choose your color and enter your name
3. Move around the map using WASD
4. Click on unclaimed tiles to claim them
5. Each claimed tile adds to your wealth (100 points per tile)
6. The player with the most wealth wins
7. Press R to start a new game with a fresh map

## Multiplayer

The game supports multiplayer through a client-server architecture:
- One player hosts the game (server)
- Other players can join as clients
- All player movements and tile claims are synchronized
- Real-time leaderboard updates for all players

## Technical Details

- Built with LÖVE 11.5
- Resolution: 1280x720 (resizable)
- Minimum window size: 800x600
- High DPI support enabled
- Optimized for smooth performance
- Uses modern LÖVE 11.5 features:
  - Improved window management
  - Enhanced graphics capabilities
  - Better high DPI support
  - Optimized performance

## Installation

1. Install LÖVE 11.5 from [love2d.org](https://love2d.org/)
2. Clone or download this repository
3. Run the game using LÖVE

## Development

The game is structured with the following main components:
- `main.lua`: Core game logic and rendering
- `conf.lua`: LÖVE configuration settings
- `network/`: Networking components
  - `network.lua`: Network communication logic
  - `sock.lua`: Network library

## License

This project is open source and available under the MIT License. 