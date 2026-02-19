-- draw/player.lua
-- Skeleton-based player sprite + axe rendering
-- 2px thick limbs, shoulder-anchored axe swing

local palette = require("core.palette")
local anim_data = require("gen.anim")

local set_color = palette.set_color
local draw_pixel = palette.draw_pixel

local M = {}

-- Bresenham pixel line
local function draw_line(x1, y1, x2, y2, color_idx)
    set_color(color_idx)
    local dx = math.abs(x2 - x1)
    local dy = math.abs(y2 - y1)
    local sx = x1 < x2 and 1 or -1
    local sy = y1 < y2 and 1 or -1
    local err = dx - dy
    while true do
        draw_pixel(x1, y1)
        if x1 == x2 and y1 == y2 then break end
        local e2 = 2 * err
        if e2 > -dy then err = err - dy; x1 = x1 + sx end
        if e2 < dx then err = err + dx; y1 = y1 + sy end
    end
end

-- Get animation offsets for a joint from walk frame data
local function get_joint_offset(frame_data, joint_name)
    if frame_data and frame_data[joint_name] then
        return frame_data[joint_name][1], frame_data[joint_name][2]
    end
    return 0, 0
end

function M.draw_player(world)
    local player = world.player
    local px = math.floor(player.x + 0.5)
    local py = math.floor(player.y + 0.5)
    local sprite = player.sprite
    local dir = player.facing

    -- Compute animated joint positions
    local animated = {}
    local body_dy = 0
    local head_dy = 0

    -- Get walk frame offsets
    local frame_data = nil
    if player.moving and player.on_ground then
        frame_data = anim_data.walk.frames[player.walk_frame]
        if frame_data then
            body_dy = frame_data.body_dy or 0
            head_dy = frame_data.head_dy or 0
        end
    end

    -- Apply canonical + walk offsets for each joint
    for name, pos in pairs(sprite.joints) do
        local ox, oy = get_joint_offset(frame_data, name)
        animated[name] = {pos[1] + ox, pos[2] + oy}
    end

    -- Apply body bob to upper body joints
    animated.neck[2] = animated.neck[2] + body_dy
    animated.shoulder_n[2] = animated.shoulder_n[2] + body_dy
    animated.shoulder_f[2] = animated.shoulder_f[2] + body_dy
    animated.elbow_n[2] = animated.elbow_n[2] + body_dy
    animated.elbow_f[2] = animated.elbow_f[2] + body_dy
    animated.hand_n[2] = animated.hand_n[2] + body_dy
    animated.hand_f[2] = animated.hand_f[2] + body_dy
    animated.head_top[2] = animated.head_top[2] + head_dy
    -- Hips bob too so body doesn't disconnect from legs
    animated.hip_n[2] = animated.hip_n[2] + body_dy
    animated.hip_f[2] = animated.hip_f[2] + body_dy

    -- Hit animation: shoulder-anchored rotation (offsets in local space, no dir multiply)
    if player.axe_swing > 0 and player.axe_swing < 1 then
        local hit = anim_data.get_hit_offsets(player.axe_swing, sprite.arm_len)
        if hit.elbow_n then
            animated.elbow_n[1] = animated.elbow_n[1] + hit.elbow_n[1]
            animated.elbow_n[2] = animated.elbow_n[2] + hit.elbow_n[2]
        end
        if hit.hand_n then
            animated.hand_n[1] = animated.hand_n[1] + hit.hand_n[1]
            animated.hand_n[2] = animated.hand_n[2] + hit.hand_n[2]
        end
    end

    -- Idle breathing: arm bob
    if player.idle_timer > 0 and not player.moving then
        local phase = math.sin(player.idle_timer * math.pi * 0.8)
        if phase > 0.3 then
            animated.hand_n[2] = animated.hand_n[2] + 1
            animated.hand_f[2] = animated.hand_f[2] + 1
            animated.elbow_n[2] = animated.elbow_n[2] + 1
            animated.elbow_f[2] = animated.elbow_f[2] + 1
        end
    end

    -- Transform local coords to screen coords (facing flip)
    local function to_screen(lx, ly)
        if dir == 1 then
            return px + lx, py + ly
        else
            return px + 15 - lx, py + ly
        end
    end

    local colors = sprite.colors
    local limb_defs = sprite.limb_defs

    -- Draw parts in order
    for _, part_name in ipairs(sprite.draw_order) do
        if part_name == "head" then
            local block = sprite.head
            local hx = animated.head_top[1] - math.floor(block.w / 2)
            local hy = animated.head_top[2]
            for _, pixel in ipairs(block.pixels) do
                local dx = pixel[1]
                -- Idle head look: shift face pixels (non-dark)
                if pixel[3] ~= colors.dk then
                    dx = dx + (player.idle_look_dir or 0)
                end
                local sx, sy = to_screen(hx + dx, hy + pixel[2])
                set_color(pixel[3])
                draw_pixel(sx, sy)
            end

        elseif part_name == "body" then
            local block = sprite.body
            local bx = block.ox
            local by = animated.neck[2]
            for _, pixel in ipairs(block.pixels) do
                local sx, sy = to_screen(bx + pixel[1], by + pixel[2])
                set_color(pixel[3])
                draw_pixel(sx, sy)
            end

        else
            -- Draw limb: outline line + fill line (2px wide)
            local limb = limb_defs[part_name]
            if limb then
                local outline_idx = colors[limb.color]
                local fill_idx = limb.fill and colors[limb.fill] or outline_idx
                local chain = limb.chain
                local w_off = limb.width_dir * dir

                for i = 1, #chain - 1 do
                    local j1 = animated[chain[i]]
                    local j2 = animated[chain[i + 1]]
                    local sx1, sy1 = to_screen(j1[1], j1[2])
                    local sx2, sy2 = to_screen(j2[1], j2[2])
                    -- Outer edge = outline color, inner edge = fill color
                    draw_line(sx1, sy1, sx2, sy2, outline_idx)
                    draw_line(sx1 + w_off, sy1, sx2 + w_off, sy2, fill_idx)
                end

                -- Foot: 3px wide (extra outline pixel on outer edge)
                if limb.foot then
                    local foot = animated[chain[#chain]]
                    local fsx, fsy = to_screen(foot[1], foot[2])
                    set_color(outline_idx)
                    draw_pixel(fsx - w_off, fsy)
                end
            end
        end
    end

    -- Return animated joints for axe code
    local hand_sx, hand_sy = to_screen(animated.hand_n[1], animated.hand_n[2])
    return {
        joints = animated,
        hand_x = hand_sx,
        hand_y = hand_sy,
    }
end

function M.draw_axe(world, result)
    local player = world.player
    local dir = player.facing
    local swing = player.axe_swing

    local hx = result.hand_x
    local hy = result.hand_y
    local d = dir

    local axe_pixels = {}
    if swing <= 0 or swing >= 1 then
        -- Rest: axe hangs down from hand
        table.insert(axe_pixels, {hx,        hy + 1, 18})
        table.insert(axe_pixels, {hx,        hy + 2, 16})
        table.insert(axe_pixels, {hx,        hy + 3, 15})
        table.insert(axe_pixels, {hx - d,    hy + 2, 21})
        table.insert(axe_pixels, {hx - d,    hy + 3, 20})
        table.insert(axe_pixels, {hx - d,    hy + 4, 20})
        table.insert(axe_pixels, {hx - d*2,  hy + 2, 20})
        table.insert(axe_pixels, {hx - d*2,  hy + 3, 20})
        table.insert(axe_pixels, {hx - d*2,  hy + 4, 20})
        table.insert(axe_pixels, {hx - d*3,  hy + 3, 19})
        table.insert(axe_pixels, {hx - d*3,  hy + 4, 19})
        table.insert(axe_pixels, {hx - d*2,  hy + 5, 19})
        table.insert(axe_pixels, {hx - d,    hy + 5, 21})
    elseif swing < 0.3 then
        -- Windup: axe points upward
        table.insert(axe_pixels, {hx,        hy,     18})
        table.insert(axe_pixels, {hx,        hy - 1, 16})
        table.insert(axe_pixels, {hx,        hy - 2, 15})
        table.insert(axe_pixels, {hx - d,    hy - 2, 21})
        table.insert(axe_pixels, {hx - d,    hy - 3, 20})
        table.insert(axe_pixels, {hx - d,    hy - 4, 20})
        table.insert(axe_pixels, {hx - d*2,  hy - 2, 20})
        table.insert(axe_pixels, {hx - d*2,  hy - 3, 20})
        table.insert(axe_pixels, {hx - d*2,  hy - 4, 20})
        table.insert(axe_pixels, {hx - d*3,  hy - 3, 19})
        table.insert(axe_pixels, {hx - d*3,  hy - 4, 19})
        table.insert(axe_pixels, {hx - d*2,  hy - 5, 19})
        table.insert(axe_pixels, {hx - d,    hy - 5, 21})
    elseif swing < 0.6 then
        -- Strike: axe extends forward
        table.insert(axe_pixels, {hx + d*4,  hy,     18})
        table.insert(axe_pixels, {hx + d*5,  hy,     16})
        table.insert(axe_pixels, {hx + d*6,  hy - 1, 21})
        table.insert(axe_pixels, {hx + d*6,  hy,     15})
        table.insert(axe_pixels, {hx + d*6,  hy + 1, 21})
        table.insert(axe_pixels, {hx + d*7,  hy - 2, 19})
        table.insert(axe_pixels, {hx + d*7,  hy - 1, 20})
        table.insert(axe_pixels, {hx + d*7,  hy,     20})
        table.insert(axe_pixels, {hx + d*7,  hy + 1, 20})
        table.insert(axe_pixels, {hx + d*7,  hy + 2, 19})
        table.insert(axe_pixels, {hx + d*8,  hy - 1, 19})
        table.insert(axe_pixels, {hx + d*8,  hy,     19})
        table.insert(axe_pixels, {hx + d*8,  hy + 1, 19})
    else
        -- Follow-through: axe forward-down
        table.insert(axe_pixels, {hx + d,    hy + 1, 18})
        table.insert(axe_pixels, {hx + d,    hy + 2, 16})
        table.insert(axe_pixels, {hx + d,    hy + 3, 15})
        table.insert(axe_pixels, {hx + d*2,  hy + 2, 21})
        table.insert(axe_pixels, {hx + d*2,  hy + 3, 20})
        table.insert(axe_pixels, {hx + d*2,  hy + 4, 20})
        table.insert(axe_pixels, {hx + d*3,  hy + 2, 20})
        table.insert(axe_pixels, {hx + d*3,  hy + 3, 20})
        table.insert(axe_pixels, {hx + d*3,  hy + 4, 20})
        table.insert(axe_pixels, {hx + d*4,  hy + 3, 19})
        table.insert(axe_pixels, {hx + d*4,  hy + 4, 19})
        table.insert(axe_pixels, {hx + d*3,  hy + 5, 19})
        table.insert(axe_pixels, {hx + d*2,  hy + 5, 21})
    end

    for _, ap in ipairs(axe_pixels) do
        set_color(ap[3])
        draw_pixel(ap[1], ap[2])
    end
end

return M
