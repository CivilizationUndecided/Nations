-- Simple Top-Down Game with Claimable Tiles

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

-- Game state
local gameState = "joining"  -- "joining" or "playing"
local windowWidth, windowHeight = love.graphics.getDimensions()
-- Ensure tiles fill the entire window by rounding up
local numTilesX = math.ceil(windowWidth / TILE_SIZE)
local numTilesY = math.ceil(windowHeight / TILE_SIZE)

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
    isTyping = false
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
    width = windowWidth,
    height = windowHeight,
    color = {0.2, 0.2, 0.2}
}

-- Game data
local tiles = {}

function love.load()
    -- Set the window title
    love.window.setTitle("Top-Down Game")
    
    -- Enable high-quality text rendering with nearest neighbor filtering
    love.graphics.setDefaultFilter("nearest", "nearest")
    
    -- Set line width for thicker outlines
    love.graphics.setLineWidth(2)
    
    -- Generate tilemap
    generateTilemap()
end

function generateTilemap()
    -- Initialize random seed
    math.randomseed(os.time())
    
    -- Generate tiles
    for y = 0, numTilesY - 1 do
        tiles[y] = {}
        for x = 0, numTilesX - 1 do
            -- Random tile type with solid colors
            local tileType = math.random()
            local color
            if tileType < 0.3 then
                color = {0.2, 0.5, 0.2}  -- Solid grass
            elseif tileType < 0.6 then
                color = {0.5, 0.3, 0.1}  -- Solid dirt
            else
                color = {0.4, 0.4, 0.4}  -- Solid stone
            end
            
            -- Calculate tile position and size
            local tileX = x * TILE_SIZE
            local tileY = y * TILE_SIZE
            local tileWidth = TILE_SIZE
            local tileHeight = TILE_SIZE
            
            -- Adjust tiles on the right and bottom edges to fill the window
            if x == numTilesX - 1 then
                tileWidth = windowWidth - tileX
            end
            if y == numTilesY - 1 then
                tileHeight = windowHeight - tileY
            end
            
            tiles[y][x] = {
                x = tileX,
                y = tileY,
                width = tileWidth,
                height = tileHeight,
                color = color,
                claimed = false,
                claimable = true,
                claimedBy = nil,
                hovered = false
            }
        end
    end
end

function love.update(dt)
    if gameState == "playing" then
        updatePlayerMovement(dt)
        updateTileHoverStates()
    end
    
    -- Update text input cursor blink
    if textInput.active then
        textInput.blinkTime = textInput.blinkTime + dt
    end
end

function updatePlayerMovement(dt)
    -- Handle movement with WASD
    if love.keyboard.isDown("a") then
        player.x = player.x - player.speed * dt
    end
    if love.keyboard.isDown("d") then
        player.x = player.x + player.speed * dt
    end
    if love.keyboard.isDown("w") then
        player.y = player.y - player.speed * dt
    end
    if love.keyboard.isDown("s") then
        player.y = player.y + player.speed * dt
    end
    
    -- Keep player in bounds
    player.x = math.max(0, math.min(windowWidth - player.width, player.x))
    player.y = math.max(0, math.min(windowHeight - player.height, player.y))
end

function updateTileHoverStates()
    local mouseX, mouseY = love.mouse.getPosition()
    local tileX = math.floor(mouseX / TILE_SIZE)
    local tileY = math.floor(mouseY / TILE_SIZE)
    
    -- Reset all hover states
    for y = 0, numTilesY - 1 do
        for x = 0, numTilesX - 1 do
            tiles[y][x].hovered = false
        end
    end
    
    -- Set hover state for current tile
    if tileY >= 0 and tileY < numTilesY and tileX >= 0 and tileX < numTilesX then
        tiles[tileY][tileX].hovered = true
    end
end

