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
        local sx = math.floor(c.x)
        local sy = math.floor(c.y)
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
        draw_pixel(math.floor(p.x), math.floor(p.y))
    end
end

return M
