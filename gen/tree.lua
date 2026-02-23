-- gen/tree.lua
-- Procedural tree generator: trunk segments + distinct foliage blobs
-- Each foliage blob gets per-blob spherical shading (light from upper-left)

local C = require("core.const")

local M = {}

----------------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------------

-- Rasterize a trunk/branch line with 3-tone bark shading
local function raster_trunk(grid, x1, y1, x2, y2, w1, w2, gw, gh)
    local dx, dy = x2 - x1, y2 - y1
    local steps = math.max(math.abs(dy), math.abs(dx), 1)
    for i = 0, steps do
        local t = i / steps
        local px = x1 + dx * t
        local py = y1 + dy * t
        local tw = w1 + (w2 - w1) * t
        local gy = math.floor(py + 0.5)
        if gy >= 1 and gy <= gh then
            local half = tw / 2
            local left  = math.max(1,  math.floor(px - half + 0.5))
            local right = math.min(gw, math.floor(px + half - 0.5))
            for gx = left, right do
                local frac = (gx - (px - half)) / math.max(0.01, tw)
                -- Add some bark texture: vertical stripes with some wobble
                local noise = math.sin(gx * 2.5 + gy * 0.3) * 0.15 + math.cos(gx * 0.8) * 0.12
                -- Pixel art dithering based on position
                local dither = ((gx + gy) % 2 == 0) and 0.05 or -0.05
                local bark = frac + noise + dither
                if bark < 0.25 then
                    grid[gy][gx] = 6 -- light wood
                elseif bark > 0.75 then
                    grid[gy][gx] = 3  -- Deep Red Brown for dark bark shading
                else
                    grid[gy][gx] = 5 -- mid brown
                end
            end
        end
    end
end

-- Rasterize a foliage blob (ellipse) with directional shading
local function raster_foliage(grid, bcx, bcy, rx, ry, gw, gh)
    rx = math.max(2, rx)
    ry = math.max(2, ry)
    local y0 = math.max(1,  math.floor(bcy - ry))
    local y1 = math.min(gh, math.ceil(bcy + ry))
    local x0 = math.max(1,  math.floor(bcx - rx))
    local x1 = math.min(gw, math.ceil(bcx + rx))
    for y = y0, y1 do
        for x = x0, x1 do
            local ndx = (x - bcx) / rx
            local ndy = (y - bcy) / ry
            local d2 = ndx * ndx + ndy * ndy
            
            -- Add clumpiness to the edge and the shading
            local clump = math.sin(x * 0.6) * math.cos(y * 0.6) * 0.2 + math.sin(x * 0.2 + y * 0.3) * 0.15
            local edge = d2 + clump
            
            if edge <= 1.05 then
                -- Clustered specular / shadows based on direction (light from top-left) and depth
                local shade = ndx * 0.4 + ndy * 0.6 + edge * 0.4
                -- Add cluster noise to make leaves look bunchy
                local leaf_noise = (math.sin(x * 1.5 + y * 0.5) + math.cos(x * 0.5 + y * 1.5)) * 0.15
                -- Pixel art dithering
                local dither = ((x + y) % 2 == 0) and 0.08 or -0.08
                shade = shade + leaf_noise + dither
                
                if shade <= -0.15 then
                    grid[y][x] = 7  -- Highlight (Olive Green)
                elseif shade <= 0.35 then
                    grid[y][x] = 8  -- Mid-light (Forest Green)
                elseif shade <= 0.85 then
                    grid[y][x] = 10 -- Core shadow (Dark Teal Blue)
                else
                    grid[y][x] = 9  -- Deep contour/shadow (Dark Olive)
                end
            end
        end
    end
end

----------------------------------------------------------------------------
-- Main generator
----------------------------------------------------------------------------

