-- sys/camera.lua
-- Camera tracking + cloud scrolling

local C = require("core.const")

local M = {}

function M.init(world)
    local max_cx = world.ground.width - C.GAME_W
    world.camera_x = math.max(0, math.min(max_cx, world.player.x - C.GAME_W / 2 + 8))
    world.camera_y = 0
end

function M.update(dt, world)
    local max_cx = world.ground.width - C.GAME_W
    world.camera_x = math.max(0, math.min(max_cx, world.player.x - C.GAME_W / 2 + 8))
    world.camera_y = 0
end

function M.update_clouds(dt, world)
    for _, layer in ipairs(world.cloud_layers) do
        layer.offset = layer.offset + layer.speed * dt * 8
    end
end

return M
