-- draw/trees.lua
-- Tree rendering with bend animation

local palette = require("core.palette")
local C = require("core.const")

local set_color = palette.set_color
local PIXEL = C.PIXEL

local M = {}

function M.draw_trees(cam_ix, cam_iy, world)
    local PAL = palette.PAL

    local cos = math.cos
    local sin = math.sin
    local floor = math.floor

    local function draw_tree(tree)
        -- Skip dead trees that aren't falling
        if tree.hp <= 0 and not tree.falling then return end

        -- Falling tree rendering
        if tree.falling then
            local angle = tree.fall_angle * tree.fall_dir
            local cos_a = cos(angle)
            local sin_a = sin(angle)
            local pivot_x = tree.w / 2  -- center of trunk (grid-local)
            local cut_row = tree.h - tree.stump_h  -- row where cut happens

            -- Fade alpha after impact
            local fade_alpha = 1
            if tree.fell then
                fade_alpha = math.max(0, tree.fall_timer / 0.8)
            end

            -- Draw stump (bottom stump_h rows, no rotation)
            for ty = cut_row + 1, tree.h do
                for tx = 1, tree.w do
                    local c = tree.grid[ty][tx]
                    if c ~= 0 then
                        set_color(c, fade_alpha)
                        local sx = (tree.x + tx - 1 - cam_ix) * PIXEL
                        local sy = (tree.y + ty - 1 - cam_iy) * PIXEL
                        love.graphics.rectangle("fill", sx, sy, PIXEL, PIXEL)
                    end
                end
            end

            -- Draw falling part (rows above cut, rotated around base-center pivot)
            for ty = 1, cut_row do
                for tx = 1, tree.w do
                    local c = tree.grid[ty][tx]
                    if c ~= 0 then
                        local dx = (tx - 1) - pivot_x
                        local dy = (ty - 1) - cut_row  -- negative (above pivot)
                        local rx = dx * cos_a - dy * sin_a
                        local ry = dx * sin_a + dy * cos_a

                        set_color(c, fade_alpha)
                        local sx = (tree.x + pivot_x + rx - cam_ix) * PIXEL
                        local sy = (tree.y + cut_row + ry - cam_iy) * PIXEL
                        love.graphics.rectangle("fill", sx, sy, PIXEL, PIXEL)
                    end
                end
            end
            return
        end

        -- Bend animation — amplitude scales with bend_dir magnitude
        local bend = 0
        local bend_duration = 0.6 + math.abs(tree.bend_dir) * 0.4
        if tree.bend_timer > 0 then
            local elapsed = bend_duration - tree.bend_timer
            local amp = (8.0 + math.abs(tree.bend_dir) * 6.0) / (1 + tree.h * 0.02)
            bend = tree.bend_dir * amp * math.exp(-elapsed * 4.5) * math.cos(elapsed * 5)
        end

        -- Flash: bright white overlay that fades quickly
        local flash_alpha = 0
        if tree.flash_timer > 0 then
            flash_alpha = tree.flash_timer / 0.12
            flash_alpha = flash_alpha * flash_alpha  -- ease out
        end

        for ty = 1, tree.h do
            local height_frac = (tree.h - ty) / tree.h
            local x_off = bend * height_frac ^ 1.5
            for tx = 1, tree.w do
                local c = tree.grid[ty][tx]
                if c ~= 0 then
                    if flash_alpha > 0 then
                        -- Lerp palette color toward white
                        local base = PAL[c]
                        local fa = flash_alpha * 0.7
                        love.graphics.setColor(
                            base[1] + (1 - base[1]) * fa,
                            base[2] + (1 - base[2]) * fa,
                            base[3] + (1 - base[3]) * fa,
                            1
                        )
                    else
                        set_color(c)
                    end
                    local sx = (tree.x + tx - 1 + x_off - cam_ix) * PIXEL
                    local sy = (tree.y + ty - 1 - cam_iy) * PIXEL
                    love.graphics.rectangle("fill", sx, sy, PIXEL, PIXEL)
                end
            end
        end
    end

    for _, tree in ipairs(world.trees) do
        draw_tree(tree)
    end
end

return M
