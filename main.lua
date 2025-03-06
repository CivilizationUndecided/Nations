-- main.lua

-- Constants
local TILE_SIZE = 50
local PLAYER_SPEED = 300
local PLAYER_SIZE = 40
local OUTLINE_OPACITY = 0.8
local HOVER_BRIGHTNESS = 1.2
local WEALTH_MULTIPLIER = 100
local UI_PADDING = 20
local UI_BACKGROUND_OPACITY = 0.8
local UI_BORDER_OPACITY = 0.3

-- Font sizes
local FONT_SIZE_SMALL = 14
local FONT_SIZE_NORMAL = 18
local FONT_SIZE_LARGE = 24
local FONT_SIZE_TITLE = 32

-- Game state
local gameState = "joining"  -- "joining" or "playing"
local windowWidth, windowHeight = love.graphics.getDimensions()
local MAP_WIDTH = TILE_SIZE * 128
local MAP_HEIGHT = TILE_SIZE * 128
local numTilesX = math.ceil(MAP_WIDTH / TILE_SIZE)
local numTilesY = math.ceil(MAP_HEIGHT / TILE_SIZE)

-- Fonts
local gameFonts = {
    small = nil,
    normal = nil,
    large = nil,
    title = nil
}

-- Available colors for players with names
local playerColors = {
    {name = "Blue", color = {0.2, 0.6, 1.0}},
    {name = "Red", color = {1.0, 0.2, 0.2}},
    {name = "Green", color = {0.2, 1.0, 0.2}},
    {name = "Yellow", color = {1.0, 1.0, 0.2}},
    {name = "Magenta", color = {1.0, 0.2, 1.0}},
    {name = "Cyan", color = {0.2, 1.0, 1.0}}
}

-- Player properties
local player = {
    x = windowWidth / 2,
    y = windowHeight / 2,
    width = PLAYER_SIZE,
    height = PLAYER_SIZE,
    speed = PLAYER_SPEED,
    color = nil,
    colorIndex = nil,
    claimedTiles = 0,
    name = "Guest",
    isTyping = false,
    wealth = 25,         -- starting wealth
    wealthAccumulator = 0  -- accumulator for passive wealth gain
}

-- Leaderboard properties
local leaderboard = {
    x = windowWidth - 300,
    y = 20,
    width = 280,
    padding = 15,
    entryHeight = 35,
    entries = {},
    maxEntries = 10
}

-- Text input properties
local textInput = {
    x = windowWidth/2 - 100,
    y = windowHeight/3 + 30,
    width = 200,
    height = 40,
    active = false,
    cursor = 0,
    blinkTime = 0,
    blinkRate = 0.5
}

-- Baseplate properties
local baseplate = {
    x = 0,
    y = 0,
    width = MAP_WIDTH,
    height = MAP_HEIGHT,
    color = {0.2, 0.2, 0.2}
}

-- Game data
local tiles = {}

-- Variables for hover optimization
local currentHoveredTileX, currentHoveredTileY = nil, nil

function love.load()
    love.window.setTitle("Nations")
    love.graphics.setDefaultFilter("nearest", "nearest")
    love.graphics.setLineWidth(2)
    
    gameFonts.small = love.graphics.newFont("assets/fonts/OpenSans-Regular.ttf", FONT_SIZE_SMALL)
    gameFonts.normal = love.graphics.newFont("assets/fonts/OpenSans-Regular.ttf", FONT_SIZE_NORMAL)
    gameFonts.large = love.graphics.newFont("assets/fonts/OpenSans-Regular.ttf", FONT_SIZE_LARGE)
    gameFonts.title = love.graphics.newFont("assets/fonts/OpenSans-Regular.ttf", FONT_SIZE_TITLE)
    love.graphics.setFont(gameFonts.normal)
    
    generateTilemap()
    ensurePlayerSpawnIsWalkable()
end

