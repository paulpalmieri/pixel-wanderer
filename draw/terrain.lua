-- draw/terrain.lua
-- Ground surface + earth + wall rendering

local palette = require("core.palette")
local C = require("core.const")

local set_color = palette.set_color
local draw_pixel = palette.draw_pixel
local GAME_W = C.GAME_W
local GAME_H = C.GAME_H
local WALL_WIDTH = C.WALL_WIDTH
local WALL_HEIGHT = C.WALL_HEIGHT

local M = {}

function M.draw_ground(cam_ix, cam_iy, world)
    local wx_start = cam_ix
    local wx_end = cam_ix + GAME_W - 1
    for wx = wx_start, wx_end do
        if wx >= 0 and wx < world.ground.width then
            if (wx * 7) % 5 == 0 then
                set_color(33)
            elseif (wx * 3) % 4 == 0 then
                set_color(32)
            else
                set_color(31)
            end
            draw_pixel(wx, world.ground.base_y)

            for wy = world.ground.base_y + 1, cam_iy + GAME_H - 1 do
                local dy = wy - world.ground.base_y
                if (wx + dy) % 5 == 0 or (wx * 3 + dy * 2) % 9 == 0 then
                    set_color(35)
                elseif (wx + dy * 3) % 7 == 0 then
                    set_color(33)
                else
                    set_color(34)
                end
                draw_pixel(wx, wy)
            end
        end
    end
end

function M.draw_walls(cam_ix, cam_iy, world)
    local function draw_wall(world_x_start, world_x_end)
        for wx = world_x_start, world_x_end do
            local gx_ref = math.max(0, math.min(world.ground.width - 1, wx))
            local gy = world.ground.heightmap[gx_ref] or world.ground.base_y
            local wall_top = gy - WALL_HEIGHT
            for wy = wall_top, gy + 5 do
                local brick_row = (wy - wall_top) % 4
                local brick_col = wx % 4
                if brick_row >= 2 then
                    brick_col = (wx + 2) % 4
                end
                if brick_row == 0 or brick_col == 0 then
                    set_color(35)
                else
                    if (wy + wx) % 7 < 3 then
                        set_color(33)
                    else
                        set_color(34)
                    end
                end
                draw_pixel(wx, wy)
            end
            if (wx % 3 ~= 0) then
                set_color(35)
            else
                set_color(8)
            end
            draw_pixel(wx, wall_top - 1)
        end
    end

    draw_wall(0, WALL_WIDTH - 1)
    draw_wall(world.ground.width - WALL_WIDTH, world.ground.width - 1)
end

return M
