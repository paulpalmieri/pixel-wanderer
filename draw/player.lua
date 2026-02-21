-- draw/player.lua
-- Part-based robot renderer with animation support
-- Reads animation state from world.player, applies per-part offsets
-- Returns axe anchor position for draw_axe()

local palette = require("core.palette")
local C       = require("core.const")
local anim    = require("gen.anim")

local set_color  = palette.set_color
local draw_pixel = palette.draw_pixel

local M = {}

-- Get per-part offsets for the current animation state
local function get_offsets(player)
    local swing = player.axe_swing

    -- Priority: swing > land squash > jump > walk > idle
    if swing > 0 and swing < 1 then
        return anim.get_swing_offsets(swing, player.facing)
    end

    if not player.on_ground then
        if player.vy < -20 then
            return anim.get_jump_offsets("rising")
        else
            return anim.get_jump_offsets("falling")
        end
    end

    if player.squash_timer and player.squash_timer > 0 then
        local progress = 1 - (player.squash_timer / player.squash_duration)
        return anim.get_land_offsets(progress)
    end

    if player.moving then
        local walk = anim.walk
        local frame_idx = player.walk_frame % walk.num_frames
        return walk.frames[frame_idx] or {}
    end

    -- Idle: pure breathing, no lateral
    return anim.get_idle_offsets(player.idle_timer or 0)
end

-- Get offset for a specific part from the offset table
local function part_offset(offsets, part_name)
    local o = offsets[part_name]
    if o then return o[1], o[2] end
    return 0, 0
end