function generateTilemap()
    love.math.setRandomSeed(os.time() + math.floor(love.timer.getTime() * 1000))
    local noiseScale = 0.1
    local offsetX = love.math.random(0, 10000)
    local offsetY = love.math.random(0, 10000)
    
    for y = 0, numTilesY - 1 do
        tiles[y] = {}
        for x = 0, numTilesX - 1 do
            local tileX = x * TILE_SIZE
            local tileY = y * TILE_SIZE
            local tileWidth = (x == numTilesX - 1) and (MAP_WIDTH - tileX) or TILE_SIZE
            local tileHeight = (y == numTilesY - 1) and (MAP_HEIGHT - tileY) or TILE_SIZE
            local tileType, color, claimable
            if x == 0 or y == 0 or x == numTilesX - 1 or y == numTilesY - 1 then
                tileType = "water"
            else
                local noiseValue = love.math.noise(x * noiseScale + offsetX, y * noiseScale + offsetY)
                if noiseValue < 0.3 then
                    tileType = "water"
                elseif noiseValue < 0.35 then
                    tileType = "sand"
                else
                    tileType = "ground"
                end
            end
            
            if tileType == "water" then
                color = {0.0, 0.0, 1.0}  -- Water is blue
                claimable = false
            elseif tileType == "sand" then
                color = {0.96, 0.87, 0.70}  -- Sand is a light yellowish color
                claimable = true
            elseif tileType == "ground" then
                color = {0.2, 0.5, 0.2}  -- Ground is green
                claimable = true
            elseif tileType == "hills" then
                color = {0.5, 0.4, 0.1}  -- Hills have a brownish hue
                claimable = true
            elseif tileType == "mountains" then
                color = {0.5, 0.5, 0.5}  -- Mountains are gray
                claimable = true
            else
                color = {0.4, 0.4, 0.4}
                claimable = true
            end
            
            tiles[y][x] = {
                x = tileX,
                y = tileY,
                width = tileWidth,
                height = tileHeight,
                color = color,
                claimed = false,
                claimable = claimable,
                claimedBy = nil,
                hovered = false,
                type = tileType
            }
        end
    end
    
    -- Additional pass: force sand on the sides of water for interior tiles
    for y = 1, numTilesY - 2 do
        for x = 1, numTilesX - 2 do
            if tiles[y][x].type ~= "water" then
                if tiles[y-1][x].type == "water" or tiles[y+1][x].type == "water" or tiles[y][x-1].type == "water" or tiles[y][x+1].type == "water" then
                    tiles[y][x].type = "sand"
                    tiles[y][x].color = {0.96, 0.87, 0.70}  -- Sand is a light yellowish color
                    tiles[y][x].claimable = true
                end
            end
        end
    end
end

function ensurePlayerSpawnIsWalkable()
    if not isPositionWalkable(player.x, player.y) then
        local startTileX = math.floor(player.x / TILE_SIZE)
        local startTileY = math.floor(player.y / TILE_SIZE)
        local maxSearchRadius = 10
        for r = 0, maxSearchRadius do
            for dy = -r, r do
                for dx = -r, r do
                    local tileX = startTileX + dx
                    local tileY = startTileY + dy
                    if tileX >= 0 and tileX < numTilesX and tileY >= 0 and tileY < numTilesY then
                        local candidateX = tileX * TILE_SIZE
                        local candidateY = tileY * TILE_SIZE
                        if isPositionWalkable(candidateX, candidateY) then
                            player.x = candidateX
                            player.y = candidateY
                            return
                        end
                    end
                end
            end
        end
    end
end

function love.update(dt)
    if gameState == "playing" then
        updatePlayerMovement(dt)
        updateTileHoverStates()
        
        player.wealthAccumulator = player.wealthAccumulator + dt
        if player.wealthAccumulator >= 1 then
            local add = math.floor(player.wealthAccumulator)
            player.wealth = player.wealth + add
            player.wealthAccumulator = player.wealthAccumulator - add
        end
        
        updateLeaderboard()  -- Moved from draw to update for efficiency
    end
    if textInput.active then
        textInput.blinkTime = textInput.blinkTime + dt
    end
