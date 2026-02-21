-- sys/player.lua
-- Player creation, movement, gravity, collision, animation state
-- Owns: world.player.*

local C = require("core.const")
local gen_char = require("gen.character")

local M = {}

function M.create(world)
    world.player = {
        x = 256 - 8,
        y = 0,
        vy = 0,
        on_ground = false,
        facing = 1,
        sprite = gen_char.generate(),
        -- Walk animation (6-frame cycle)
        walk_timer = 0,
        walk_frame = 0,
        moving = false,
        -- Idle animation
        idle_timer = 0,
        idle_look_dir = 0,
        idle_look_timer = 0,
        idle_look_next = 2 + math.random() * 2,
        -- Jump animation
        squash_timer = 0,           -- landing bounce remaining time
        squash_duration = 0.25,     -- total bounce duration
        crouch_timer = 0,           -- pre-jump crouch
        -- Dust
        dust_timer = 0,
        walk_dust_cd = 0,           -- cooldown between walk dust puffs
        -- Trail
        trail_x = nil,
        trail_y = nil,
        -- Axe
        axe_swing = 0,
        axe_cooldown = 0,
        axe_has_hit = false,
        -- Resources
        wood_count = 0,
    }

    -- Place on ground
    if world.ground then
        local gh = world.ground.heightmap[math.floor(world.player.x)] or world.ground.base_y
        world.player.y = gh - 16
    end
end

function M.update(dt, world)
    local player = world.player

    -- Store previous position for trail
    player.trail_x = player.x
    player.trail_y = player.y

    -- Horizontal movement
    local moving = false
    if love.keyboard.isDown("a") then
        player.x = player.x - C.MOVE_SPEED * dt
        player.facing = -1
        moving = true
    end
    if love.keyboard.isDown("d") then
        player.x = player.x + C.MOVE_SPEED * dt
        player.facing = 1
        moving = true
    end

    -- Jump (continuous check for responsiveness)
    if love.keyboard.isDown("space") and player.on_ground then
        player.vy = C.JUMP_VEL
        player.on_ground = false
        -- Jump dust puff
        local foot_y = player.y + 16
        for _ = 1, math.random(2, 3) do
            local life = 0.15 + math.random() * 0.1
            table.insert(world.particles, {
                x = player.x + 8 + (math.random() - 0.5) * 4,
                y = foot_y - 1,
                vx = (math.random() - 0.5) * 20,
                vy = -(5 + math.random() * 10),
                life = life,
                max_life = life,
                color = ({33, 34, 32})[math.random(1, 3)],
            })
        end
    end

    -- Walk animation: 6-frame cycle
    player.moving = moving
    if moving and player.on_ground then
        player.walk_timer = player.walk_timer + dt
        local frame_time = 0.1
        if player.walk_timer > frame_time then
            player.walk_timer = player.walk_timer - frame_time
            local prev_frame = player.walk_frame
            player.walk_frame = (player.walk_frame + 1) % 6

            -- Walk dust on contact frames (0 and 3)
            if (player.walk_frame == 0 or player.walk_frame == 3) and player.walk_dust_cd <= 0 then
                local foot_y = player.y + 16
                local life = 0.12 + math.random() * 0.08
                table.insert(world.particles, {
                    x = player.x + 8 + player.facing * 2 + (math.random() - 0.5) * 2,
                    y = foot_y - 1,
                    vx = -player.facing * (5 + math.random() * 8),
                    vy = -(3 + math.random() * 5),
                    life = life,
                    max_life = life,
                    color = ({33, 34, 32})[math.random(1, 3)],
                })
                player.walk_dust_cd = 0.15
            end
        end
        player.idle_timer = 0
    else
        player.walk_timer = 0
        player.walk_frame = 0
        if player.on_ground then
            player.idle_timer = player.idle_timer + dt
        else
            player.idle_timer = 0
        end
    end

    -- Walk dust cooldown
    if player.walk_dust_cd > 0 then
        player.walk_dust_cd = player.walk_dust_cd - dt
    end

    -- Squash timer (landing)
    if player.squash_timer > 0 then
        player.squash_timer = player.squash_timer - dt
    end

    -- Idle head look
    if player.idle_timer > 2 then
        player.idle_look_timer = player.idle_look_timer + dt
        if player.idle_look_timer >= player.idle_look_next then
            player.idle_look_timer = 0
            player.idle_look_next = 1.5 + math.random() * 2
            local dirs = {-1, 0, 0, 1}
            player.idle_look_dir = dirs[math.random(1, #dirs)]
        end
    else
        player.idle_look_dir = 0
        player.idle_look_timer = 0
    end

    -- Gravity
    player.vy = player.vy + C.GRAVITY * dt
    player.y = player.y + player.vy * dt

    -- Ground collision
    local foot_x = math.floor(player.x + 8)
    local gx = math.max(0, math.min(world.ground.width - 1, foot_x))
    local ground_y = world.ground.heightmap[gx] or world.ground.base_y

    local was_airborne = not player.on_ground
    if player.y + 16 >= ground_y then
        player.y = ground_y - 16
        player.vy = 0
        player.on_ground = true
    else
        player.on_ground = false
    end

    -- Landing effects
    if player.on_ground and was_airborne then
        -- Squash timer
        player.squash_timer = player.squash_duration

        -- Landing dust burst
        for _ = 1, math.random(3, 5) do
            local life = 0.2 + math.random() * 0.2
            table.insert(world.particles, {
                x = player.x + 8 + (math.random() - 0.5) * 8,
                y = ground_y - 1,
                vx = (math.random() - 0.5) * 30,
                vy = -(8 + math.random() * 15),
                life = life,
                max_life = life,
                color = ({33, 34, 32})[math.random(1, 3)],
            })
        end
    end

    -- Wall collision
    if player.x < C.WALL_WIDTH then
        player.x = C.WALL_WIDTH
    end
    if player.x > world.ground.width - C.WALL_WIDTH - 16 then
        player.x = world.ground.width - C.WALL_WIDTH - 16
    end

    -- Clear trail when stopped
    if not moving then
        player.trail_x = nil
        player.trail_y = nil
    end
end

return M
