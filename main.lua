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
local MAP_WIDTH = windowWidth * 2
local MAP_HEIGHT = windowHeight * 2
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
    width = MAP_WIDTH,
    height = MAP_HEIGHT,
    color = {0.2, 0.2, 0.2}
}

-- Game data
local tiles = {}

function love.load()
    -- Set the window title
    love.window.setTitle("Nations")
    
    -- Enable high-quality text rendering with nearest neighbor filtering
    love.graphics.setDefaultFilter("nearest", "nearest")
    
    -- Set line width for thicker outlines
    love.graphics.setLineWidth(2)
    
    -- Load custom fonts
    gameFonts.small = love.graphics.newFont("assets/fonts/OpenSans-Regular.ttf", FONT_SIZE_SMALL)
    gameFonts.normal = love.graphics.newFont("assets/fonts/OpenSans-Regular.ttf", FONT_SIZE_NORMAL)
    gameFonts.large = love.graphics.newFont("assets/fonts/OpenSans-Regular.ttf", FONT_SIZE_LARGE)
    gameFonts.title = love.graphics.newFont("assets/fonts/OpenSans-Regular.ttf", FONT_SIZE_TITLE)
    
    -- Set default font
    love.graphics.setFont(gameFonts.normal)
    
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
                tileWidth = MAP_WIDTH - tileX
            end
            if y == numTilesY - 1 then
                tileHeight = MAP_HEIGHT - tileY
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

function getCameraOffset()
    local camX = math.max(0, math.min(player.x + player.width/2 - windowWidth/2, MAP_WIDTH - windowWidth))
    local camY = math.max(0, math.min(player.y + player.height/2 - windowHeight/2, MAP_HEIGHT - windowHeight))
    return camX, camY
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
    player.x = math.max(0, math.min(MAP_WIDTH - player.width, player.x))
    player.y = math.max(0, math.min(MAP_HEIGHT - player.height, player.y))
end