end

function getCameraOffset()
    local camX = math.max(0, math.min(player.x + player.width/2 - windowWidth/2, MAP_WIDTH - windowWidth))
    local camY = math.max(0, math.min(player.y + player.height/2 - windowHeight/2, MAP_HEIGHT - windowHeight))
    return camX, camY
end

function isPositionWalkable(newX, newY)
    local corners = {
        { x = newX, y = newY },
        { x = newX + player.width, y = newY },
        { x = newX, y = newY + player.height },
        { x = newX + player.width, y = newY + player.height }
    }
    for _, corner in ipairs(corners) do
        local tileX = math.floor(corner.x / TILE_SIZE)
        local tileY = math.floor(corner.y / TILE_SIZE)
        if tileX < 0 or tileX >= numTilesX or tileY < 0 or tileY >= numTilesY then
            return false
        end
        local tile = tiles[tileY][tileX]
        if tile.type == "water" then
            return false
        end
    end
    return true
end

function updatePlayerMovement(dt)
    local newX = player.x
    local newY = player.y

    if love.keyboard.isDown("a") then
        newX = newX - player.speed * dt
    end
    if love.keyboard.isDown("d") then
        newX = newX + player.speed * dt
    end
    if isPositionWalkable(newX, player.y) then
        player.x = newX
    end

    if love.keyboard.isDown("w") then
        newY = newY - player.speed * dt
    end
    if love.keyboard.isDown("s") then
        newY = newY + player.speed * dt
    end
    if isPositionWalkable(player.x, newY) then
        player.y = newY
    end

    player.x = math.max(0, math.min(MAP_WIDTH - player.width, player.x))
    player.y = math.max(0, math.min(MAP_HEIGHT - player.height, player.y))
end

-- Optimized hover update: only update the tile under the mouse
function updateTileHoverStates()
    local mouseX, mouseY = love.mouse.getPosition()
    local camX, camY = getCameraOffset()
    local worldX = mouseX + camX
    local worldY = mouseY + camY
    local tileX = math.floor(worldX / TILE_SIZE)
    local tileY = math.floor(worldY / TILE_SIZE)
    
    if tileX < 0 or tileX >= numTilesX or tileY < 0 or tileY >= numTilesY then
        return
    end
    
    if currentHoveredTileX ~= tileX or currentHoveredTileY ~= tileY then
        if currentHoveredTileX and currentHoveredTileY and tiles[currentHoveredTileY] and tiles[currentHoveredTileY][currentHoveredTileX] then
            tiles[currentHoveredTileY][currentHoveredTileX].hovered = false
        end
        tiles[tileY][tileX].hovered = true
        currentHoveredTileX, currentHoveredTileY = tileX, tileY
    end
end

-- Helper to compute the visible tile range based on camera
local function getVisibleTileRange(camX, camY)
    local startX = math.floor(camX / TILE_SIZE)
    local startY = math.floor(camY / TILE_SIZE)
    local endX = math.min(numTilesX - 1, math.ceil((camX + windowWidth) / TILE_SIZE))
    local endY = math.min(numTilesY - 1, math.ceil((camY + windowHeight) / TILE_SIZE))
    return startX, startY, endX, endY
end

