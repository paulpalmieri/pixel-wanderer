-- draw/trees.lua
-- Tree rendering with bend animation

local palette = require("core.palette")
local C = require("core.const")

local set_color = palette.set_color
local PIXEL = C.PIXEL

local M = {}

-- Cache falling tree images (weak keys: auto-cleaned when tree is removed)
local fall_images = setmetatable({}, {__mode = "k"})

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
            local pivot_x = tree.w / 2  -- center of trunk (grid-local)
            local cut_row = tree.h - tree.stump_h  -- row where cut happens

            -- Build cached image for the falling part on first encounter
            if not fall_images[tree] then
                local imgdata = love.image.newImageData(tree.w, cut_row)
                for ty = 1, cut_row do
                    for tx = 1, tree.w do
                        local c = tree.grid[ty][tx]
                        if c ~= 0 then
                            local color = PAL[c]
                            imgdata:setPixel(tx - 1, ty - 1, color[1], color[2], color[3], 1)
                        end
                    end
                end
                local img = love.graphics.newImage(imgdata)
                img:setFilter("nearest", "nearest")
                fall_images[tree] = img
            end

            local angle = tree.fall_angle * tree.fall_dir

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

            -- Draw falling part using LÖVE's native rotation (no pixel gaps)
            love.graphics.setColor(1, 1, 1, fade_alpha)
            love.graphics.draw(fall_images[tree],
                (tree.x + pivot_x - cam_ix) * PIXEL,
                (tree.y + cut_row - cam_iy) * PIXEL,
                angle,
                PIXEL, PIXEL,
                pivot_x, cut_row
            )
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