function drawTile(tile)
    -- Draw tile base color
    if tile.hovered and not tile.claimed then
        love.graphics.setColor(tile.color[1] * HOVER_BRIGHTNESS, tile.color[2] * HOVER_BRIGHTNESS, tile.color[3] * HOVER_BRIGHTNESS)
    else
        love.graphics.setColor(tile.color)
    end
    love.graphics.rectangle("fill", tile.x, tile.y, tile.width, tile.height)
    
    -- Draw tile border only for unclaimed tiles
    if not tile.claimed then
        love.graphics.setColor(0.3, 0.3, 0.3)
        love.graphics.rectangle("line", tile.x, tile.y, tile.width, tile.height)
    end
    
    -- Draw claimed status and outline
    if tile.claimed then
        love.graphics.setColor(tile.claimedBy)
        love.graphics.rectangle("fill", tile.x, tile.y, tile.width, tile.height)
        
        -- Check adjacent tiles for outline
        local tileX = math.floor(tile.x / TILE_SIZE)
        local tileY = math.floor(tile.y / TILE_SIZE)
        
        -- Draw outline only if adjacent to unclaimed tile
        local shouldOutline = false
        
        -- Check all sides
        if tileY > 0 and not tiles[tileY-1][tileX].claimed then
            shouldOutline = true
        end
        if tileY < numTilesY-1 and not tiles[tileY+1][tileX].claimed then
            shouldOutline = true
        end
        if tileX > 0 and not tiles[tileY][tileX-1].claimed then
            shouldOutline = true
        end
        if tileX < numTilesX-1 and not tiles[tileY][tileX+1].claimed then
            shouldOutline = true
        end
        
        -- Draw outline if needed
        if shouldOutline then
            love.graphics.setColor(1, 1, 1, OUTLINE_OPACITY)
            -- Draw all sides that are adjacent to unclaimed tiles
            if tileY > 0 and not tiles[tileY-1][tileX].claimed then
                love.graphics.line(tile.x, tile.y, tile.x + tile.width, tile.y)  -- Top
            end
            if tileY < numTilesY-1 and not tiles[tileY+1][tileX].claimed then
                love.graphics.line(tile.x, tile.y + tile.height, tile.x + tile.width, tile.y + tile.height)  -- Bottom
            end
            if tileX > 0 and not tiles[tileY][tileX-1].claimed then
                love.graphics.line(tile.x, tile.y, tile.x, tile.y + tile.height)  -- Left
            end
            if tileX < numTilesX-1 and not tiles[tileY][tileX+1].claimed then
                love.graphics.line(tile.x + tile.width, tile.y, tile.x + tile.width, tile.y + tile.height)  -- Right
            end
        end
    end
end

