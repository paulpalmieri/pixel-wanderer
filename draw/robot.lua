-- draw/robot.lua
-- Renders robot NPCs and their axes

local palette = require("core.palette")
local anim = require("gen.anim")

local set_color = palette.set_color
local draw_pixel = palette.draw_pixel

local M = {}

local function get_robot_offsets(robot)
    local swing = robot.axe_swing

    if swing > 0 and swing < 1 then
        return anim.get_swing_offsets(swing, robot.facing)
    end

    if not robot.on_ground and robot.vy then
        if robot.vy < -20 then
            return anim.get_jump_offsets("rising")
        else
            return anim.get_jump_offsets("falling")
        end
    end

    if robot.squash_timer and robot.squash_timer > 0 then
        local progress = 1 - (robot.squash_timer / robot.squash_duration)
        return anim.get_land_offsets(progress)
    end

    if robot.moving then
        local walk = anim.walk
        local frame_idx = robot.walk_frame % walk.num_frames
        return walk.frames[frame_idx] or {}
    end

    return anim.get_idle_offsets(robot.idle_timer or 0)
end

local function part_offset(offsets, part_name)
    local o = offsets[part_name]
    if o then return o[1], o[2] end
    return 0, 0
end

local function draw_single_robot(robot, world)
    local sprite = robot.sprite
    local px = math.floor(robot.x + 0.5)
    local py = math.floor(robot.y + 0.5)
    local facing = robot.facing
    local body_w = sprite.body_w

    local entrance_clip = (robot.state == "ENTRANCE_WALK")
    if entrance_clip then
        local cam_ix = math.floor(world.camera_x + 0.5)
        local cam_iy = math.floor(world.camera_y + 0.5)
        local C = require("core.const")
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

    local body_offset_x = math.floor((16 - body_w) / 2)
    local base_x = px + body_offset_x
    local base_y = py + (16 - sprite.total_h)

    local offsets = get_robot_offsets(robot)

    for _, part_name in ipairs(sprite.draw_order) do
        local part = sprite[part_name]
        if part then
            local odx, ody = part_offset(offsets, part_name)
            local ax = part.anchor_x
            
            if facing == 1 then
                ax = body_w - part.anchor_x - part.w
            end

            local custom_arm = nil
            if part_name == "near_arm" and robot.axe_swing > 0 and robot.axe_swing < 1 then
                custom_arm = anim.get_swing_arm_shape(robot.axe_swing)
            end

            if custom_arm then
                for _, p in ipairs(custom_arm) do
                    local pdx = p.dx * facing
                    local final_x = base_x + ax + pdx + odx * facing
                    local final_y = base_y + part.anchor_y + p.dy + ody

                    set_color(sprite.colors.body_hi)
                    draw_pixel(final_x, final_y)
                end
            else
                for _, p in ipairs(part.pixels) do
                    local pdx = p.dx
                    if facing == 1 then
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

    -- Axe anchor calc
    local near_arm = sprite.near_arm
    local arm_odx, arm_ody = part_offset(offsets, "near_arm")
    local arm_ax = near_arm.anchor_x
    if facing == 1 then arm_ax = body_w - near_arm.anchor_x - near_arm.w end

    local hand_dx = 0
    local hand_dy = near_arm.h
    if robot.axe_swing > 0 and robot.axe_swing < 1 then
        local custom_arm = anim.get_swing_arm_shape(robot.axe_swing)
        if custom_arm then
            local last_p = custom_arm[#custom_arm]
            hand_dx = last_p.dx
            hand_dy = last_p.dy + 1
        end
    end

    local axe_x = base_x + arm_ax + (arm_odx + hand_dx) * facing
    local axe_y = base_y + near_arm.anchor_y + arm_ody + hand_dy

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

local function draw_robot_axe(robot, result, world)
    local d = robot.facing
    local swing = robot.axe_swing
    local hx = result.hand_x
    local hy = result.hand_y

    local entrance_clip = (robot.state == "ENTRANCE_WALK")
    if entrance_clip then
        local cam_ix = math.floor(world.camera_x + 0.5)
        local cam_iy = math.floor(world.camera_y + 0.5)
        local C = require("core.const")
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

    -- Using slightly different colors from player axe to distinguish or reuse
    local HANDLE_DARK = 15
    local HANDLE_LIGHT = 16
    local HANDLE_HI = 18
    local BLADE_INNER = 20
    local BLADE_OUTER = 19
    local BLADE_EDGE = 21

    local axe_pixels = {}
    
    if swing <= 0.0 then
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

    elseif swing <= 0.25 then
        table.insert(axe_pixels, {hx,       hy,     HANDLE_DARK})
        table.insert(axe_pixels, {hx - d,   hy - 1, HANDLE_LIGHT})
        table.insert(axe_pixels, {hx - d*2, hy - 2, HANDLE_LIGHT})
        table.insert(axe_pixels, {hx - d*3, hy - 3, HANDLE_LIGHT})
        table.insert(axe_pixels, {hx - d*4, hy - 4, HANDLE_HI})
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
        table.insert(axe_pixels, {hx,       hy,     HANDLE_DARK})
        table.insert(axe_pixels, {hx,       hy - 1, HANDLE_LIGHT})
        table.insert(axe_pixels, {hx,       hy - 2, HANDLE_LIGHT})
        table.insert(axe_pixels, {hx,       hy - 3, HANDLE_LIGHT})
        table.insert(axe_pixels, {hx,       hy - 4, HANDLE_HI})
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
        table.insert(axe_pixels, {hx,       hy,     HANDLE_DARK})
        table.insert(axe_pixels, {hx + d,   hy + 1, HANDLE_LIGHT})
        table.insert(axe_pixels, {hx + d*2, hy + 2, HANDLE_LIGHT})
        table.insert(axe_pixels, {hx + d*3, hy + 3, HANDLE_LIGHT})
        table.insert(axe_pixels, {hx + d*4, hy + 4, HANDLE_HI})
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
        table.insert(axe_pixels, {hx,       hy,     HANDLE_DARK})
        table.insert(axe_pixels, {hx,       hy + 1, HANDLE_LIGHT})
        table.insert(axe_pixels, {hx,       hy + 2, HANDLE_LIGHT})
        table.insert(axe_pixels, {hx + d,   hy + 3, HANDLE_LIGHT})
        table.insert(axe_pixels, {hx + d,   hy + 4, HANDLE_HI})
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

    for _, ap in ipairs(axe_pixels) do
        set_color(ap[3])
        draw_pixel(ap[1], ap[2])
    end

    if entrance_clip then
        love.graphics.setScissor()
    end
end

function M.draw_robots(world)
    for _, robot in ipairs(world.robots) do
        local result = draw_single_robot(robot, world)
        draw_robot_axe(robot, result, world)
    end
end

return M
