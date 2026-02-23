-- gen/character.lua
-- Part-based procedural robot generator
-- Returns a table of body parts, each with pixel data and anchor points
-- 16px bounding box, ~14px drawn (head 4 + torso 5 + legs 3 + antenna 1-2)

local M = {}

-- Color palettes: each set creates a cohesive robot look
-- 4 colors only: {body_hi, body_mid, body_lo, eye}
local PALETTES = {
    { -- Brushed Steel (Clean)
        name = "brushed_steel",
        body_hi = 20, body_mid = 19, body_lo = 18, eye = 12,
    },
    { -- Dark Iron (Heavy)
        name = "dark_iron",
        body_hi = 19, body_mid = 10, body_lo = 16, eye = 13,
    },
    { -- Industrial (Amber/Rust details)
        name = "industrial",
        body_hi = 20, body_mid = 6, body_lo = 5, eye = 12,
    },
    { -- Cobalt Steel (Toned)
        name = "cobalt_steel",
        body_hi = 12, body_mid = 11, body_lo = 10, eye = 20,
    },
    { -- Rust Red (Weathered)
        name = "rust_red",
        body_hi = 13, body_mid = 4, body_lo = 3, eye = 6,
    },
    { -- Plum Night (Dark)
        name = "plum_night",
        body_hi = 13, body_mid = 14, body_lo = 15, eye = 12,
    },
}

-- Body type variations affect torso dimensions
local BODY_TYPES = {
    { name = "standard", torso_w = 6, torso_h = 5 },
    { name = "stocky",   torso_w = 7, torso_h = 4 },
    { name = "tall",     torso_w = 6, torso_h = 6 },
    { name = "tall",     torso_w = 6, torso_h = 6 },  -- weighted: tall appears 50%
}

-- Build pixel list with soft shading (2-tone: mid fill + lo shadow edge)
-- Much subtler than the old 3-band approach
local function make_soft_rect(w, h, pal, extras)
    local pixels = {}
    for row = 0, h - 1 do
        for col = 0, w - 1 do
            local color
            -- Shadow: rightmost column only (single edge shadow)
            if col == w - 1 then
                color = pal.body_lo
            -- Highlight: single specular pixel at top-left corner
            elseif col == 0 and row == 0 then
                color = pal.body_hi
            else
                color = pal.body_mid
            end
            table.insert(pixels, {dx = col, dy = row, c = color})
        end
    end
    -- Apply extras (eyes, details) — overwrites existing pixels
    if extras then
        for _, e in ipairs(extras) do
            for i, p in ipairs(pixels) do
                if p.dx == e.dx and p.dy == e.dy then
                    pixels[i].c = e.c
                    break
                end
            end
        end
    end
    return pixels
end

-- Build a 1px-wide arm with lighter shading for visibility
-- Uses body_hi so arms contrast against body_mid torso and show behind it
local function make_arm(h, pal)
    local pixels = {}
    for row = 0, h - 1 do
        local color = pal.body_mid
        if row == 0 then color = pal.body_hi end
        table.insert(pixels, {dx = 0, dy = row, c = color})
    end
    return pixels
end

local function make_leg(h, pal)
    local pixels = {}
    for row = 0, h - 1 do
        local color
        if row == h - 1 then
            color = pal.body_lo   -- foot darker
        else
            color = pal.body_mid  -- body tone
        end
        table.insert(pixels, {dx = 0, dy = row, c = color})
    end
    return pixels
end

