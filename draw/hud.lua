-- draw/hud.lua
-- HUD overlay rendering (floating text, wood counter, UI hints)

local palette = require("core.palette")
local C = require("core.const")

local PAL = palette.PAL
local PIXEL = C.PIXEL
local GAME_W = C.GAME_W
local GAME_H = C.GAME_H

local M = {}

-- Draw a small wood log icon (8x6 pixels at given scale)
local function draw_wood_icon(x, y, s, alpha)
    -- Bark outline
    local bark = PAL[15]
    love.graphics.setColor(bark[1], bark[2], bark[3], alpha)
    love.graphics.rectangle("fill", x, y + 1*s, 8*s, 4*s)
    -- Wood face
    local wood = PAL[16]
    love.graphics.setColor(wood[1], wood[2], wood[3], alpha)
    love.graphics.rectangle("fill", x + 1*s, y + 2*s, 6*s, 2*s)
    -- Highlight
    local hi = PAL[18]
    love.graphics.setColor(hi[1], hi[2], hi[3], alpha)
    love.graphics.rectangle("fill", x + 2*s, y + 2*s, 3*s, 1*s)
    -- End grain circle
    love.graphics.setColor(bark[1], bark[2], bark[3], alpha)
    love.graphics.rectangle("fill", x + 6*s, y, 2*s, 6*s)
    love.graphics.setColor(wood[1], wood[2], wood[3], alpha)
    love.graphics.rectangle("fill", x + 6*s + 1, y + 1*s, 1*s, 4*s)
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
        draw_wood_icon(ex - 10*icon_s, ey + 2, icon_s, alpha)

        -- Text
        love.graphics.setColor(0, 0, 0, alpha * 0.5)
        love.graphics.print(text, ex + 1, ey + 1)
        local c = PAL[13]
        love.graphics.setColor(c[1], c[2], c[3], alpha)
        love.graphics.print(text, ex, ey)
    end

    -- Wood total (top-left, persistent)
    if world.player.wood_count > 0 then
        local alpha = 0.9
        draw_wood_icon(10, 10, icon_s, alpha)
        local c = PAL[13]
        love.graphics.setColor(c[1], c[2], c[3], alpha)
        love.graphics.print(tostring(world.player.wood_count), 10 + 10*icon_s, 6)
    end

    -- UI hint
    local c = PAL[23]
    love.graphics.setColor(c[1], c[2], c[3], 0.6)
    love.graphics.print("WASD + SPACE | LMB = chop | R = randomize | F5 = regenerate", 8, SCREEN_H - 20)
end

return M