function M.generate_tree(size_hint)
    size_hint = size_hint or "medium"

    local r = math.random()
    local tree_type
    if r < 0.35 then tree_type = 1        -- round/oak
    elseif r < 0.70 then tree_type = 2    -- conifer/pine (mapped to 2, wait previously it was 3)
    else tree_type = 3 end                -- wide spreading/willow-ish (mapped to 3, previously 5)

    local sizes = {
        [1] = { small={w={16,22},h={38,48}}, medium={w={22,28},h={48,64}}, large={w={28,36},h={64,80}} },
        [2] = { small={w={12,16},h={36,50}}, medium={w={16,22},h={50,68}}, large={w={20,26},h={68,88}} },
        [3] = { small={w={24,30},h={40,50}}, medium={w={30,40},h={50,64}}, large={w={38,48},h={64,78}} },
    }
    local sz = sizes[tree_type][size_hint]
    local w = math.random(sz.w[1], sz.w[2])
    local h = math.random(sz.h[1], sz.h[2])
    local cx = math.floor(w / 2) + 1

    local trunks = {}
    local fol = {}

    if tree_type == 1 then
        ----------------------------------------------------------------
        -- OAK TREE: thick trunk + cluster of over-lapping round blobs
        ----------------------------------------------------------------
        local cr = math.floor(w * 0.38)
        local crown_cy = cr + 6
        local tw = math.max(3, math.floor(w * 0.16))
        trunks[1] = {cx, h, cx, crown_cy + math.floor(cr * 0.2), tw, math.max(2, tw - 1)}
        -- main central blob
        fol[1] = {cx, crown_cy + 2, cr, math.floor(cr * 0.9)}
        -- left/right smaller clusters
        fol[2] = {cx - math.floor(cr * 0.6), crown_cy + 4, math.floor(cr * 0.7), math.floor(cr * 0.65)}
        fol[3] = {cx + math.floor(cr * 0.6), crown_cy + 4, math.floor(cr * 0.7), math.floor(cr * 0.65)}
        -- top cluster
        fol[4] = {cx + math.random(-1, 1), crown_cy - math.floor(cr * 0.5), math.floor(cr * 0.75), math.floor(cr * 0.6)}

    elseif tree_type == 2 then
        ----------------------------------------------------------------
        -- PINE/CONIFER: trunk + 4 stacked overlapping cone-like layers
        ----------------------------------------------------------------
        local n = (h > 55) and 4 or 3
        local base_rx = math.max(4, math.floor(w * 0.42))
        local top_y = 6
        local bot_y = math.floor(h * 0.75)
        local tw = math.max(2, math.floor(w * 0.14))
        trunks[1] = {cx, h, cx, top_y + 4, tw, math.max(1, tw - 1)}
        for i = 1, n do
            local t = (i - 1) / math.max(1, n - 1)  -- 0=top, 1=bottom
            local rx = math.max(3, math.floor(base_rx * (0.30 + t * 0.70)))
            local ry = math.max(3, math.floor((bot_y - top_y) / n * 0.85))
            local by = top_y + t * (bot_y - top_y)
            -- make the top layer a bit narrower
            if i == 1 then rx = rx * 0.8 end
            fol[#fol+1] = {cx, by, rx, ry}
            -- add secondary overlapping sub-blobs to jagged the edges
            if i > 1 then
                fol[#fol+1] = {cx - math.floor(rx*0.4), by + 1, math.floor(rx*0.6), math.floor(ry*0.9)}
                fol[#fol+1] = {cx + math.floor(rx*0.4), by + 1, math.floor(rx*0.6), math.floor(ry*0.9)}
            end
        end

    else
        ----------------------------------------------------------------
        -- WILLOW / BRANCHING: Split trunk with extended sweeping foliage
        ----------------------------------------------------------------
        local br = math.max(4, math.floor(math.min(w, h) * 0.20))
        local split_y = math.floor(h * 0.50)
        local spread = math.floor(w * 0.28)
        local tw = math.max(3, math.floor(w * 0.14))
        
        -- main trunk
        trunks[1] = {cx, h, cx, split_y, tw, math.max(2, tw - 1)}
        
        local ly = br + 6
        local ry_pos = br + 4
        -- left branch
        trunks[2] = {cx, split_y, cx - spread + 2, ly, math.max(2, tw - 1), 1}
        -- right branch
        trunks[3] = {cx, split_y, cx + spread - 2, ry_pos, math.max(2, tw - 1), 1}
        
        -- center cluster
        fol[1] = {cx, split_y - math.floor(br * 0.5), br, math.floor(br * 0.9)}
        
        -- left and right sweeping foliage
        fol[2] = {cx - spread, ly, math.floor(br * 1.1), math.floor(br * 1.3)}
        fol[3] = {cx + spread, ry_pos, math.floor(br * 1.1), math.floor(br * 1.2)}
        
        -- additional filler
        fol[4] = {cx - math.floor(spread*0.5), ly - 4, math.floor(br * 0.8), math.floor(br * 0.8)}
        fol[5] = {cx + math.floor(spread*0.5), ry_pos - 4, math.floor(br * 0.8), math.floor(br * 0.8)}
    end

    ----------------------------------------------------------------
    -- Rasterize
    ----------------------------------------------------------------
    local grid = {}
    for y = 1, h do
        grid[y] = {}
        for x = 1, w do grid[y][x] = 0 end
    end

    -- Trunk first (foliage draws on top)
    for _, seg in ipairs(trunks) do
        raster_trunk(grid, seg[1], seg[2], seg[3], seg[4], seg[5], seg[6], w, h)
    end

    -- Foliage: lower blobs first, upper blobs on top
    table.sort(fol, function(a, b) return a[2] > b[2] end)
    for _, blob in ipairs(fol) do
        raster_foliage(grid, blob[1], blob[2], blob[3], blob[4], w, h)
    end

    return {grid = grid, w = w, h = h, tree_type = tree_type}
end

----------------------------------------------------------------------------
-- World tree placement
----------------------------------------------------------------------------

function M.generate_trees(world)
    world.trees = {}
    local gy = world.ground and world.ground.base_y or (C.GAME_H - 16)
    local world_w = 512

    local function place_tree(tx, size_hint)
        tx = math.max(C.WALL_WIDTH + 8, math.min(world_w - C.WALL_WIDTH - 8, tx))
        local tree_data = M.generate_tree(size_hint)
        local depth = math.random(0, 2)
        table.insert(world.trees, {
            x = tx,
            y = gy - tree_data.h,
            grid = tree_data.grid,
            w = tree_data.w,
            h = tree_data.h,
            hp = 5 + (world.upgrades and world.upgrades.tree_health_bonus and (world.upgrades.tree_health_bonus * 5) or 0),
            max_hp = 5 + (world.upgrades and world.upgrades.tree_health_bonus and (world.upgrades.tree_health_bonus * 5) or 0),
            shake_timer = 0,
            flash_timer = 0,
            bend_timer = 0,
            bend_dir = 0,
            depth = depth,
            -- Fall animation state
            falling = false,
            fall_angle = 0,
            fall_vel = 0,
            fall_dir = 0,
            fell = false,
            fall_timer = 0,
            stump_h = 3,
        })
    end

    -- Safe zone: no trees near entrance
    local safe_min_x = C.WALL_WIDTH + C.ENTRANCE_DOOR_W + C.SAFE_ZONE_W

    -- Progressive density: sparse near entrance, dense toward far end
    local placed = {}  -- {x, ...}
    local max_x = world_w - C.WALL_WIDTH - 12
    local range = max_x - safe_min_x

    -- How close together trees can be, based on map progress (0=entrance, 1=far end)
    local function min_gap_at(x)
        local progress = math.max(0, math.min(1, (x - safe_min_x) / range))
        -- 35px gap near entrance, down to 10px at far end
        return 35 - 25 * progress
    end

    local function is_too_close(x)
        local gap = min_gap_at(x)
        for _, px in ipairs(placed) do
            if math.abs(x - px) < gap then return true end
        end
        return false
    end

    local function pick_size(progress)
        -- Bias toward larger trees further into the map
        local rr = math.random()
        local large_chance = 0.15 + 0.35 * progress  -- 15% → 50%
        local small_chance = 0.35 - 0.20 * progress  -- 35% → 15%
        if rr < small_chance then return "small"
        elseif rr < (1 - large_chance) then return "medium"
        else return "large"
        end
    end

    -- Place trees across the map with increasing density
    -- Divide map into zones, place more trees per zone as x increases
    local num_zones = 6
    local zone_w = range / num_zones
    for zone = 0, num_zones - 1 do
        local zone_start = safe_min_x + zone * zone_w
        local zone_end = zone_start + zone_w
        local progress = (zone + 0.5) / num_zones  -- 0..1
        local is_dense = (zone >= num_zones - 2)

        local tree_count, cluster_chance, extras_max, dense_gap
        if is_dense then
            -- Last 2 zones: wall-to-wall forest
            tree_count    = math.random(14, 20)
            cluster_chance = 0.90
            extras_max    = 3
            dense_gap     = 6
        else
            local base_count = math.floor(2 + progress * 5)
            tree_count     = base_count + math.random(0, math.floor(1 + progress * 2))
            cluster_chance = 0.15 + 0.35 * progress
            extras_max     = progress > 0.5 and 2 or 1
            dense_gap      = nil
        end

        local function can_place(x)
            local gap = dense_gap or min_gap_at(x)
            for _, px in ipairs(placed) do
                if math.abs(x - px) < gap then return false end
            end
            return true
        end

        local zone_attempts = 0
        local zone_placed = 0
        while zone_placed < tree_count and zone_attempts < 150 do
            zone_attempts = zone_attempts + 1
            local tx = math.random(math.floor(zone_start), math.floor(zone_end))
            tx = math.max(safe_min_x, math.min(max_x, tx))
            if can_place(tx) then
                place_tree(tx, pick_size(progress))
                table.insert(placed, tx)
                zone_placed = zone_placed + 1

                if math.random() < cluster_chance then
                    local n = math.random(1, extras_max)
                    for _ = 1, n do
                        local spread = is_dense and math.random(6, 12) or math.random(10, 18)
                        local pair_tx = tx + spread * (math.random() < 0.5 and -1 or 1)
                        pair_tx = math.max(safe_min_x, math.min(max_x, pair_tx))
                        if can_place(pair_tx) then
                            place_tree(pair_tx, pick_size(progress))
                            table.insert(placed, pair_tx)
                        end
                    end
                end
            end
        end
    end

    table.sort(world.trees, function(a, b) return a.depth < b.depth end)
end

return M
