-- gen/cloud.lua
-- Procedural cloud shape + texture generation

local palette = require("core.palette")
local C = require("core.const")

local PAL = palette.PAL
local PIXEL = C.PIXEL

local M = {}

function M.generate_cloud_shape(w, h)
    local grid = {}
    for y = 0, h - 1 do
        grid[y] = {}
        for x = 0, w - 1 do
            grid[y][x] = false
        end
    end

    local function fill_ellipse(cx, cy, rx, ry)
        for y = 0, h - 1 do
            for x = 0, w - 1 do
                local dx = (x - cx) / rx
                local dy = (y - cy) / ry
                if dx * dx + dy * dy <= 1.0 then
                    grid[y][x] = true
                end
            end
        end
    end

    local base_cx = w * (0.42 + math.random() * 0.16)
    local base_cy = h * 0.68
    fill_ellipse(base_cx, base_cy, w * 0.44, h * 0.36)

    local num_bumps = math.random(2, 4)
    local positions = {}
    for i = 1, num_bumps do
        local t = (i - 0.5) / num_bumps
        local jitter = (math.random() - 0.5) * 0.2
        table.insert(positions, math.max(0.1, math.min(0.9, t + jitter)))
    end
    for _, t in ipairs(positions) do
        local bx = w * t
        local by = h * (0.25 + math.random() * 0.2)
        local rx = w * (0.14 + math.random() * 0.12)
        local ry = h * (0.28 + math.random() * 0.16)
        fill_ellipse(bx, by, rx, ry)
    end

    if math.random() > 0.4 then
        local ex = w * (0.15 + math.random() * 0.7)
        local ey = h * (0.35 + math.random() * 0.3)
        fill_ellipse(ex, ey, w * 0.1 + math.random() * 2, h * 0.18 + math.random() * 1)
    end

    local pixels = {}
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            if grid[y][x] then
                local above = (y > 0 and grid[y - 1][x])
                local below = (y < h - 1 and grid[y + 1][x])
                local shade
                if not above then
                    shade = 0
                elseif not below then
                    shade = 2
                else
                    shade = 1
                end
                table.insert(pixels, {x, y, shade})
            end
        end
    end
    return pixels
end

function M.generate_cloud_textures(world)
    local TILE_W = 200
    local TILE_H = 60

    local configs = {
        {num = 8, speed = 0.04, parallax = 0.04, colors = {4, 3, 2}, y_min = 4, y_max = 26, alpha = 0.35},
        {num = 6, speed = 0.07, parallax = 0.06, colors = {6, 5, 3}, y_min = 4, y_max = 33, alpha = 0.45},
    }

    for i, cfg in ipairs(configs) do
        local cw = TILE_W * PIXEL
        local ch = TILE_H * PIXEL
        local tex = love.graphics.newCanvas(cw, ch)
        tex:setFilter("linear", "linear")
        tex:setWrap("repeat", "clampzero")

        love.graphics.setCanvas(tex)
        love.graphics.clear(0, 0, 0, 0)

        local pal_h = PAL[cfg.colors[1]]
        local pal_b = PAL[cfg.colors[2]]
        local pal_s = PAL[cfg.colors[3]]

        local spacing = TILE_W / cfg.num
        for n = 1, cfg.num do
            local w = math.random(12, 22)
            local h = math.random(7, 11)
            local pixels = M.generate_cloud_shape(w, h)
            local cx = math.floor((n - 1) * spacing + math.random(0, math.floor(spacing * 0.6)))
            local cy = math.random(cfg.y_min, cfg.y_max)

            for _, p in ipairs(pixels) do
                local shade = p[3]
                if shade == 0 then
                    love.graphics.setColor(pal_h[1], pal_h[2], pal_h[3])
                elseif shade == 2 then
                    love.graphics.setColor(pal_s[1], pal_s[2], pal_s[3])
                else
                    love.graphics.setColor(pal_b[1], pal_b[2], pal_b[3])
                end
                local px = ((cx + p[1]) % TILE_W) * PIXEL
                local py = (cy + p[2]) * PIXEL
                if py >= 0 and py < ch then
                    love.graphics.rectangle("fill", px, py, PIXEL, PIXEL)
                end
            end
        end

        love.graphics.setCanvas()

        world.cloud_layers[i] = {
            texture = tex,
            tile_w = cw,
            tile_h = ch,
            speed = cfg.speed,
            parallax = cfg.parallax,
            alpha = cfg.alpha,
            offset = 0,
        }
    end
end

return M
