-- draw/sky.lua
-- Sky gradient + cloud layer rendering

local palette = require("core.palette")
local C = require("core.const")

local PAL = palette.PAL
local PIXEL = C.PIXEL
local GAME_W = C.GAME_W
local GAME_H = C.GAME_H

local M = {}

function M.draw_sky(world)
    local SCREEN_W = GAME_W * PIXEL
    local SCREEN_H = GAME_H * PIXEL

    -- Single solid deep blue color
    local c = PAL[11]
    love.graphics.setColor(c[1], c[2], c[3], 1.0)
    love.graphics.rectangle("fill", 0, 0, SCREEN_W, SCREEN_H)
end

function M.draw_clouds(world)
    local SCREEN_W = GAME_W * PIXEL

    for _, layer in ipairs(world.cloud_layers) do
        local scroll_px = layer.offset * PIXEL - world.camera_x * layer.parallax * PIXEL
        local vx = (-scroll_px) % layer.tile_w
        local quad = love.graphics.newQuad(vx, 0, SCREEN_W, layer.tile_h,
                                           layer.tile_w, layer.tile_h)
        -- Pure white tint so baked palette colors come through clean
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(layer.texture, quad, 0, 0)
    end
end

return M
