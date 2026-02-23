-- draw/entities.lua
-- Wood chunk + particle rendering

local palette = require("core.palette")

local set_color = palette.set_color
local draw_pixel = palette.draw_pixel

local M = {}

-- Wood chunk pixel map: 0=skip, 2=dark bark, 5=mid brown, 6=light wood
local chunk_map = {
    {  0,  5,  5,  0 },
    {  5,  6,  6,  5 },
    {  2,  6,  6,  2 },
    {  0,  2,  2,  0 },
}

function M.draw_wood_chunks(world)
    for _, c in ipairs(world.wood_chunks) do
        local cam_ix = math.floor(world.camera_x + 0.5)
        local cam_iy = math.floor(world.camera_y + 0.5)
        local sx = math.floor(c.x - world.camera_x + 0.5) + cam_ix
        local sy = math.floor(c.y - world.camera_y + 0.5) + cam_iy
        for dy = 1, 4 do
            for dx = 1, 4 do
                local col = chunk_map[dy][dx]
                if col ~= 0 then
                    set_color(col)
                    draw_pixel(sx + dx - 1, sy + dy - 1)
                end
            end
        end
    end
end

function M.draw_particles(world)
    for _, p in ipairs(world.particles) do
        set_color(p.color, 1.0)
        local cam_ix = math.floor(world.camera_x + 0.5)
        local cam_iy = math.floor(world.camera_y + 0.5)
        local px = math.floor(p.x - world.camera_x + 0.5) + cam_ix
        local py = math.floor(p.y - world.camera_y + 0.5) + cam_iy
        draw_pixel(px, py)
    end
end

return M