function drawLeaderboard()
    -- Draw leaderboard background with border
    love.graphics.setColor(0, 0, 0, UI_BACKGROUND_OPACITY)
    love.graphics.rectangle("fill", leaderboard.x, leaderboard.y, leaderboard.width, #leaderboard.entries * leaderboard.entryHeight + leaderboard.padding * 2)
    love.graphics.setColor(1, 1, 1, UI_BORDER_OPACITY)
    love.graphics.rectangle("line", leaderboard.x, leaderboard.y, leaderboard.width, #leaderboard.entries * leaderboard.entryHeight + leaderboard.padding * 2)
    
    -- Draw title with underline
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Leaderboard", leaderboard.x + leaderboard.padding, leaderboard.y + leaderboard.padding, 0, 1.5)
    love.graphics.line(leaderboard.x + leaderboard.padding, leaderboard.y + leaderboard.padding + 25, 
                      leaderboard.x + leaderboard.width - leaderboard.padding, leaderboard.y + leaderboard.padding + 25)
    
    -- Draw column headers
    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.print("Player", leaderboard.x + leaderboard.padding + 30, leaderboard.y + leaderboard.padding + 30, 0, 1)
    love.graphics.print("Wealth", leaderboard.x + leaderboard.width - leaderboard.padding - 120, leaderboard.y + leaderboard.padding + 30, 0, 1)
    love.graphics.print("Tiles", leaderboard.x + leaderboard.width - leaderboard.padding - 40, leaderboard.y + leaderboard.padding + 30, 0, 1)
    
    -- Draw entries
    for i, entry in ipairs(leaderboard.entries) do
        local y = leaderboard.y + leaderboard.padding + 60 + (i-1) * leaderboard.entryHeight
        
        -- Draw entry background for current player
        if entry.name == player.name then
            love.graphics.setColor(1, 1, 1, 0.1)
            love.graphics.rectangle("fill", leaderboard.x + leaderboard.padding, y - 5, leaderboard.width - leaderboard.padding * 2, leaderboard.entryHeight + 10)
        end
        
        -- Draw rank number
        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.print(i .. ".", leaderboard.x + leaderboard.padding, y + 5, 0, 1)
        
        -- Draw color icon
        love.graphics.setColor(entry.color)
        love.graphics.rectangle("fill", leaderboard.x + leaderboard.padding + 30, y + 5, 20, 20)
        love.graphics.setColor(1, 1, 1, 0.5)
        love.graphics.rectangle("line", leaderboard.x + leaderboard.padding + 30, y + 5, 20, 20)
        
        -- Draw name and scores
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(entry.name, leaderboard.x + leaderboard.padding + 60, y + 5, 0, 1)
        love.graphics.print(entry.wealth or 0, leaderboard.x + leaderboard.width - leaderboard.padding - 120, y + 5, 0, 1)
        love.graphics.print(entry.score, leaderboard.x + leaderboard.width - leaderboard.padding - 40, y + 5, 0, 1)
    end
end

function updateLeaderboard()
    -- Update or add current player to leaderboard
    local found = false
    for i, entry in ipairs(leaderboard.entries) do
        if entry.name == player.name then
            entry.score = player.claimedTiles
            entry.wealth = player.claimedTiles * WEALTH_MULTIPLIER
            entry.color = player.color
            found = true
            break
        end
    end
    
    if not found then
        table.insert(leaderboard.entries, {
            name = player.name,
            score = player.claimedTiles,
            wealth = player.claimedTiles * WEALTH_MULTIPLIER,
            color = player.color
        })
    end
    
    -- Sort leaderboard by wealth (highest first)
    table.sort(leaderboard.entries, function(a, b) return (a.wealth or 0) > (b.wealth or 0) end)
end

function drawColorSelection()
    -- Draw semi-transparent overlay
    love.graphics.setColor(0, 0, 0, UI_BACKGROUND_OPACITY)
    love.graphics.rectangle("fill", 0, 0, windowWidth, windowHeight)
    
    -- Draw title
    love.graphics.setColor(1, 1, 1)
    local titleText = "Select Your Color"
    local titleFont = love.graphics.getFont()
    local titleWidth = titleFont:getWidth(titleText) * 2
    love.graphics.print(titleText, windowWidth/2 - titleWidth/2, windowHeight/4, 0, 2)
    
    -- Draw name input box
    love.graphics.print("Enter your name:", windowWidth/2 - 100, windowHeight/3, 0, 1.5)
    
    -- Draw input box background
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.rectangle("fill", textInput.x, textInput.y, textInput.width, textInput.height)
    
    -- Draw input box border
    if textInput.active then
        love.graphics.setColor(0.2, 0.8, 0.2)
    else
        love.graphics.setColor(0.5, 0.5, 0.5)
    end
    love.graphics.rectangle("line", textInput.x, textInput.y, textInput.width, textInput.height)
    
    -- Draw text and cursor
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(player.name, textInput.x + 10, textInput.y + 10, 0, 1.5)
    
    if textInput.active and math.floor(textInput.blinkTime / textInput.blinkRate) % 2 == 0 then
        local cursorX = textInput.x + 10 + love.graphics.getFont():getWidth(player.name:sub(1, textInput.cursor)) * 1.5
        love.graphics.line(cursorX, textInput.y + 5, cursorX, textInput.y + textInput.height - 5)
    end
    
    -- Draw color palette
    local paletteSize = 60
    local paletteSpacing = 20
    local totalPaletteWidth = (#playerColors * (paletteSize + paletteSpacing)) - paletteSpacing
    local startX = windowWidth/2 - totalPaletteWidth/2
    local startY = windowHeight/2 - paletteSize/2
    
    for i, colorData in ipairs(playerColors) do
        local x = startX + (i-1) * (paletteSize + paletteSpacing)
        local y = startY
        
        -- Draw color box with selection indicator
        if i == player.colorIndex then
            love.graphics.setColor(1, 1, 1)
            love.graphics.rectangle("line", x - 5, y - 5, paletteSize + 10, paletteSize + 10)
        end
        
        love.graphics.setColor(colorData.color)
        love.graphics.rectangle("fill", x, y, paletteSize, paletteSize)
        
        -- Draw color name
        love.graphics.setColor(1, 1, 1)
        local colorName = colorData.name
        local nameWidth = titleFont:getWidth(colorName)
        love.graphics.print(colorName, x + paletteSize/2 - nameWidth/2, y + paletteSize + 5, 0, 1)
    end
    
    -- Draw start game button
    local buttonWidth = 200
    local buttonHeight = 50
    local buttonX = windowWidth/2 - buttonWidth/2
    local buttonY = startY + paletteSize + 50
    
    if player.colorIndex then
        love.graphics.setColor(0.2, 0.8, 0.2)
    else
        love.graphics.setColor(0.5, 0.5, 0.5)
    end
    love.graphics.rectangle("fill", buttonX, buttonY, buttonWidth, buttonHeight)
    
    -- Center the "Start Game" text
    love.graphics.setColor(1, 1, 1)
    local buttonText = "Start Game"
    local buttonTextWidth = titleFont:getWidth(buttonText) * 1.5
    love.graphics.print(buttonText, buttonX + buttonWidth/2 - buttonTextWidth/2, buttonY + buttonHeight/2 - 10, 0, 1.5)
end

function drawGameUI()
    -- Draw semi-transparent background for game UI
    love.graphics.setColor(0, 0, 0, UI_BACKGROUND_OPACITY)
    love.graphics.rectangle("fill", 0, 0, 300, 150)
    love.graphics.setColor(1, 1, 1, UI_BORDER_OPACITY)
    love.graphics.rectangle("line", 0, 0, 300, 150)
    
    local padding = UI_PADDING
    local lineHeight = 30
    local startY = padding
    
    -- Draw instructions with consistent spacing
    local instructions = {
        "Use WASD to move",
        "Click to claim tiles",
        "Claimed tiles: " .. player.claimedTiles,
        "Press R to regenerate map"
    }
    
    for i, text in ipairs(instructions) do
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(text, padding, startY + (i-1) * lineHeight, 0, 1.5)
    end
end

function love.draw()
    -- Clear the screen with a dark background
    love.graphics.clear(0.1, 0.1, 0.1)
    
    -- Draw baseplate
    love.graphics.setColor(baseplate.color)
    love.graphics.rectangle("fill", baseplate.x, baseplate.y, baseplate.width, baseplate.height)
    
    -- Draw tiles
    for y = 0, numTilesY - 1 do
        for x = 0, numTilesX - 1 do
            drawTile(tiles[y][x])
        end
    end
    
    -- Draw player if color is selected
    if player.color then
        love.graphics.setColor(player.color)
        love.graphics.rectangle("fill", player.x, player.y, player.width, player.height)
        -- Draw player border
        love.graphics.setColor(1, 1, 1, 0.5)
        love.graphics.rectangle("line", player.x, player.y, player.width, player.height)
    end
    
    -- Draw UI based on game state
    if gameState == "joining" then
        drawColorSelection()
    else
        drawGameUI()
        updateLeaderboard()
        drawLeaderboard()
    end
end

function love.mousepressed(x, y, button)
    if button == 1 then  -- Left click
        if gameState == "joining" then
            handleJoiningStateClick(x, y)
        else
            handlePlayingStateClick(x, y)
        end
    end
end

function handleJoiningStateClick(x, y)
    -- Check if clicking text input box
    if x >= textInput.x and x <= textInput.x + textInput.width and
       y >= textInput.y and y <= textInput.y + textInput.height then
        textInput.active = true
        textInput.cursor = #player.name
    else
        textInput.active = false
    end
    
    -- Check if clicking color palette
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
    
    -- Check if clicking start game button
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

function handlePlayingStateClick(x, y)
    -- Convert mouse position to tile coordinates
    local tileX = math.floor(x / TILE_SIZE)
    local tileY = math.floor(y / TILE_SIZE)
    
    -- Check if tile exists and is claimable
    if tileY >= 0 and tileY < numTilesY and tileX >= 0 and tileX < numTilesX then
        local tile = tiles[tileY][tileX]
        if tile and tile.claimable and not tile.claimed then
            tile.claimed = true
            tile.claimedBy = player.color
            player.claimedTiles = player.claimedTiles + 1
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
        -- Reset claimed tiles count
        player.claimedTiles = 0
        -- Generate new tilemap
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