function drawTile(tile)
    if tile.hovered and not tile.claimed then
        love.graphics.setColor(tile.color[1] * HOVER_BRIGHTNESS, tile.color[2] * HOVER_BRIGHTNESS, tile.color[3] * HOVER_BRIGHTNESS)
    else
        love.graphics.setColor(tile.color)
    end
    love.graphics.rectangle("fill", tile.x, tile.y, tile.width, tile.height)
    
    if not tile.claimed then
        love.graphics.setColor(0.3, 0.3, 0.3)
        love.graphics.rectangle("line", tile.x, tile.y, tile.width, tile.height)
    end
    
    if tile.claimed then
        love.graphics.setColor(tile.claimedBy)
        love.graphics.rectangle("fill", tile.x, tile.y, tile.width, tile.height)
        
        local tileX = math.floor(tile.x / TILE_SIZE)
        local tileY = math.floor(tile.y / TILE_SIZE)
        local shouldOutline = false
        if tileY > 0 and not tiles[tileY-1][tileX].claimed then shouldOutline = true end
        if tileY < numTilesY-1 and not tiles[tileY+1][tileX].claimed then shouldOutline = true end
        if tileX > 0 and not tiles[tileY][tileX-1].claimed then shouldOutline = true end
        if tileX < numTilesX-1 and not tiles[tileY][tileX+1].claimed then shouldOutline = true end
        
        if shouldOutline then
            love.graphics.setColor(1, 1, 1, OUTLINE_OPACITY)
            if tileY > 0 and not tiles[tileY-1][tileX].claimed then
                love.graphics.line(tile.x, tile.y, tile.x + tile.width, tile.y)
            end
            if tileY < numTilesY-1 and not tiles[tileY+1][tileX].claimed then
                love.graphics.line(tile.x, tile.y + tile.height, tile.x + tile.width, tile.y + tile.height)
            end
            if tileX > 0 and not tiles[tileY][tileX-1].claimed then
                love.graphics.line(tile.x, tile.y, tile.x, tile.y + tile.height)
            end
            if tileX < numTilesX-1 and not tiles[tileY][tileX+1].claimed then
                love.graphics.line(tile.x + tile.width, tile.y, tile.x + tile.width, tile.y + tile.height)
            end
        end
    end
end

function drawLeaderboard()
    local padding = leaderboard.padding
    local x, y, width = leaderboard.x, leaderboard.y, leaderboard.width
    local totalEntries = #leaderboard.entries
    local rowHeight = leaderboard.entryHeight
    local headerHeight = 40
    local totalHeight = headerHeight + totalEntries * rowHeight + padding * 2

    love.graphics.setColor(0, 0, 0, UI_BACKGROUND_OPACITY)
    love.graphics.rectangle("fill", x, y, width, totalHeight)
    love.graphics.setColor(1, 1, 1, UI_BORDER_OPACITY)
    love.graphics.rectangle("line", x, y, width, totalHeight)

    love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
    love.graphics.rectangle("fill", x, y, width, headerHeight)

    love.graphics.setFont(gameFonts.large)
    love.graphics.setColor(1, 1, 1)
    local headerText = "Leaderboard"
    local textWidth = gameFonts.large:getWidth(headerText)
    love.graphics.print(headerText, x + width/2 - textWidth/2, y + (headerHeight - gameFonts.large:getHeight(headerText))/2, 0, 1)

    local colHeaderY = y + headerHeight
    love.graphics.setColor(0.3, 0.3, 0.3, 0.8)
    love.graphics.rectangle("fill", x, colHeaderY, width, leaderboard.entryHeight)

    love.graphics.setFont(gameFonts.normal)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Rank", x + padding, colHeaderY + (leaderboard.entryHeight - gameFonts.normal:getHeight())/2, 0, 1)
    love.graphics.print("Player", x + padding + 50, colHeaderY + (leaderboard.entryHeight - gameFonts.normal:getHeight())/2, 0, 1)
    love.graphics.print("Wealth", x + width - padding - 120, colHeaderY + (leaderboard.entryHeight - gameFonts.normal:getHeight())/2, 0, 1)
    love.graphics.print("Tiles", x + width - padding - 50, colHeaderY + (leaderboard.entryHeight - gameFonts.normal:getHeight())/2, 0, 1)

    local startY = colHeaderY + leaderboard.entryHeight
    love.graphics.setFont(gameFonts.small)
    for i, entry in ipairs(leaderboard.entries) do
        local rowY = startY + (i-1) * leaderboard.entryHeight
        if i % 2 == 0 then
            love.graphics.setColor(1, 1, 1, 0.05)
            love.graphics.rectangle("fill", x, rowY, width, leaderboard.entryHeight)
        end
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(tostring(i), x + padding, rowY + (leaderboard.entryHeight - gameFonts.small:getHeight(tostring(i)))/2, 0, 1)
        love.graphics.setColor(entry.color)
        love.graphics.rectangle("fill", x + padding + 30, rowY + 5, leaderboard.entryHeight - 10, leaderboard.entryHeight - 10)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(entry.name, x + padding + 30 + leaderboard.entryHeight, rowY + (leaderboard.entryHeight - gameFonts.small:getHeight(entry.name))/2, 0, 1)
        love.graphics.print(tostring(entry.wealth or 0), x + width - padding - 120, rowY + (leaderboard.entryHeight - gameFonts.small:getHeight(tostring(entry.wealth or 0)))/2, 0, 1)
        love.graphics.print(tostring(entry.score or 0), x + width - padding - 50, rowY + (leaderboard.entryHeight - gameFonts.small:getHeight(tostring(entry.score or 0)))/2, 0, 1)
    end
