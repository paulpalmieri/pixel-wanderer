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
                local frac = (gx - (px - half)) / math.max(0.5, tw)
                if frac < 0.28 then
                    grid[gy][gx] = 18
                elseif frac > 0.72 then
                    grid[gy][gx] = 15
                else
                    grid[gy][gx] = 16
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
    local shift = (math.random() - 0.5) * 0.06
    for y = y0, y1 do
        for x = x0, x1 do
            local ndx = (x - bcx) / rx
            local ndy = (y - bcy) / ry
            local d2 = ndx * ndx + ndy * ndy
            if d2 <= 1.0 then
                local shade = ndx * 0.30 + ndy * 0.65 + d2 * 0.18
                local dither = ((x + y) % 2) * 0.07 - 0.035
                shade = shade + dither + shift
                if shade < -0.10 then
                    grid[y][x] = 36
                elseif shade < 0.28 then
                    grid[y][x] = 17
                elseif shade < 0.58 then
                    grid[y][x] = 7
                else
                    grid[y][x] = 8
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
    if r < 0.25 then tree_type = 1        -- round
    elseif r < 0.48 then tree_type = 2    -- tall multi-blob
    elseif r < 0.64 then tree_type = 3    -- conifer
    elseif r < 0.82 then tree_type = 4    -- branching
    else tree_type = 5 end                -- wide spreading

    if size_hint == "small" and math.random() < 0.25 then
        tree_type = 6
    end

    local sizes = {
        [1] = { small={w={14,20},h={32,44}}, medium={w={18,26},h={44,60}}, large={w={24,34},h={56,72}} },
        [2] = { small={w={12,16},h={36,48}}, medium={w={14,20},h={48,64}}, large={w={16,24},h={60,78}} },
        [3] = { small={w={10,14},h={30,44}}, medium={w={12,18},h={44,62}}, large={w={14,22},h={58,78}} },
        [4] = { small={w={22,28},h={32,42}}, medium={w={28,38},h={42,56}}, large={w={34,44},h={52,68}} },
        [5] = { small={w={18,26},h={32,42}}, medium={w={24,34},h={42,54}}, large={w={30,42},h={50,64}} },
        [6] = { small={w={6,10},h={6,10}},   medium={w={8,14},h={8,14}},   large={w={12,18},h={10,16}} },
    }
    local sz = sizes[tree_type][size_hint]
    local w = math.random(sz.w[1], sz.w[2])
    local h = math.random(sz.h[1], sz.h[2])
    local cx = math.floor(w / 2) + 1

    local trunks = {}
    local fol = {}

    if tree_type == 1 then
        ----------------------------------------------------------------
        -- ROUND TREE: trunk + 1 main round blob + optional small cap
        ----------------------------------------------------------------
        local cr = math.floor(w * 0.42)
        local crown_cy = cr + 2
        local tw = math.max(2, math.floor(w * 0.14))
        trunks[1] = {cx, h, cx, crown_cy + math.floor(cr * 0.15), tw, math.max(2, tw - 1)}
        fol[1] = {cx, crown_cy, cr, math.floor(cr * (0.85 + math.random() * 0.15))}
        if w >= 20 then
            fol[2] = {cx + math.random(-1, 1), crown_cy - cr * 0.40,
                      cr * 0.50, cr * 0.42}
        end

    elseif tree_type == 2 then
        ----------------------------------------------------------------
        -- TALL: trunk + 2-3 stacked ovals
        ----------------------------------------------------------------
        local n = (h > 55) and 3 or 2
        local brx = math.max(3, math.floor(w * 0.40))
        local bry = math.max(3, math.floor(h * 0.13))
        local top_y = bry + 2
        local bot_y = math.floor(h * 0.65)
        local tw = math.max(2, math.floor(w * 0.16))
        trunks[1] = {cx, h, cx, top_y + math.floor(bry * 0.5), tw, math.max(1, tw - 1)}
        for i = 1, n do
            local t = (i - 1) / math.max(1, n - 1)
            local by = top_y + t * (bot_y - top_y)
            fol[#fol+1] = {cx + (math.random() - 0.5) * 2,
                           by, brx, bry}
        end

    elseif tree_type == 3 then
        ----------------------------------------------------------------
        -- CONIFER: trunk + 2-3 stacked layers, wider toward bottom
        ----------------------------------------------------------------
        local n = (h > 50) and math.random(3, 4) or 2
        local base_rx = math.max(3, math.floor(w * 0.44))
        local layer_ry = math.max(3, math.floor(h * 0.11))
        local tw = math.max(2, math.floor(w * 0.18))
        local top_y = layer_ry + 1
        local bot_y = math.floor(h * 0.68)
        trunks[1] = {cx, h, cx, top_y, tw, math.max(1, tw - 1)}
        for i = 1, n do
            local t = (i - 1) / math.max(1, n - 1)  -- 0=top, 1=bottom
            local rx = math.max(2, math.floor(base_rx * (0.35 + t * 0.65)))
            local ry = math.max(2, math.floor(layer_ry * (0.70 + t * 0.40)))
            local by = top_y + t * (bot_y - top_y)
            fol[#fol+1] = {cx, by, rx, ry}
        end

    elseif tree_type == 4 then
        ----------------------------------------------------------------
        -- BRANCHING: Y-trunk with 1 blob per branch tip
        ----------------------------------------------------------------
        local br = math.max(3, math.floor(math.min(w, h) * 0.16))
        local split_y = math.floor(h * (0.52 + math.random() * 0.08))
        local spread = math.floor(w * 0.22)
        local tw = math.max(2, math.floor(w * 0.10))
        local branch_top = math.max(br + 2, math.floor(h * 0.12))
        -- main trunk
        trunks[1] = {cx, h, cx, split_y, tw + 1, tw}
        -- left branch + blob
        local lx = cx - spread
        local ly = branch_top
        trunks[2] = {cx, split_y, lx, ly + math.floor(br * 0.3), tw, 1}
        fol[#fol+1] = {lx, ly, br * (1.0 + math.random() * 0.2),
                       br * (0.85 + math.random() * 0.2)}
        -- right branch + blob
        local rx_pos = cx + spread
        local ry_pos = branch_top + math.random(-2, 2)
        trunks[3] = {cx, split_y, rx_pos, ry_pos + math.floor(br * 0.3), tw, 1}
        fol[#fol+1] = {rx_pos, ry_pos, br * (1.0 + math.random() * 0.2),
                       br * (0.85 + math.random() * 0.2)}
        -- optional center blob at junction
        if math.random() < 0.45 then
            fol[#fol+1] = {cx, split_y - math.floor(br * 0.5),
                           br * 0.70, br * 0.60}
        end

    elseif tree_type == 5 then
        ----------------------------------------------------------------
        -- WIDE SPREADING: trunk + center blob + side blobs
        ----------------------------------------------------------------
        local br = math.max(3, math.floor(math.min(w, h) * 0.17))
        local crown_cy = br + 3
        local spread = math.floor(w * 0.26)
        local tw = math.max(3, math.floor(w * 0.13))
        trunks[1] = {cx, h, cx, crown_cy + math.floor(br * 0.15), tw, tw - 1}
        -- center
        fol[1] = {cx, crown_cy, br, math.floor(br * 0.85)}
        -- sides
        fol[2] = {cx - spread, crown_cy + math.floor(br * 0.12),
                  math.floor(br * 0.75), math.floor(br * 0.65)}
        fol[3] = {cx + spread, crown_cy + math.floor(br * 0.12),
                  math.floor(br * 0.75), math.floor(br * 0.65)}

    else
        ----------------------------------------------------------------
        -- BUSH: 1 blob, no trunk
        ----------------------------------------------------------------
        local brx = math.max(2, math.floor(w * 0.42))
        local bry = math.max(2, math.floor(h * 0.42))
        fol[1] = {cx, math.floor(h * 0.55), brx, bry}
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
            hp = 5,
            max_hp = 5,
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

    local num_clusters = math.random(3, 5)
    local clusters = {}
    for _ = 1, num_clusters do
        local ccx = math.random(C.WALL_WIDTH + 30, world_w - C.WALL_WIDTH - 30)
        local size = math.random(2, 4)
        table.insert(clusters, {x = ccx, size = size})
    end

    for _, cluster in ipairs(clusters) do
        for _ = 1, cluster.size do
            local spread = 8 + cluster.size * 3
            local tx = cluster.x + (math.random() - 0.5) * spread * 2
            local size_hint
            local rr = math.random()
            if rr < 0.30 then size_hint = "small"
            elseif rr < 0.65 then size_hint = "medium"
            else size_hint = "large"
            end
            place_tree(tx, size_hint)
        end
    end

    local num_lone = math.random(2, 4)
    for _ = 1, num_lone do
        local tx = math.random(C.WALL_WIDTH + 12, world_w - C.WALL_WIDTH - 12)
        local size_hint
        local rr = math.random()
        if rr < 0.3 then size_hint = "small"
        elseif rr < 0.7 then size_hint = "medium"
        else size_hint = "large"
        end
        place_tree(tx, size_hint)
    end

    table.sort(world.trees, function(a, b) return a.depth < b.depth end)
end

return M
