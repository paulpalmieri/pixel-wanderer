-- draw/entities.lua
-- Wood chunk + particle rendering

local palette = require("core.palette")

local set_color = palette.set_color
local draw_pixel = palette.draw_pixel

local M = {}

-- Wood chunk pixel map: 0=skip, 15=dark bark, 16=mid brown, 18=light wood
local chunk_map = {
    {  0, 16, 16,  0 },
    { 16, 18, 18, 16 },
    { 15, 18, 18, 15 },
    {  0, 15, 15,  0 },
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
        local alpha = 1.0
        if p.max_life and p.max_life > 0 then
            alpha = math.min(1.0, p.life / (p.max_life * 0.4))
        end
        set_color(p.color, alpha)
        draw_pixel(math.floor(p.x), math.floor(p.y))
    end
end

return M
