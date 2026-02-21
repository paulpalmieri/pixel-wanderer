-- core/world.lua
-- Shared state bag factory

local M = {}

-- Upgrades persist across game runs (carried on world.upgrades, passed in on new())
function M.new(upgrades)
    return {
        player = nil,           -- owned by sys/player
        ground = nil,           -- set once by gen/ground
        trees = {},             -- owned by sys/combat (damage), gen/tree (spawning)
        wood_chunks = {},       -- owned by sys/physics
        particles = {},         -- owned by sys/physics (spawned by sys/combat, sys/player)
        floating_texts = {},    -- owned by sys/physics
        cloud_layers = {},      -- set by gen/cloud, scrolled by sys/camera
        camera_x = 0,           -- owned by sys/camera
        camera_y = 0,           -- owned by sys/camera
        canvas = nil,           -- set in love.load
        font = nil,             -- set in love.load
        pickup_chain = 0,       -- used by gen/sound
        pickup_chain_timer = 0, -- used by gen/sound
        resource_accum = { wood = 0 },  -- owned by sys/physics
        resource_accum_timer = 0,       -- owned by sys/physics
        resource_log = {},              -- owned by sys/physics, drawn by draw/hud
        flying_chunks = {},             -- owned by sys/physics, drawn by draw/hud
        robots = {},                    -- owned by sys/robot
        -- Entrance door system
        entrance_x = 4,                 -- left wall width (WALL_WIDTH)
        door_state = "closed",          -- "closed", "opening", "open", "walk_in", "done"
        door_timer = 0,                 -- animation progress
        door_open_amount = 0,           -- 0..1 how far open the door panels are
        entrance_anim_done = false,     -- player has control after this
        entrance_walk_target = 0,       -- x position player walks to after door opens
        -- Battery / game flow
        battery = nil,          -- set after sys_player.create(), based on upgrades
        game_state = "playing", -- "playing", "gameover", "skilltree"
        wood_at_game_end = 0,   -- wood count when battery ran out
        -- Persistent upgrades (survive across game restarts)
        upgrades = upgrades or {
            free_robot    = false,  -- spawns one robot for free at game start
            battery_bonus = 0,      -- extra seconds added to starting battery
            axe_damage    = 0,      -- extra flat damage per hit
        },
    }
end

return M
