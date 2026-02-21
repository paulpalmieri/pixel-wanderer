-- draw/hud.lua
-- HUD overlay rendering (floating text, wood counter, UI hints)

local palette = require("core.palette")
local C = require("core.const")

local PAL = palette.PAL
local PIXEL = C.PIXEL
local GAME_W = C.GAME_W
local GAME_H = C.GAME_H

local M = {}

-- Same 4x4 chunk pixel map used in draw/entities.lua
local chunk_map = {
    {  0, 16, 16,  0 },
    { 16, 18, 18, 16 },
    { 15, 18, 18, 15 },
    {  0, 15, 15,  0 },
}

-- Draw a wood chunk at screen position (x, y) with pixel size s and alpha
local function draw_chunk(x, y, s, alpha)
    for dy = 1, 4 do
        for dx = 1, 4 do
            local col = chunk_map[dy][dx]
            if col ~= 0 then
                local c = PAL[col]
                love.graphics.setColor(c[1], c[2], c[3], alpha)
                love.graphics.rectangle("fill", x + (dx-1)*s, y + (dy-1)*s, s, s)
            end
        end
    end
end

-- Ease-out cubic
local function ease_out(t)
    local t1 = 1 - t
    return 1 - t1 * t1 * t1
end

function M.draw_hud(world)
    local SCREEN_W = GAME_W * PIXEL
    local SCREEN_H = GAME_H * PIXEL

    -- Floating damage numbers
    for _, ft in ipairs(world.floating_texts) do
        if ft.is_crit ~= nil then
            local t = ft.life / ft.max_life
            local alpha = t
            local scale = ft.scale or 1.0
            local age = ft.max_life - ft.life
            if age < 0.1 then
                scale = scale * (1.0 + (1.0 - age / 0.1) * 0.5)
            end

            local sx = math.floor((ft.x - world.camera_x) * PIXEL)
            local sy = math.floor((ft.y - world.camera_y) * PIXEL)

            if ft.is_crit then
                love.graphics.setColor(0, 0, 0, alpha * 0.6)
                for ox = -1, 1 do
                    for oy = -1, 1 do
                        if ox ~= 0 or oy ~= 0 then
                            love.graphics.print(ft.text, sx + ox, sy + oy, 0, scale, scale)
                        end
                    end
                end
                love.graphics.setColor(1.0, 0.85, 0.15, alpha)
            else
                love.graphics.setColor(0, 0, 0, alpha * 0.5)
                love.graphics.print(ft.text, sx + 1, sy + 1, 0, scale, scale)
                love.graphics.setColor(1.0, 1.0, 1.0, alpha)
            end
            love.graphics.print(ft.text, sx, sy, 0, scale, scale)
        end
    end

    -- Resource log (top-right, slides in and fades)
    local log_x = SCREEN_W - 10
    local log_y = 10
    local icon_s = 3
    local line_h = 28
    for i, entry in ipairs(world.resource_log) do
        local t = entry.life / entry.max_life
        -- Fade in first 0.3s, fade out last 1s
        local alpha
        local age = entry.max_life - entry.life
        if age < 0.3 then
            alpha = age / 0.3
        elseif t < 0.25 then
            alpha = t / 0.25
        else
            alpha = 1.0
        end
        -- Slide in from right
        local slide = 0
        if age < 0.2 then
            slide = (1.0 - age / 0.2) * 60
        end

        local text = "x" .. entry.amount
        local tw = world.font:getWidth(text)
        local ex = log_x + slide - tw
        local ey = log_y + (i - 1) * line_h

        -- Icon
        draw_chunk(ex - 5*icon_s, ey + 2, icon_s, alpha)

        -- Text
        love.graphics.setColor(0, 0, 0, alpha * 0.5)
        love.graphics.print(text, ex + 1, ey + 1)
        local c = PAL[13]
        love.graphics.setColor(c[1], c[2], c[3], alpha)
        love.graphics.print(text, ex, ey)
    end

    -- Flying wood chunks (animate from pickup to HUD counter)
    for _, fc in ipairs(world.flying_chunks) do
        local t = ease_out(fc.t)
        -- Curved path: add an arc offset that peaks at t=0.5
        local arc = -60 * math.sin(t * math.pi)
        local cx = fc.x + (fc.tx - fc.x) * t
        local cy = fc.y + (fc.ty - fc.y) * t + arc
        -- Slight fade at the very end
        local alpha = t > 0.85 and (1 - t) / 0.15 or 1.0
        draw_chunk(cx - 2*PIXEL, cy - 2*PIXEL, PIXEL, alpha)
    end

    -- Wood total (top-left, persistent)
    if world.player.wood_count > 0 then
        local alpha = 0.9
        draw_chunk(10, 10, icon_s, alpha)
        local c = PAL[13]
        love.graphics.setColor(c[1], c[2], c[3], alpha)
        love.graphics.print(tostring(world.player.wood_count), 10 + 5*icon_s, 6)
    end

    -- UI hint
    local c = PAL[23]
    love.graphics.setColor(c[1], c[2], c[3], 0.6)
    love.graphics.print("WASD + SPACE | LMB = chop | R = randomize | F5 = regenerate", 8, SCREEN_H - 20)
end

return M