local function build_character(pal, body_type, eye_style, antenna_style, detail_style)
    local torso_w = body_type.torso_w
    local torso_h = body_type.torso_h
    local head_w = 5  -- always narrower than torso

    -- HEAD: 5×4, with eye style variation
    local head_extras = {}

    if eye_style == 1 then
        -- Two 1×2 eye slits
        table.insert(head_extras, {dx = 1, dy = 1, c = pal.eye})
        table.insert(head_extras, {dx = 1, dy = 2, c = pal.eye})
        table.insert(head_extras, {dx = 3, dy = 1, c = pal.eye})
        table.insert(head_extras, {dx = 3, dy = 2, c = pal.eye})
    elseif eye_style == 2 then
        -- Visor bar across row 1-2
        for col = 1, 3 do
            table.insert(head_extras, {dx = col, dy = 1, c = pal.eye})
        end
    elseif eye_style == 3 then
        -- Single cyclops eye (2×2 center)
        table.insert(head_extras, {dx = 1, dy = 1, c = pal.eye})
        table.insert(head_extras, {dx = 2, dy = 1, c = pal.eye})
        table.insert(head_extras, {dx = 1, dy = 2, c = pal.eye})
        table.insert(head_extras, {dx = 2, dy = 2, c = pal.eye})
    else
        -- Dot eyes: two single pixels
        table.insert(head_extras, {dx = 1, dy = 1, c = pal.eye})
        table.insert(head_extras, {dx = 3, dy = 1, c = pal.eye})
    end

    -- Neck accent: bottom row of head is darker (body_lo) for separation
    for col = 0, head_w - 1 do
        table.insert(head_extras, {dx = col, dy = 3, c = pal.body_lo})
    end

    local head_pixels = make_soft_rect(head_w, 4, pal, head_extras)

    -- Antenna: 0-2px nub on top of head
    local antenna_pixels = {}
    if antenna_style == 2 then
        table.insert(antenna_pixels, {dx = 2, dy = -1, c = pal.eye})
    elseif antenna_style == 3 then
        local side = math.random(0, 1) == 0 and 1 or 3
        table.insert(antenna_pixels, {dx = side, dy = -1, c = pal.body_lo})
        table.insert(antenna_pixels, {dx = side, dy = -2, c = pal.eye})
    elseif antenna_style == 4 then
        -- Twin short antennae
        table.insert(antenna_pixels, {dx = 1, dy = -1, c = pal.body_lo})
        table.insert(antenna_pixels, {dx = 3, dy = -1, c = pal.body_lo})
    end
    -- Merge antenna into head pixels
    for _, ap in ipairs(antenna_pixels) do
        table.insert(head_pixels, ap)
    end

    -- TORSO: variable size, with detail variation
    local torso_extras = {}

    if detail_style == 1 then
        -- Horizontal panel line at row 2
        for col = 1, torso_w - 2 do
            table.insert(torso_extras, {dx = col, dy = 2, c = pal.body_lo})
        end
    elseif detail_style == 2 then
        -- Two rivet dots (highlight)
        table.insert(torso_extras, {dx = 1, dy = 1, c = pal.body_hi})
        table.insert(torso_extras, {dx = torso_w - 2, dy = 1, c = pal.body_hi})
    elseif detail_style == 3 then
        -- Center accent plate (2×2, lighter)
        local cx = math.floor(torso_w / 2) - 1
        table.insert(torso_extras, {dx = cx, dy = 1, c = pal.body_hi})
        table.insert(torso_extras, {dx = cx + 1, dy = 1, c = pal.body_hi})
        table.insert(torso_extras, {dx = cx, dy = 2, c = pal.body_hi})
        table.insert(torso_extras, {dx = cx + 1, dy = 2, c = pal.body_hi})
    elseif detail_style == 4 then
        -- Vertical stripe down center
        local cx = math.floor(torso_w / 2)
        for row = 0, torso_h - 1 do
            table.insert(torso_extras, {dx = cx, dy = row, c = pal.body_lo})
        end
    else
        -- Cross pattern
        local cx = math.floor(torso_w / 2)
        local cy = math.floor(torso_h / 2)
        table.insert(torso_extras, {dx = cx, dy = cy, c = pal.body_hi})
        table.insert(torso_extras, {dx = cx - 1, dy = cy, c = pal.body_hi})
        table.insert(torso_extras, {dx = cx + 1, dy = cy, c = pal.body_hi})
        table.insert(torso_extras, {dx = cx, dy = cy - 1, c = pal.body_hi})
        table.insert(torso_extras, {dx = cx, dy = cy + 1, c = pal.body_hi})
    end

    -- Shoulder accents: 1px "pauldrons" on top corners of torso
    local has_shoulders = (pal.name == "player_industrial") or (math.random() > 0.4)
    if has_shoulders then
        table.insert(torso_extras, {dx = 0, dy = 0, c = pal.body_lo})
        table.insert(torso_extras, {dx = torso_w - 1, dy = 0, c = pal.body_lo})
    end

    local torso_pixels = make_soft_rect(torso_w, torso_h, pal, torso_extras)

    -- ARMS: 1×4 each (darker shade for visibility)
    local arm_pixels = make_arm(4, pal)

    -- LEGS: 1×3 each, with foot pixel
    local leg_pixels = make_leg(3, pal)

    -- Head centering: center the narrower head on the wider torso
    local head_offset_x = math.floor((torso_w - head_w) / 2)

    local total_h = 4 + torso_h + 3  -- head + torso + legs

    return {
        -- Head: centered on torso, offset up from torso
        head = {
            w = head_w, h = 4,
            pixels = head_pixels,
            anchor_x = head_offset_x, anchor_y = 0,
        },
        -- Torso: anchored below head
        torso = {
            w = torso_w, h = torso_h,
            pixels = torso_pixels,
            anchor_x = 0, anchor_y = 4,  -- below head
        },
        -- Arms: anchored 1px outside torso edge for visibility
        near_arm = {
            w = 1, h = 4,
            pixels = arm_pixels,
            anchor_x = torso_w, anchor_y = 4,   -- 1px outside right edge
        },
        far_arm = {
            w = 1, h = 4,
            pixels = arm_pixels,
            anchor_x = -1, anchor_y = 4,         -- 1px outside left edge
        },
        -- Legs: anchored at hip (torso bottom)
        near_leg = {
            w = 1, h = 3,
            pixels = leg_pixels,
            anchor_x = torso_w - 2, anchor_y = 4 + torso_h,
        },
        far_leg = {
            w = 1, h = 3,
            pixels = leg_pixels,
            anchor_x = 1, anchor_y = 4 + torso_h,
        },
        -- Draw order: far limbs behind, then body, then near limbs in front
        draw_order = {"far_leg", "far_arm", "torso", "head", "near_leg", "near_arm"},
        -- Metadata
        palette_name = pal.name,
        eye_style = eye_style,
        antenna_style = antenna_style,
        detail_style = detail_style,
        body_type = body_type.name,
        -- Colors for axe/effects
        colors = {
            eye = pal.eye,
            body_hi = pal.body_hi,
            body_mid = pal.body_mid,
            body_lo = pal.body_lo,
        },
        -- Layout constants
        body_w = torso_w,        -- widest part (torso) for flip math
        head_w = head_w,
        total_h = total_h,
    }
end

function M.generate()
    local pal = PALETTES[math.random(1, #PALETTES)]
    local body_type = BODY_TYPES[math.random(1, #BODY_TYPES)]
    local eye_style = math.random(1, 4)
    local antenna_style = math.random(1, 4)
    local detail_style = math.random(1, 5)

    return build_character(pal, body_type, eye_style, antenna_style, detail_style)
end

function M.generate_player()
    local pal = {
        name = "player_industrial",
        body_hi = 6,   -- Warm Gold (Yellow)
        body_mid = 17, -- Charcoal
        body_lo = 1,   -- Black
        eye = 6,       -- Warm Gold (Yellow)
    }
    local body_type = BODY_TYPES[1] -- standard (6x5)
    local eye_style = 2 -- visor bar
    local antenna_style = 2 -- center nub
    local detail_style = 2 -- rivets

    return build_character(pal, body_type, eye_style, antenna_style, detail_style)
end


return M
