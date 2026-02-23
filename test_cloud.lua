local function print_cloud(w, h)
    local grid = {}
    for y = -4, h + 4 do
        grid[y] = {}
        for x = -4, w + 4 do
            grid[y][x] = 0 -- density/distance
        end
    end

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

    for y = -2, h + 2 do
        for x = -2, w + 2 do
            local min_edge = 999
            local best_ndx, best_ndy = 0, 0
            
            for _, puff in ipairs(puffs) do
                local cx, cy, r = puff[1], puff[2], puff[3]
                local ndx = (x - cx) / r
                local ndy = (y - cy) / r
                local d2 = ndx * ndx + ndy * ndy
                
                -- clumpiness like trees
                local clump = math.sin(x * 0.5) * math.cos(y * 0.5) * 0.2 + math.sin(x * 0.15 + y * 0.2) * 0.15
                local edge = d2 + clump
                
                -- bottom flattening
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
            
            if min_edge <= 1.0 then
                -- Clustered specular / shadows based on direction (light from top-left) and depth
                local shade_val = best_ndx * 0.4 + best_ndy * 0.6 + min_edge * 0.4
                -- Add cluster noise
                local leaf_noise = (math.sin(x * 1.5 + y * 0.5) + math.cos(x * 0.5 + y * 1.5)) * 0.15
                -- Pixel art dithering
                local dither = ((x + y) % 2 == 0) and 0.08 or -0.08
                shade_val = shade_val + leaf_noise + dither
                
                local char = "1"
                if shade_val <= -0.1 then
                    char = "0" -- highlight
                elseif shade_val <= 0.45 then
                    char = "1" -- mid
                elseif shade_val <= 0.85 then
                    char = "2" -- shadow
                else
                    char = "2" -- deep shadow
                end
                grid[y][x] = char
            end
        end
    end

    for y = -2, h + 2 do
        local s = ""
        local has_content = false
        for x = -2, w + 2 do
            if grid[y][x] == 0 then
                s = s .. "."
            else
                s = s .. grid[y][x]
            end
        end
        if s:find("[012]") then
            print(s)
        end
    end
    print("")
end

math.randomseed(0)
for i = 1, 5 do
    print_cloud(math.random(18, 28), math.random(10, 16))
end
