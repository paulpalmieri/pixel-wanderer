-- draw/terrain.lua
-- Ground surface + earth + wall rendering + entrance door

local palette = require("core.palette")
local C = require("core.const")

local set_color = palette.set_color
local draw_pixel = palette.draw_pixel
local GAME_W = C.GAME_W
local GAME_H = C.GAME_H
local WALL_WIDTH = C.WALL_WIDTH
local WALL_HEIGHT = C.WALL_HEIGHT

local M = {}

-- Simple deterministic noise based on position (LuaJIT-safe)
local function hash2(x, y)
    local n = ((x * 73) + (y * 151) + x * y * 17) % 97
    return n / 96.0  -- 0..1
end

function M.draw_ground(cam_ix, cam_iy, world)
    local wx_start = cam_ix
    local wx_end = cam_ix + GAME_W - 1
    local base_y = world.ground.base_y

    for wx = wx_start, wx_end do
        if wx >= 0 and wx < world.ground.width then

            -- ── Surface row (top of ground) ──────────────────────────
            -- Use a tight, low-contrast pattern: mostly surface-bright with
            -- occasional surface-shadow specks and a rare dirt-light pebble.
            local h = hash2(wx, base_y)
            if h < 0.12 then
                set_color(33) -- dirt light pebble
            elseif h < 0.30 then
                set_color(32) -- surface shadow
            else
                set_color(31) -- surface bright (dominant)
            end
            draw_pixel(wx, base_y)

            -- ── Earth below surface ───────────────────────────────────
            -- Depth-based shading: lighter near surface, darker deep down.
            -- Small noise clusters break up uniformity without feeling chaotic.
            local max_wy = cam_iy + GAME_H - 1
            for wy = base_y + 1, max_wy do
                local dy = wy - base_y  -- 1 = just below surface
                local n = hash2(wx, wy)

                -- Every ~5 rows draw a faint horizontal "strata" line
                local strata = (wy % 5 == 0)

                if strata then
                    -- thin darker band to mimic soil compression lines
                    if n < 0.40 then
                        set_color(35) -- dirt dark
                    else
                        set_color(34) -- dirt mid
                    end
                elseif dy <= 3 then
                    -- sub-surface transition: mix surface bright into the mid dirt
                    if n < 0.20 then
                        set_color(31) -- echoed surface bright
                    elseif n < 0.50 then
                        set_color(34) -- dirt mid
                    else
                        set_color(35) -- dirt dark
                    end
                else
                    -- Deep earth: mostly dark, with occasional dirt-mid vein
                    if n < 0.22 then
                        set_color(34) -- dirt mid vein
                    else
                        set_color(35) -- dirt dark (dominant)
                    end
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

    -- ============================================================
    -- ENTRANCE DOOR (on the left wall)
    -- ============================================================
    local gy = world.ground.base_y
    local door_left = WALL_WIDTH
    local door_w = C.ENTRANCE_DOOR_W
    local door_h = 20
    local door_top = gy - door_h
    local door_bottom = gy

    local open_amount = world.door_open_amount or 0
    local half_w = math.floor(door_w / 2)
    local slide = math.floor(half_w * open_amount)

    -- ── Door frame ──────────────────────────────────────────────
    -- Top bar: darkest shade for depth
    for dx = -1, door_w do
        set_color(21) -- steel shadow (dark frame)
        draw_pixel(door_left + dx, door_top - 1)
    end
    -- Side pillars
    for dy = 0, door_h - 1 do
        set_color(21) -- steel shadow
        draw_pixel(door_left - 1, door_top + dy)
        draw_pixel(door_left + door_w, door_top + dy)
    end

    -- ── Door panel drawing helper ─────────────────────────────
    -- Each panel has:
    --   • outer edge shadow (1px inner border)
    --   • inner raised surface with top-left highlight strip
    --   • subtle vertical gradient (top brighter, bottom darker)
    --   • rivet dots near edges

    local function draw_panel(px_start, px_end, dy)
        local pw = px_end - px_start + 1
        if pw <= 0 then return end

        local wy = door_top + dy

        for px = px_start, px_end do
            local dx = px - px_start
            local wx = door_left + px

            if dy <= 1 then
                set_color(19) -- top bevel hi
            elseif dy >= door_h - 2 then
                set_color(21) -- bot bevel shd
            elseif dx == 0 then
                set_color(19) -- left bevel hi
            elseif dx == pw - 1 then
                set_color(21) -- right bevel shd
            else
                -- Heavy horizontal ribs
                if (dy % 4) == 0 then
                    set_color(21) -- recess
                elseif (dy % 4) == 1 then
                    set_color(19) -- ridge hi
                else
                    set_color(20) -- flat
                end
            end

            draw_pixel(wx, wy)
        end
    end

    -- ── Draw the two sliding panels ─────────────────────────────
    for dy = 0, door_h - 1 do
        -- Gutter between panels: 1-px dark seam in the middle
        local seam_left  = half_w - slide
        local seam_right = half_w + slide - 1

        -- Left panel: columns 0 .. half_w-1-slide  (skip last col = seam)
        if half_w - 1 - slide >= 0 then
            draw_panel(0, half_w - 1 - slide, dy)
        end
        -- Right panel: columns half_w+slide .. door_w-1
        if half_w + slide <= door_w - 1 then
            draw_panel(half_w + slide, door_w - 1, dy)
        end

        -- Central seam (dark gap between panels)
        if slide == 0 then
            set_color(21)
            draw_pixel(door_left + half_w - 1, door_top + dy)
        end
    end

    -- ── Interior behind door (dark void when opening) ──────────
    if open_amount > 0 then
        local gap_left  = door_left + half_w - slide
        local gap_right = door_left + half_w + slide - 1
        for dy = 0, door_h - 1 do
            for gx = gap_left, gap_right do
                set_color(9) -- void dark
                draw_pixel(gx, door_top + dy)
            end
        end
    end

    -- ============================================================
    -- WALL BUTTON (for spawning robots)
    -- ============================================================
    local btn_x = door_left + door_w + 3
    local btn_y = gy - 10
    local btn_w = 3
    local btn_h = 3

    -- Button housing (dark metal)
    for dy = -1, btn_h do
        for dx = -1, btn_w do
            set_color(21)
            draw_pixel(btn_x + dx, btn_y + dy)
        end
    end

    -- Button face (red if can't afford, green if can)
    local can_afford = world.player and world.player.wood_count >= 20
    for dy = 0, btn_h - 1 do
        for dx = 0, btn_w - 1 do
            if can_afford then
                set_color(36) -- bright leaf (green-ish)
            else
                set_color(45) -- red eye
            end
            draw_pixel(btn_x + dx, btn_y + dy)
        end
    end

    -- Tiny highlight on button
    if can_afford then
        set_color(17) -- forest highlight
    else
        set_color(18) -- wood highlight
    end
    draw_pixel(btn_x, btn_y)

    -- Store button position on world for proximity check
    world._btn_x = btn_x
    world._btn_y = btn_y
end

return M
