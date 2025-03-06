function love.conf(t)
    t.identity = "tile-claim-game"        -- The name of the save directory
    t.version = "11.5"                    -- The LÖVE version this game was made for
    t.console = false                     -- Enable the console (boolean)
    
    -- Only enable modules we're actually using
    t.modules.audio = false               -- Not using audio
    t.modules.data = false                -- Not using data module
    t.modules.event = true                -- Required for window events
    t.modules.font = true                 -- Using for text rendering
    t.modules.graphics = true             -- Required for drawing
    t.modules.image = false               -- Not using images
    t.modules.joystick = false            -- Not using joystick
    t.modules.keyboard = true             -- Using for WASD controls
    t.modules.math = true                 -- Using for calculations
    t.modules.mouse = true                -- Using for tile claiming
    t.modules.sound = false               -- Not using sound
    t.modules.system = true               -- Required for system info
    t.modules.thread = false              -- Not using threads
    t.modules.timer = true                -- Using for animations
    t.modules.touch = false               -- Not using touch
    t.modules.video = false               -- Not using video
    t.modules.window = true               -- Required for window management

    -- Window settings
    t.window.title = "Nations Game"    -- The window title
    t.window.width = 1280                 -- The window width
    t.window.height = 720                 -- The window height
    t.window.resizable = false            -- Fixed window size
    t.window.fullscreen = false           -- Not using fullscreen
    t.window.vsync = 1                    -- Enable vsync for smooth rendering
    t.window.highdpi = true               -- Enable high-dpi support
    t.window.minwidth = 800              -- Minimum window width
    t.window.minheight = 600             -- Minimum window height
    t.window.depth = nil                  -- Default depth buffer
    t.window.stencil = nil                -- Default stencil buffer
    t.window.antialias = 0                -- No antialiasing
    t.window.srgb = false                 -- No sRGB color space
    t.window.fsaa = 0                     -- No fullscreen antialiasing
end 