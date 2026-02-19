-- core/world.lua
-- Shared state bag factory

local M = {}

function M.new()
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
    }
end

return M