function M.draw_player(world)
    local player = world.player
    local sprite = player.sprite
    local px = math.floor(player.x + 0.5)
    local py = math.floor(player.y + 0.5)
    local facing = player.facing
    local body_w = sprite.body_w

    -- Elevator door clipping: during entrance animation, only show player through door gap
    local entrance_clip = not world.entrance_anim_done and (world.door_state == "closed" or world.door_state == "opening" or world.door_state == "walk_in")
    if entrance_clip then
        local cam_ix = math.floor(world.camera_x + 0.5)
        local cam_iy = math.floor(world.camera_y + 0.5)
        local door_left = C.WALL_WIDTH
        local door_w = C.ENTRANCE_DOOR_W
        local door_h = 20
        local door_top = world.ground.base_y - door_h
        local half_w = math.floor(door_w / 2)
        local open_amount = world.door_open_amount or 0
        local slide = math.floor(half_w * open_amount)

        -- Gap in canvas space (untransformed)
        local gap_left = door_left + half_w - slide - cam_ix
        local gap_top = door_top - cam_iy

        if open_amount >= 1.0 then
            -- Door fully open: clip from door left edge to end of screen, full height
            local clip_left = door_left - cam_ix
            love.graphics.setScissor(clip_left, 0, C.GAME_W - clip_left, C.GAME_H)
        else
            local gap_right = door_left + half_w + slide - cam_ix
            local gap_w = gap_right - gap_left
            if gap_w > 0 then
                love.graphics.setScissor(gap_left, gap_top, gap_w, door_h)
            else
                -- Door fully closed — don't draw player at all
                love.graphics.setScissor(0, 0, 0, 0)
            end
        end
    end

    -- Center the body in the 16px bounding box
    local body_offset_x = math.floor((16 - body_w) / 2)
    local base_x = px + body_offset_x
    local base_y = py + (16 - sprite.total_h)

    -- Get animation offsets
    local offsets = get_offsets(player)

    -- Draw trail ghost (previous frame position, translucent)
    if player.moving and player.on_ground and player.trail_x then
        local trail_bx = math.floor(player.trail_x + 0.5) + body_offset_x
        local trail_by = math.floor(player.trail_y + 0.5) + (16 - sprite.total_h)
        local torso = sprite.torso
        set_color(sprite.colors.body_lo, 0.25)
        for _, p in ipairs(torso.pixels) do
            local tdx = p.dx
            if facing == 1 then tdx = (torso.w - 1) - p.dx end
            draw_pixel(trail_bx + tdx, trail_by + torso.anchor_y + p.dy)
        end
    end

    -- Draw each part in draw order
    -- The facing flip works as follows:
    --   1. Each part has an anchor (defined for facing LEFT — the default art direction)
    --   2. When facing RIGHT, we mirror the entire character around the body center
    --   3. Anim offsets are in "character space" — positive = forward (toward facing dir)
    for _, part_name in ipairs(sprite.draw_order) do
        local part = sprite[part_name]
        if part then
            local odx, ody = part_offset(offsets, part_name)

            -- Compute the anchor in screen space
            local ax = part.anchor_x
            if facing == 1 then
                -- Mirror anchor AND part width around body center
                ax = body_w - part.anchor_x - part.w
            end

            local custom_arm = nil
            if part_name == "near_arm" and player.axe_swing > 0 and player.axe_swing < 1 then
                custom_arm = anim.get_swing_arm_shape(player.axe_swing)
            end

            if custom_arm then
                for _, p in ipairs(custom_arm) do
                    local pdx = p.dx * facing -- custom arm defines +x as FORWARD
                    local final_x = base_x + ax + pdx + odx * facing
                    local final_y = base_y + part.anchor_y + p.dy + ody

                    set_color(sprite.colors.body_hi)
                    draw_pixel(final_x, final_y)
                end
            else
                -- Draw each pixel of the part
                for _, p in ipairs(part.pixels) do
                    local pdx = p.dx
                    if facing == 1 then
                        -- Mirror pixel within the part
                        pdx = (part.w - 1) - p.dx
                    end

                    local final_x = base_x + ax + pdx + odx * facing
                    local final_y = base_y + part.anchor_y + p.dy + ody

                    set_color(p.c)
                    draw_pixel(final_x, final_y)
                end
            end
        end
    end

    -- Compute axe anchor: near arm tip position
    local near_arm = sprite.near_arm
    local arm_odx, arm_ody = part_offset(offsets, "near_arm")
    local arm_ax = near_arm.anchor_x
    if facing == 1 then
        arm_ax = body_w - near_arm.anchor_x - near_arm.w
    end

    local hand_dx = 0
    local hand_dy = near_arm.h
    if player.axe_swing > 0 and player.axe_swing < 1 then
        local custom_arm = anim.get_swing_arm_shape(player.axe_swing)
        if custom_arm then
            local last_p = custom_arm[#custom_arm]
            hand_dx = last_p.dx
            hand_dy = last_p.dy + 1
        end
    end

    -- Axe attaches at the hand pixel smoothly
    local axe_x = base_x + arm_ax + (arm_odx + hand_dx) * facing
    local axe_y = base_y + near_arm.anchor_y + arm_ody + hand_dy

    -- Axe follows arm position exactly — no separate bob timer
    -- Reset entrance clip scissor
    if entrance_clip then
        love.graphics.setScissor()
    end

    return {
        hand_x = axe_x,
        hand_y = axe_y,
        base_x = base_x,
        base_y = base_y,
        body_w = body_w
    }
end

function M.draw_axe(world, result)
    local player = world.player
    local dir = player.facing
    local swing = player.axe_swing

    -- Elevator door clipping for axe too
    local entrance_clip = not world.entrance_anim_done and (world.door_state == "closed" or world.door_state == "opening" or world.door_state == "walk_in")
    if entrance_clip then
        local cam_ix = math.floor(world.camera_x + 0.5)
        local cam_iy = math.floor(world.camera_y + 0.5)
        local door_left = C.WALL_WIDTH
        local door_w = C.ENTRANCE_DOOR_W
        local door_h = 20
        local door_top = world.ground.base_y - door_h
        local half_w = math.floor(door_w / 2)
        local open_amount = world.door_open_amount or 0
        local slide = math.floor(half_w * open_amount)
        local gap_left = door_left + half_w - slide - cam_ix
        local gap_top = door_top - cam_iy

        if open_amount >= 1.0 then
            local clip_left = door_left - cam_ix
            love.graphics.setScissor(clip_left, 0, C.GAME_W - clip_left, C.GAME_H)
        else
            local gap_right = door_left + half_w + slide - cam_ix
            local gap_w = gap_right - gap_left
            if gap_w > 0 then
                love.graphics.setScissor(gap_left, gap_top, gap_w, door_h)
            else
                love.graphics.setScissor(0, 0, 0, 0)
            end
        end
    end

    local hx = result.hand_x
    local hy = result.hand_y
    local d = dir

    -- Color constants
    -- Color constants
    local HANDLE_DARK = 16    -- dark (Dark Violet Black)
    local HANDLE_LIGHT = 5    -- light (Burnt Orange)
    local HANDLE_HI = 6       -- wood highlight (Warm Gold)
    local BLADE_INNER = 19    -- steel mid (Light Gray)
    local BLADE_OUTER = 20    -- steel hi (Warm White)
    local BLADE_EDGE  = 16    -- steel shadow (Dark Violet Black)
    local SMEAR       = 20    -- Warm White for motion smear

    local axe_pixels = {}
    if swing <= 0.0 then
        -- REST: held horizontally forward
        table.insert(axe_pixels, {hx,       hy,     HANDLE_DARK})
        table.insert(axe_pixels, {hx + d,   hy,     HANDLE_LIGHT})
        table.insert(axe_pixels, {hx + d*2, hy,     HANDLE_LIGHT})
        table.insert(axe_pixels, {hx + d*3, hy,     HANDLE_LIGHT})
        table.insert(axe_pixels, {hx + d*4, hy,     HANDLE_HI})
        -- Big Blade head (Standard Shape)
        table.insert(axe_pixels, {hx + d*5, hy - 2, BLADE_OUTER})
        table.insert(axe_pixels, {hx + d*5, hy - 1, BLADE_OUTER})
        table.insert(axe_pixels, {hx + d*5, hy,     BLADE_INNER})
        table.insert(axe_pixels, {hx + d*5, hy + 1, BLADE_INNER})
        table.insert(axe_pixels, {hx + d*5, hy + 2, BLADE_OUTER})
        table.insert(axe_pixels, {hx + d*6, hy - 2, BLADE_OUTER})
        table.insert(axe_pixels, {hx + d*6, hy - 1, BLADE_INNER})
        table.insert(axe_pixels, {hx + d*6, hy,     BLADE_INNER})
        table.insert(axe_pixels, {hx + d*6, hy + 1, BLADE_EDGE})
        table.insert(axe_pixels, {hx + d*6, hy + 2, BLADE_EDGE})
        table.insert(axe_pixels, {hx + d*7, hy - 1, BLADE_INNER})
        table.insert(axe_pixels, {hx + d*7, hy,     BLADE_EDGE})
        table.insert(axe_pixels, {hx + d*7, hy + 1, BLADE_EDGE})

    elseif swing <= 0.25 then
        -- WINDUP: hand is down/back. Axe points up and back
        table.insert(axe_pixels, {hx,       hy,     HANDLE_DARK})
        table.insert(axe_pixels, {hx - d,   hy - 1, HANDLE_LIGHT})
        table.insert(axe_pixels, {hx - d*2, hy - 2, HANDLE_LIGHT})
        table.insert(axe_pixels, {hx - d*3, hy - 3, HANDLE_LIGHT})
        table.insert(axe_pixels, {hx - d*4, hy - 4, HANDLE_HI})
        -- Blade pointing back/up (Standard Shape Rotated)
        table.insert(axe_pixels, {hx - d*3, hy - 5, BLADE_OUTER})
        table.insert(axe_pixels, {hx - d*4, hy - 6, BLADE_OUTER})
        table.insert(axe_pixels, {hx - d*5, hy - 5, BLADE_INNER})
        table.insert(axe_pixels, {hx - d*6, hy - 4, BLADE_INNER})
        table.insert(axe_pixels, {hx - d*7, hy - 3, BLADE_OUTER})
        table.insert(axe_pixels, {hx - d*4, hy - 7, BLADE_OUTER})
        table.insert(axe_pixels, {hx - d*5, hy - 6, BLADE_INNER})
        table.insert(axe_pixels, {hx - d*6, hy - 5, BLADE_INNER})
        table.insert(axe_pixels, {hx - d*7, hy - 4, BLADE_EDGE})
        table.insert(axe_pixels, {hx - d*8, hy - 3, BLADE_EDGE})
        table.insert(axe_pixels, {hx - d*6, hy - 7, BLADE_INNER})
        table.insert(axe_pixels, {hx - d*7, hy - 6, BLADE_EDGE})
        table.insert(axe_pixels, {hx - d*8, hy - 5, BLADE_EDGE})

    elseif swing <= 0.35 then
        -- PEAK: hand is mid-back. Axe points steeply up
        table.insert(axe_pixels, {hx,       hy,     HANDLE_DARK})
        table.insert(axe_pixels, {hx,       hy - 1, HANDLE_LIGHT})
        table.insert(axe_pixels, {hx,       hy - 2, HANDLE_LIGHT})
        table.insert(axe_pixels, {hx,       hy - 3, HANDLE_LIGHT})
        table.insert(axe_pixels, {hx,       hy - 4, HANDLE_HI})
        -- Blade high and pointing forward
        table.insert(axe_pixels, {hx + d*2, hy - 5, BLADE_OUTER})
        table.insert(axe_pixels, {hx + d,   hy - 5, BLADE_OUTER})
        table.insert(axe_pixels, {hx,       hy - 5, BLADE_INNER})
        table.insert(axe_pixels, {hx - d,   hy - 5, BLADE_INNER})
        table.insert(axe_pixels, {hx - d*2, hy - 5, BLADE_OUTER})
        table.insert(axe_pixels, {hx + d*2, hy - 6, BLADE_OUTER})
        table.insert(axe_pixels, {hx + d,   hy - 6, BLADE_INNER})
        table.insert(axe_pixels, {hx,       hy - 6, BLADE_INNER})
        table.insert(axe_pixels, {hx - d,   hy - 6, BLADE_EDGE})
        table.insert(axe_pixels, {hx - d*2, hy - 6, BLADE_EDGE})
        table.insert(axe_pixels, {hx + d,   hy - 7, BLADE_INNER})
        table.insert(axe_pixels, {hx,       hy - 7, BLADE_EDGE})
        table.insert(axe_pixels, {hx - d,   hy - 7, BLADE_EDGE})

    elseif swing <= 0.45 then
        -- STRIKE: hand is front-down. Axe swinging down
        table.insert(axe_pixels, {hx,       hy,     HANDLE_DARK})
        table.insert(axe_pixels, {hx + d,   hy + 1, HANDLE_LIGHT})
        table.insert(axe_pixels, {hx + d*2, hy + 2, HANDLE_LIGHT})
        table.insert(axe_pixels, {hx + d*3, hy + 3, HANDLE_LIGHT})
        table.insert(axe_pixels, {hx + d*4, hy + 4, HANDLE_HI})
        -- Blade angled down-front
        table.insert(axe_pixels, {hx + d*6, hy + 3, BLADE_OUTER})
        table.insert(axe_pixels, {hx + d*5, hy + 4, BLADE_OUTER})
        table.insert(axe_pixels, {hx + d*5, hy + 5, BLADE_INNER})
        table.insert(axe_pixels, {hx + d*4, hy + 6, BLADE_INNER})
        table.insert(axe_pixels, {hx + d*3, hy + 7, BLADE_OUTER})
        table.insert(axe_pixels, {hx + d*7, hy + 4, BLADE_OUTER})
        table.insert(axe_pixels, {hx + d*6, hy + 5, BLADE_INNER})
        table.insert(axe_pixels, {hx + d*5, hy + 6, BLADE_INNER})
        table.insert(axe_pixels, {hx + d*4, hy + 7, BLADE_EDGE})
        table.insert(axe_pixels, {hx + d*3, hy + 8, BLADE_EDGE})
        table.insert(axe_pixels, {hx + d*7, hy + 6, BLADE_INNER})
        table.insert(axe_pixels, {hx + d*6, hy + 7, BLADE_EDGE})
        table.insert(axe_pixels, {hx + d*5, hy + 8, BLADE_EDGE})

    elseif swing <= 0.65 then
        -- IMPACT: hand straight down. Axe points down-front
        table.insert(axe_pixels, {hx,       hy,     HANDLE_DARK})
        table.insert(axe_pixels, {hx,       hy + 1, HANDLE_LIGHT})
        table.insert(axe_pixels, {hx,       hy + 2, HANDLE_LIGHT})
        table.insert(axe_pixels, {hx + d,   hy + 3, HANDLE_LIGHT})
        table.insert(axe_pixels, {hx + d,   hy + 4, HANDLE_HI})
        -- Blade
        table.insert(axe_pixels, {hx + d*3, hy + 3, BLADE_OUTER})
        table.insert(axe_pixels, {hx + d*2, hy + 4, BLADE_OUTER})
        table.insert(axe_pixels, {hx + d*1, hy + 5, BLADE_INNER})
        table.insert(axe_pixels, {hx + d*1, hy + 6, BLADE_INNER})
        table.insert(axe_pixels, {hx,       hy + 7, BLADE_OUTER})
        table.insert(axe_pixels, {hx + d*3, hy + 4, BLADE_OUTER})
        table.insert(axe_pixels, {hx + d*2, hy + 5, BLADE_INNER})
        table.insert(axe_pixels, {hx + d*2, hy + 6, BLADE_INNER})
        table.insert(axe_pixels, {hx + d*1, hy + 7, BLADE_EDGE})
        table.insert(axe_pixels, {hx + d*1, hy + 8, BLADE_EDGE})
        table.insert(axe_pixels, {hx + d*3, hy + 6, BLADE_INNER})
        table.insert(axe_pixels, {hx + d*2, hy + 7, BLADE_EDGE})
        table.insert(axe_pixels, {hx + d*2, hy + 8, BLADE_EDGE})

    else
        -- REBOUND / RECOVERY
        -- Identical to REST, but positioned at the current hx, hy
        table.insert(axe_pixels, {hx,       hy,     HANDLE_DARK})
        table.insert(axe_pixels, {hx + d,   hy,     HANDLE_LIGHT})
        table.insert(axe_pixels, {hx + d*2, hy,     HANDLE_LIGHT})
        table.insert(axe_pixels, {hx + d*3, hy,     HANDLE_LIGHT})
        table.insert(axe_pixels, {hx + d*4, hy,     HANDLE_HI})
        
        table.insert(axe_pixels, {hx + d*5, hy - 2, BLADE_OUTER})
        table.insert(axe_pixels, {hx + d*5, hy - 1, BLADE_OUTER})
        table.insert(axe_pixels, {hx + d*5, hy,     BLADE_INNER})
        table.insert(axe_pixels, {hx + d*5, hy + 1, BLADE_INNER})
        table.insert(axe_pixels, {hx + d*5, hy + 2, BLADE_OUTER})
        table.insert(axe_pixels, {hx + d*6, hy - 2, BLADE_OUTER})
        table.insert(axe_pixels, {hx + d*6, hy - 1, BLADE_INNER})
        table.insert(axe_pixels, {hx + d*6, hy,     BLADE_INNER})
        table.insert(axe_pixels, {hx + d*6, hy + 1, BLADE_EDGE})
        table.insert(axe_pixels, {hx + d*6, hy + 2, BLADE_EDGE})
        table.insert(axe_pixels, {hx + d*7, hy - 1, BLADE_INNER})
        table.insert(axe_pixels, {hx + d*7, hy,     BLADE_EDGE})
        table.insert(axe_pixels, {hx + d*7, hy + 1, BLADE_EDGE})
    end

    -- Dynamic Smear: keyframed crescent arc from shoulder pivot
    if swing > 0.0 and swing <= 0.45 then
        local cx = result.base_x + math.floor(result.body_w / 2)
        local cy = result.base_y + 4 -- shoulder pivot

        local radius = 10
        -- Arc angles: behind-down to forward-down (0=right, pi=left, -pi/2=up)
        local a0, a1 -- start and end angle for this keyframe
        if swing <= 0.25 then
            -- WINDUP: short arc behind the character
            a0 = math.pi * 0.75
            a1 = math.pi * 0.55
        elseif swing <= 0.35 then
            -- PEAK: arc sweeps overhead
            a0 = math.pi * 0.65
            a1 = math.pi * 0.2
        else
            -- STRIKE: full crescent from behind to forward-down
            a0 = math.pi * 0.5
            a1 = math.pi * -0.2
        end

        -- Sample the arc and draw a wide crescent (inner + outer radius)
        local r_inner = radius - 2
        local r_outer = radius + 1
        local steps = 16
        for i = 0, steps do
            local t = i / steps
            local angle = a0 + (a1 - a0) * t
            local cos_a = math.cos(angle)
            local sin_a = -math.sin(angle) -- flip Y (screen coords)

            -- Outer edge
            local ox = cx + math.floor(cos_a * r_outer * d + 0.5)
            local oy = cy + math.floor(sin_a * r_outer + 0.5)
            -- Inner edge
            local ix = cx + math.floor(cos_a * r_inner * d + 0.5)
            local iy = cy + math.floor(sin_a * r_inner + 0.5)
            -- Center
            local mx = cx + math.floor(cos_a * radius * d + 0.5)
            local my = cy + math.floor(sin_a * radius + 0.5)

            set_color(SMEAR)
            draw_pixel(ox, oy)
            draw_pixel(ix, iy)
            draw_pixel(mx, my)
        end
    end

    for _, ap in ipairs(axe_pixels) do
        set_color(ap[3])
        draw_pixel(ap[1], ap[2])
    end

    -- Reset entrance clip scissor
    if entrance_clip then
        love.graphics.setScissor()
    end
end

return M
