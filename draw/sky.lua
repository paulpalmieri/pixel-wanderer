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
    local SKY_BANDS = GAME_H
    local band_h = math.ceil(SCREEN_H / SKY_BANDS)

    for band = 0, SKY_BANDS - 1 do
        local t = band / (SKY_BANDS - 1)
        local c1, c2, lt
        if t < 0.5 then
            c1 = PAL[1]; c2 = PAL[2]; lt = t / 0.5
        else
            c1 = PAL[2]; c2 = PAL[3]; lt = (t - 0.5) / 0.5
        end
        love.graphics.setColor(
            c1[1] + (c2[1] - c1[1]) * lt,
            c1[2] + (c2[2] - c1[2]) * lt,
            c1[3] + (c2[3] - c1[3]) * lt
        )
        love.graphics.rectangle("fill", 0, band * band_h, SCREEN_W, band_h)
    end
end

function M.draw_clouds(world)
    local SCREEN_W = GAME_W * PIXEL

    for _, layer in ipairs(world.cloud_layers) do
        local scroll_px = layer.offset * PIXEL - world.camera_x * layer.parallax * PIXEL
        local vx = (-scroll_px) % layer.tile_w
        local quad = love.graphics.newQuad(vx, 0, SCREEN_W, layer.tile_h,
                                           layer.tile_w, layer.tile_h)
        love.graphics.setColor(1, 1, 1, layer.alpha)
        love.graphics.draw(layer.texture, quad, 0, 0)
    end
end

return M