function updateTileHoverStates()
    local mouseX, mouseY = love.mouse.getPosition()
    local camX, camY = getCameraOffset()
    local worldX = mouseX + camX
    local worldY = mouseY + camY
    local tileX = math.floor(worldX / TILE_SIZE)
    local tileY = math.floor(worldY / TILE_SIZE)
    
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
    love.graphics.rectangle("fill", x, colHeaderY, width, rowHeight)

    love.graphics.setFont(gameFonts.normal)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Rank", x + padding, colHeaderY + (rowHeight - gameFonts.normal:getHeight())/2, 0, 1)
    love.graphics.print("Player", x + padding + 50, colHeaderY + (rowHeight - gameFonts.normal:getHeight())/2, 0, 1)
    love.graphics.print("Wealth", x + width - padding - 120, colHeaderY + (rowHeight - gameFonts.normal:getHeight())/2, 0, 1)
    love.graphics.print("Tiles", x + width - padding - 50, colHeaderY + (rowHeight - gameFonts.normal:getHeight())/2, 0, 1)

    local startY = colHeaderY + rowHeight
    love.graphics.setFont(gameFonts.small)
    for i, entry in ipairs(leaderboard.entries) do
        local rowY = startY + (i-1) * rowHeight

        if i % 2 == 0 then
            love.graphics.setColor(1, 1, 1, 0.05)
            love.graphics.rectangle("fill", x, rowY, width, rowHeight)
        end

        love.graphics.setColor(1, 1, 1)
        love.graphics.print(tostring(i), x + padding, rowY + (rowHeight - gameFonts.small:getHeight(tostring(i)))/2, 0, 1)

        love.graphics.setColor(entry.color)
        love.graphics.rectangle("fill", x + padding + 30, rowY + 5, rowHeight - 10, rowHeight - 10)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(entry.name, x + padding + 30 + rowHeight, rowY + (rowHeight - gameFonts.small:getHeight(entry.name))/2, 0, 1)
        love.graphics.print(tostring(entry.wealth or 0), x + width - padding - 120, rowY + (rowHeight - gameFonts.small:getHeight(tostring(entry.wealth or 0)))/2, 0, 1)
        love.graphics.print(tostring(entry.score or 0), x + width - padding - 50, rowY + (rowHeight - gameFonts.small:getHeight(tostring(entry.score or 0)))/2, 0, 1)
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
    love.graphics.setFont(gameFonts.title)
    love.graphics.setColor(1, 1, 1)
    local titleText = "Select Your Color"
    local titleWidth = gameFonts.title:getWidth(titleText)
    love.graphics.print(titleText, windowWidth/2 - titleWidth/2, windowHeight/4, 0, 1)
    
    -- Draw name input box
    love.graphics.setFont(gameFonts.large)
    love.graphics.print("Enter your name:", windowWidth/2 - 100, windowHeight/3, 0, 1)
    
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
    love.graphics.setFont(gameFonts.normal)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(player.name, textInput.x + 10, textInput.y + 10, 0, 1)
    
    if textInput.active and math.floor(textInput.blinkTime / textInput.blinkRate) % 2 == 0 then
        local cursorX = textInput.x + 10 + gameFonts.normal:getWidth(player.name:sub(1, textInput.cursor))
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
        love.graphics.setFont(gameFonts.small)
        love.graphics.setColor(1, 1, 1)
        local colorName = colorData.name
        local nameWidth = gameFonts.small:getWidth(colorName)
        love.graphics.print(colorName, x + paletteSize/2 - nameWidth/2, y + paletteSize + 5, 0, 1)
    end
    
    -- Draw start game button
    local buttonWidth = 200
    local buttonHeight = 50
    local buttonX = windowWidth/2 - buttonWidth/2
    local buttonY = startY + paletteSize + 50
    
    -- Draw button background with gradient effect
    if player.colorIndex then
        love.graphics.setColor(0.2, 0.8, 0.2, 0.8)
    else
        love.graphics.setColor(0.5, 0.5, 0.5, 0.8)
    end
    love.graphics.rectangle("fill", buttonX, buttonY, buttonWidth, buttonHeight)
    
    -- Draw button border
    love.graphics.setColor(1, 1, 1, 0.3)
    love.graphics.rectangle("line", buttonX, buttonY, buttonWidth, buttonHeight)
    
    -- Center the "Start Game" text
    love.graphics.setFont(gameFonts.large)
    love.graphics.setColor(1, 1, 1)
    local buttonText = "Start Game"
    local buttonTextWidth = gameFonts.large:getWidth(buttonText)
    love.graphics.print(buttonText, buttonX + buttonWidth/2 - buttonTextWidth/2, buttonY + buttonHeight/2 - gameFonts.large:getHeight(buttonText)/2, 0, 1)
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
    
    love.graphics.setFont(gameFonts.normal)
    for i, text in ipairs(instructions) do
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(text, padding, startY + (i-1) * lineHeight, 0, 1)
    end
end

function love.draw()
    -- Calculate camera offset to center player in viewport
    local camX = math.max(0, math.min(player.x + player.width/2 - windowWidth/2, MAP_WIDTH - windowWidth))
    local camY = math.max(0, math.min(player.y + player.height/2 - windowHeight/2, MAP_HEIGHT - windowHeight))

    love.graphics.push()
    love.graphics.translate(-camX, -camY)

    -- Clear the screen with a dark background
    love.graphics.clear(0.1, 0.1, 0.1)
    
    -- Draw baseplate
    love.graphics.setColor(baseplate.color)
    love.graphics.rectangle("fill", baseplate.x, baseplate.y, baseplate.width, baseplate.height)
    
    -- Draw tiles
    for j = 0, numTilesY - 1 do
        for i = 0, numTilesX - 1 do
            drawTile(tiles[j][i])
        end
    end
    
    -- Draw player if color is selected
    if player.color then
        love.graphics.setColor(player.color)
        love.graphics.rectangle("fill", player.x, player.y, player.width, player.height)
        love.graphics.setColor(1, 1, 1, 0.5)
        love.graphics.rectangle("line", player.x, player.y, player.width, player.height)
        love.graphics.setFont(gameFonts.small)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(player.name, player.x, player.y - 20, 0, 1)
    end
    
    -- Draw UI based on game state (draw UI in screen space)
    love.graphics.pop()  -- End camera transform
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
    local camX, camY = getCameraOffset()
    local worldX = x + camX
    local worldY = y + camY
    local tileX = math.floor(worldX / TILE_SIZE)
    local tileY = math.floor(worldY / TILE_SIZE)
    
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
