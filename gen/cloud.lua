-- gen/cloud.lua
-- Procedural cloud shape + texture generation

local palette = require("core.palette")
local C = require("core.const")

local PAL = palette.PAL
local PIXEL = C.PIXEL

local M = {}

function M.generate_cloud_shape(w, h)
    local puffs = {}
    
    local base_y = math.floor(h * 0.75)
    local left_x = math.floor(w * 0.25)
    local right_x = math.floor(w * 0.75)
    
    table.insert(puffs, {w * 0.5, base_y - h * 0.35, h * 0.45})
    table.insert(puffs, {left_x, base_y - h * 0.1, h * 0.3})
    table.insert(puffs, {right_x, base_y - h * 0.1, h * 0.3})
    
    local num_extra = math.random(1, 3)
    for i = 1, num_extra do
        local px = left_x + math.random() * (right_x - left_x)
        local py = base_y - math.random() * h * 0.4
        local pr = h * 0.2 + math.random() * h * 0.2
        table.insert(puffs, {px, py, pr})
    end

    local pixels = {}
    for y = -2, h + 2 do
        for x = -2, w + 2 do
            local min_edge = 999
            local best_ndx, best_ndy = 0, 0
            
            for _, puff in ipairs(puffs) do
                local cx, cy, r = puff[1], puff[2], puff[3]
                local ndx = (x - cx) / r
                local ndy = (y - cy) / r
                local d2 = ndx * ndx + ndy * ndy
                
                -- clumpiness to edge similar to trees
                local clump = math.sin(x * 0.5) * math.cos(y * 0.5) * 0.2 + math.sin(x * 0.15 + y * 0.2) * 0.15
                local edge = d2 + clump
                
                -- Bottom flattening
                if y > base_y then
                    local flatten_factor = (y - base_y) / 2.0
                    edge = edge + flatten_factor * flatten_factor * 2
                end
                
                if edge < min_edge then
                    min_edge = edge
                    best_ndx = ndx
                    best_ndy = ndy
                end
            end
            
            if min_edge <= 1.05 then
                -- Clustered specular / shadows based on direction (light from top-left) and depth
                local shade_val = best_ndx * 0.4 + best_ndy * 0.6 + min_edge * 0.4
                -- Add cluster noise
                local leaf_noise = (math.sin(x * 1.5 + y * 0.5) + math.cos(x * 0.5 + y * 1.5)) * 0.15
                -- Pixel art dithering
                local dither = ((x + y) % 2 == 0) and 0.08 or -0.08
                shade_val = shade_val + leaf_noise + dither
                
                local shade_idx = 1
                if shade_val <= -0.15 then
                    shade_idx = 0 -- highlight
                elseif shade_val <= 0.45 then
                    shade_idx = 1 -- midtone
                else
                    shade_idx = 2 -- shadow
                end
                
                table.insert(pixels, {x, y, shade_idx})
            end
        end
    end
    return pixels
end

function M.generate_cloud_textures(world)
    local TILE_W = 200
    local TILE_H = 60

    local configs = {
        -- The single cloud layer: white, slow. Made larger and placed lower.
        {num = 6, speed = 0.02, parallax = 0.02, colors = {20, 19, 18},
         y_min = 10, y_max = 38, alpha = 0.8, cloud_w = {18, 28}, cloud_h = {10, 16}},
    }

    for i, cfg in ipairs(configs) do
        local cw = TILE_W * PIXEL
        local ch = TILE_H * PIXEL
        local tex = love.graphics.newCanvas(cw, ch)
        tex:setFilter("nearest", "nearest")
        tex:setWrap("repeat", "clampzero")

        love.graphics.setCanvas(tex)
        love.graphics.clear(0, 0, 0, 0)

        local pal_h = PAL[cfg.colors[1]]
        local pal_b = PAL[cfg.colors[2]]
        local pal_s = PAL[cfg.colors[3]]

        local spacing = TILE_W / cfg.num
        for n = 1, cfg.num do
            local w = math.random(cfg.cloud_w[1], cfg.cloud_w[2])
            local h = math.random(cfg.cloud_h[1], cfg.cloud_h[2])
            local pixels = M.generate_cloud_shape(w, h)
            local cx = math.floor((n - 1) * spacing + math.random(0, math.floor(spacing * 0.6)))
            local cy = math.random(cfg.y_min, cfg.y_max)

            for _, p in ipairs(pixels) do
                local shade = p[3]
                if shade == 0 then
                    love.graphics.setColor(pal_h[1], pal_h[2], pal_h[3], 1.0)
                elseif shade == 2 then
                    love.graphics.setColor(pal_s[1], pal_s[2], pal_s[3], 1.0)
                else
                    love.graphics.setColor(pal_b[1], pal_b[2], pal_b[3], 1.0)
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