end

function updateLeaderboard()
    local found = false
    for i, entry in ipairs(leaderboard.entries) do
        if entry.name == player.name then
            entry.score = player.claimedTiles
            entry.wealth = player.wealth
            entry.color = player.color
            found = true
            break
        end
    end
    if not found then
        table.insert(leaderboard.entries, {
            name = player.name,
            score = player.claimedTiles,
            wealth = player.wealth,
            color = player.color
        })
    end
    table.sort(leaderboard.entries, function(a, b) return (a.wealth or 0) > (b.wealth or 0) end)
end

function drawColorSelection()
    love.graphics.setColor(0, 0, 0, UI_BACKGROUND_OPACITY)
    love.graphics.rectangle("fill", 0, 0, windowWidth, windowHeight)
    
    love.graphics.setFont(gameFonts.title)
    love.graphics.setColor(1, 1, 1)
    local titleText = "Select Your Color"
    local titleWidth = gameFonts.title:getWidth(titleText)
    love.graphics.print(titleText, windowWidth/2 - titleWidth/2, windowHeight/4, 0, 1)
    
    love.graphics.setFont(gameFonts.large)
    love.graphics.print("Enter your name:", windowWidth/2 - 100, windowHeight/3, 0, 1)
    
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.rectangle("fill", textInput.x, textInput.y, textInput.width, textInput.height)
    
    if textInput.active then
        love.graphics.setColor(0.2, 0.8, 0.2)
    else
        love.graphics.setColor(0.5, 0.5, 0.5)
    end
    love.graphics.rectangle("line", textInput.x, textInput.y, textInput.width, textInput.height)
    
    love.graphics.setFont(gameFonts.normal)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(player.name, textInput.x + 10, textInput.y + 10, 0, 1)
    
    if textInput.active and math.floor(textInput.blinkTime / textInput.blinkRate) % 2 == 0 then
        local cursorX = textInput.x + 10 + gameFonts.normal:getWidth(player.name:sub(1, textInput.cursor))
        love.graphics.line(cursorX, textInput.y + 5, cursorX, textInput.y + textInput.height - 5)
    end
    
    local paletteSize = 60
    local paletteSpacing = 20
    local totalPaletteWidth = (#playerColors * (paletteSize + paletteSpacing)) - paletteSpacing
    local startX = windowWidth/2 - totalPaletteWidth/2
    local startY = windowHeight/2 - paletteSize/2
    
    for i, colorData in ipairs(playerColors) do
        local x = startX + (i-1) * (paletteSize + paletteSpacing)
        local y = startY
        if i == player.colorIndex then
            love.graphics.setColor(1, 1, 1)
            love.graphics.rectangle("line", x - 5, y - 5, paletteSize + 10, paletteSize + 10)
        end
        love.graphics.setColor(colorData.color)
        love.graphics.rectangle("fill", x, y, paletteSize, paletteSize)
        
        love.graphics.setFont(gameFonts.small)
        love.graphics.setColor(1, 1, 1)
        local colorName = colorData.name
        local nameWidth = gameFonts.small:getWidth(colorName)
        love.graphics.print(colorName, x + paletteSize/2 - nameWidth/2, y + paletteSize + 5, 0, 1)
    end
    
    local buttonWidth = 200
    local buttonHeight = 50
    local buttonX = windowWidth/2 - buttonWidth/2
    local buttonY = startY + paletteSize + 50
    
    if player.colorIndex then
        love.graphics.setColor(0.2, 0.8, 0.2, 0.8)
    else
        love.graphics.setColor(0.5, 0.5, 0.5, 0.8)
    end
    love.graphics.rectangle("fill", buttonX, buttonY, buttonWidth, buttonHeight)
    
    love.graphics.setColor(1, 1, 1, 0.3)
    love.graphics.rectangle("line", buttonX, buttonY, buttonWidth, buttonHeight)
    
    love.graphics.setFont(gameFonts.large)
    love.graphics.setColor(1, 1, 1)
    local buttonText = "Start Game"
    local buttonTextWidth = gameFonts.large:getWidth(buttonText)
    love.graphics.print(buttonText, buttonX + buttonWidth/2 - buttonTextWidth/2, buttonY + buttonHeight/2 - gameFonts.large:getHeight(buttonText)/2, 0, 1)
end

function drawGameUI()
    love.graphics.setColor(0, 0, 0, UI_BACKGROUND_OPACITY)
    love.graphics.rectangle("fill", 0, 0, 300, 150)
    love.graphics.setColor(1, 1, 1, UI_BORDER_OPACITY)
    love.graphics.rectangle("line", 0, 0, 300, 150)
    
    local padding = UI_PADDING
    local lineHeight = 30
    local startY = padding
    
    local instructions = {
        "Use WASD to move",
        "Click to claim tiles",
        "Claimed tiles: " .. player.claimedTiles,
        "Press R to regenerate map"
    }
    
    love.graphics.setFont(gameFonts.normal)
    for i, text in ipairs(instructions) do
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(text, padding, startY + (i-1) * lineHeight, 0, 1)
    end
end

function love.draw()
    local camX, camY = getCameraOffset()
    love.graphics.push()
    love.graphics.translate(-camX, -camY)
    love.graphics.clear(0.1, 0.1, 0.1)
    
    love.graphics.setColor(baseplate.color)
    love.graphics.rectangle("fill", baseplate.x, baseplate.y, baseplate.width, baseplate.height)
    
    local startTileX, startTileY, endTileX, endTileY = getVisibleTileRange(camX, camY)
    
    -- Layer 1: Draw base tiles (only visible ones)
    for j = startTileY, endTileY do
        for i = startTileX, endTileX do
            local tile = tiles[j][i]
            if tile.type == "water" then
                love.graphics.setColor(tile.color)
                love.graphics.rectangle("fill", tile.x, tile.y, tile.width, tile.height)
                if j > 0 and tiles[j-1][i].type ~= "water" then
                    love.graphics.line(tile.x, tile.y, tile.x + tile.width, tile.y)
                end
                if i < numTilesX - 1 and tiles[j][i+1].type ~= "water" then
                    love.graphics.line(tile.x + tile.width, tile.y, tile.x + tile.width, tile.y + tile.height)
                end
                if j < numTilesY - 1 and tiles[j+1][i].type ~= "water" then
                    love.graphics.line(tile.x, tile.y + tile.height, tile.x + tile.width, tile.y + tile.height)
                end
                if i > 0 and tiles[j][i-1].type ~= "water" then
                    love.graphics.line(tile.x, tile.y, tile.x, tile.y + tile.height)
                end
            else
                love.graphics.setColor(tile.color)
                love.graphics.rectangle("fill", tile.x, tile.y, tile.width, tile.height)
                love.graphics.setColor(0.3, 0.3, 0.3)
                love.graphics.rectangle("line", tile.x, tile.y, tile.width, tile.height)
            end
        end
    end

    -- Layer 2: Draw claimed tile overlays
    for j = startTileY, endTileY do
        for i = startTileX, endTileX do
            local tile = tiles[j][i]
            if tile.claimed then
                love.graphics.setColor(tile.claimedBy)
                love.graphics.rectangle("fill", tile.x, tile.y, tile.width, tile.height)
                local tileX = i
                local tileY = j
                love.graphics.setColor(1, 1, 1, OUTLINE_OPACITY)
                if tileY > 0 and not tiles[tileY-1][tileX].claimed then
                    love.graphics.line(tile.x, tile.y, tile.x + tile.width, tile.y)
                end
                if tileY < numTilesY - 1 and not tiles[tileY+1][tileX].claimed then
                    love.graphics.line(tile.x, tile.y + tile.height, tile.x + tile.width, tile.y + tile.height)
                end
                if tileX > 0 and not tiles[tileY][tileX-1].claimed then
                    love.graphics.line(tile.x, tile.y, tile.x, tile.y + tile.height)
                end
                if tileX < numTilesX - 1 and not tiles[tileY][tileX+1].claimed then
                    love.graphics.line(tile.x + tile.width, tile.y, tile.x + tile.width, tile.y + tile.height)
                end
            end
        end
    end

    -- Layer 3: Draw hover effect (only for the current hovered tile)
    if currentHoveredTileX and currentHoveredTileY then
        local tile = tiles[currentHoveredTileY][currentHoveredTileX]
        love.graphics.setColor(1, 1, 1, 0.7)
        love.graphics.rectangle("line", tile.x, tile.y, tile.width, tile.height)
    end
    
    if player.color then
        love.graphics.setColor(player.color)
        love.graphics.rectangle("fill", player.x, player.y, player.width, player.height)
        love.graphics.setColor(1, 1, 1, 0.5)
        love.graphics.rectangle("line", player.x, player.y, player.width, player.height)
        love.graphics.setFont(gameFonts.small)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(player.name, player.x, player.y - 20)
    end
    
    love.graphics.pop()
    
    if gameState == "joining" then
        drawColorSelection()
    else
        drawGameUI()
        drawLeaderboard()
    end
    
    love.graphics.setFont(gameFonts.small)
    love.graphics.setColor(1, 1, 1)
    local fpsText = "FPS: " .. love.timer.getFPS()
    love.graphics.print(fpsText, 10, love.graphics.getHeight() - gameFonts.small:getHeight() - 10)
    
    local minimapSize = 200
    local minimapMargin = 20
    local minimapX = windowWidth - minimapSize - minimapMargin
    local minimapY = windowHeight - minimapSize - minimapMargin
    local scale = minimapSize / MAP_WIDTH
    love.graphics.setColor(1, 1, 1, 0.3)
    love.graphics.rectangle("fill", minimapX, minimapY, minimapSize, minimapSize)
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", minimapX, minimapY, minimapSize, minimapSize)
    
    for j = 0, numTilesY - 1 do
        for i = 0, numTilesX - 1 do
            local tile = tiles[j][i]
            local col = tile.claimed and tile.claimedBy or tile.color
            love.graphics.setColor(col)
            love.graphics.rectangle("fill", minimapX + tile.x * scale, minimapY + tile.y * scale, tile.width * scale, tile.height * scale)
        end
    end
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("fill", minimapX + player.x * scale, minimapY + player.y * scale, player.width * scale, player.height * scale)
end

function love.mousepressed(x, y, button)
    if button == 1 then
        if gameState == "joining" then
            handleJoiningStateClick(x, y)
        else
            handlePlayingStateClick(x, y)
        end
    end
end

function handleJoiningStateClick(x, y)
    if x >= textInput.x and x <= textInput.x + textInput.width and
       y >= textInput.y and y <= textInput.y + textInput.height then
        textInput.active = true
        textInput.cursor = #player.name
    else
        textInput.active = false
    end
    
    local paletteSize = 60
    local paletteSpacing = 20
    local totalPaletteWidth = (#playerColors * (paletteSize + paletteSpacing)) - paletteSpacing
    local startX = windowWidth/2 - totalPaletteWidth/2
    local startY = windowHeight/2 - paletteSize/2
    
    for i, colorData in ipairs(playerColors) do
        if x >= startX + (i-1) * (paletteSize + paletteSpacing) and 
           x <= startX + (i-1) * (paletteSize + paletteSpacing) + paletteSize and
           y >= startY and y <= startY + paletteSize then
            player.colorIndex = i
            player.color = colorData.color
        end
    end
    
    local buttonWidth = 200
    local buttonHeight = 50
    local buttonX = windowWidth/2 - buttonWidth/2
    local buttonY = startY + paletteSize + 50
    
    if player.colorIndex and
       x >= buttonX and x <= buttonX + buttonWidth and
       y >= buttonY and y <= buttonY + buttonHeight then
        gameState = "playing"
    end
end

function isTileAdjacentToOwner(tileX, tileY, ownerColor)
    local directions = {
        {x = -1, y = 0},
        {x = 1, y = 0},
        {x = 0, y = -1},
        {x = 0, y = 1}
    }
    for _, dir in ipairs(directions) do
        local nx = tileX + dir.x
        local ny = tileY + dir.y
        if nx >= 0 and nx < numTilesX and ny >= 0 and ny < numTilesY then
            local neighbor = tiles[ny][nx]
            if neighbor and neighbor.claimed and neighbor.claimedBy and 
               neighbor.claimedBy[1] == ownerColor[1] and 
               neighbor.claimedBy[2] == ownerColor[2] and 
               neighbor.claimedBy[3] == ownerColor[3] then
                return true
            end
        end
    end
    return false
end

function handlePlayingStateClick(x, y)
    local camX, camY = getCameraOffset()
    local worldX = x + camX
    local worldY = y + camY
    local tileX = math.floor(worldX / TILE_SIZE)
    local tileY = math.floor(worldY / TILE_SIZE)
    
    if tileY >= 0 and tileY < numTilesY and tileX >= 0 and tileX < numTilesX then
        local tile = tiles[tileY][tileX]
        if tile and tile.claimable and not tile.claimed and player.wealth >= 1 then
            if player.claimedTiles == 0 or isTileAdjacentToOwner(tileX, tileY, player.color) then
                tile.claimed = true
                tile.claimedBy = player.color
                player.claimedTiles = player.claimedTiles + 1
                player.wealth = player.wealth - 1
            end
        end
    end
end

function love.textinput(t)
    if textInput.active then
        player.name = player.name:sub(1, textInput.cursor) .. t .. player.name:sub(textInput.cursor + 1)
        textInput.cursor = textInput.cursor + 1
    end
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    elseif key == "r" and gameState == "playing" then
        player.claimedTiles = 0
        generateTilemap()
    elseif key:match("%d") and gameState == "joining" then
        local num = tonumber(key)
        if num >= 1 and num <= #playerColors then
            player.colorIndex = num
            player.color = playerColors[num].color
        end
    elseif textInput.active then
        handleTextInputKey(key)
    end
end

function handleTextInputKey(key)
    if key == "backspace" then
        if textInput.cursor > 0 then
            player.name = player.name:sub(1, textInput.cursor - 1) .. player.name:sub(textInput.cursor + 1)
            textInput.cursor = textInput.cursor - 1
        end
    elseif key == "left" then
        textInput.cursor = math.max(0, textInput.cursor - 1)
    elseif key == "right" then
        textInput.cursor = math.min(#player.name, textInput.cursor + 1)
    elseif key == "return" then
        textInput.active = false
    end
end
