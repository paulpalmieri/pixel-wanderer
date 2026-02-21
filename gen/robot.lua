-- gen/robot.lua
-- Similar to character generator, but generates robot NPC entities

local gen_char = require("gen.character")

local M = {}

function M.generate(x, y)
    -- Start with character sprite components
    local sprite = gen_char.generate()
    
    return {
        x = x,
        y = y,
        vy = 0,
        facing = 1,
        state = "IDLE",     -- IDLE, SEEK_TREE, CHOP, SEEK_WOOD
        timer = 0,
        target_tree = nil,
        target_wood = nil,
        sprite = sprite,
        
        -- Walk animation 
        walk_timer = 0,
        walk_frame = 0,
        moving = false,
        walk_dust_cd = 0,

        -- Idle look
        idle_timer = 0,
        idle_look_dir = 0,
        idle_look_timer = 0,
        idle_look_next = 2 + math.random() * 2,

        -- Axe animation similar to player
        axe_swing = 0,
        axe_cooldown = 0,
        axe_has_hit = false,

        -- Bouncing
        squash_timer = 0,
        squash_duration = 0.25,
    }
end

return M
