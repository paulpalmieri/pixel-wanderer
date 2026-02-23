-- sys/player.lua
-- Player creation, movement, gravity, collision, animation state
-- Owns: world.player.*

local C = require("core.const")
local gen_char = require("gen.character")
local gen_sound = require("gen.sound")

local M = {}

-- Check if a position collides with any standing tree trunk
-- Returns the tree and push direction if blocked, nil otherwise
function M.check_tree_collision(world, entity_x, entity_w, direction)
    for _, t in ipairs(world.trees) do
        if t.hp > 0 and not t.falling and not t.fell then
            -- Trunk collision zone: center portion of tree width
            local trunk_hw = math.max(2, math.floor(t.w * 0.15))
            local trunk_cx = t.x + t.w / 2
            local trunk_left = trunk_cx - trunk_hw
            local trunk_right = trunk_cx + trunk_hw

            local entity_left = entity_x
            local entity_right = entity_x + entity_w

            -- Check overlap
            if entity_right > trunk_left and entity_left < trunk_right then
                return t, (direction > 0) and trunk_left - entity_w or trunk_right
            end
        end
    end
    return nil
end

function M.create(world)
    -- Spawn inside the elevator door frame (centered in the door opening)
    local spawn_x = C.WALL_WIDTH + math.floor(C.ENTRANCE_DOOR_W / 2) - 8
    local entrance_ground_y = world.ground and world.ground.base_y or (C.GAME_H - 16)

    world.player = {
        x = spawn_x,
        y = entrance_ground_y - 16,
        vy = 0,
        on_ground = true,
        facing = 1,
        sprite = gen_char.generate_player(),
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
        swing_variant = 1,
        -- Resources
        wood_count = 0,
    }

    -- Set up entrance animation
    world.door_state = "closed"
    world.door_timer = 0
    world.door_open_amount = 0
    world.entrance_anim_done = false
    world.entrance_walk_target = C.WALL_WIDTH + C.ENTRANCE_DOOR_W + 20
end

function M.update(dt, world)
    local player = world.player

    -- ============================================================
    -- ENTRANCE ANIMATION (before giving player control)
    -- ============================================================
    if not world.entrance_anim_done then
        world.door_timer = world.door_timer + dt

        if world.door_state == "closed" then
            -- Brief pause, then start opening
            if world.door_timer >= 0.5 then
                world.door_state = "opening"
                world.door_timer = 0
                -- Play door opening sound effect
                local door_sfx = love.audio.newSource("assets/door_opening.mp3", "static")
                door_sfx:setVolume(0.3)
                door_sfx:play()
            end
        elseif world.door_state == "opening" then
            -- Door slides open over 0.8s
            world.door_open_amount = math.min(1.0, world.door_timer / 0.8)
            if world.door_open_amount >= 1.0 then
                world.door_state = "walk_in"
                world.door_timer = 0
            end
        elseif world.door_state == "walk_in" then
            -- Player walks right from behind door to the walk target
            player.facing = 1
            player.moving = true

            local walk_speed = C.MOVE_SPEED * 0.8
            player.x = player.x + walk_speed * dt

            -- Walk animation
            player.walk_timer = player.walk_timer + dt
            local frame_time = 0.1
            if player.walk_timer > frame_time then
                player.walk_timer = player.walk_timer - frame_time
                player.walk_frame = (player.walk_frame + 1) % 6
            end

            -- Ground snap
            local foot_x = math.floor(player.x + 8)
            local gx = math.max(0, math.min(world.ground.width - 1, foot_x))
            local ground_y = world.ground.heightmap[gx] or world.ground.base_y
            player.y = ground_y - 16
            player.on_ground = true

            if player.x >= world.entrance_walk_target then
                world.door_state = "closing"
                world.door_timer = 0
                player.moving = false
                player.walk_timer = 0
                player.walk_frame = 0
            end
        elseif world.door_state == "closing" then
            -- Door slides closed over 0.6s
            world.door_open_amount = math.max(0, 1.0 - world.door_timer / 0.6)
            if world.door_open_amount <= 0 then
                world.door_state = "done"
                world.entrance_anim_done = true
            end
        end
        return -- skip normal update during entrance animation
    end

    -- ============================================================
    -- NORMAL PLAYER UPDATE (after entrance animation)
    -- ============================================================

    -- Store previous position for trail
    player.trail_x = player.x
    player.trail_y = player.y

    -- Horizontal movement
    local moving = false
    local move_dir = 0
    if love.keyboard.isDown("a") then
        player.x = player.x - C.MOVE_SPEED * dt
        player.facing = -1
        moving = true
        move_dir = -1
    end
    if love.keyboard.isDown("d") then
        player.x = player.x + C.MOVE_SPEED * dt
        player.facing = 1
        moving = true
        move_dir = 1
    end

    -- Tree collision (push back if walking into a standing tree trunk)
    if moving then
        local _, push_x = M.check_tree_collision(world, player.x, 16, move_dir)
        if push_x then
            player.x = push_x
        end
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
                color = ({5, 16, 10})[math.random(1, 3)],
            })
        end
    end

    -- Walk animation: 6-frame cycle
    local was_moving = player.moving
    player.moving = moving
    if moving and player.on_ground then
        -- Immediate step on walk start (so you don't wait 0.3s for first sound)
        if not was_moving and player.walk_dust_cd <= 0 then
            gen_sound.play_step_sound()
            local foot_y = player.y + 16
            local count = math.random(1, 2)
            for _ = 1, count do
                local life = 0.15 + math.random() * 0.10
                local spread_x = (math.random() - 0.5) * 3
                local kick_back = -player.facing * (8 + math.random() * 14)
                local lift = -(1 + math.random() * 4)
                table.insert(world.particles, {
                    x = player.x + 8 - player.facing * (1 + math.random() * 2) + spread_x,
                    y = foot_y - math.random(0, 1),
                    vx = kick_back,
                    vy = lift,
                    life = life,
                    max_life = life,
                    color = ({5, 16, 10})[math.random(1, 3)],
                })
            end
            player.walk_dust_cd = 0.10
        end

        player.walk_timer = player.walk_timer + dt
        local frame_time = 0.1
        if player.walk_timer > frame_time then
            player.walk_timer = player.walk_timer - frame_time
            local prev_frame = player.walk_frame
            player.walk_frame = (player.walk_frame + 1) % 6

            -- Walk dust + step sound on contact frames (0 and 3)
            if (player.walk_frame == 0 or player.walk_frame == 3) and player.walk_dust_cd <= 0 then
                gen_sound.play_step_sound()
                local foot_y = player.y + 16
                -- Spawn 2-3 trailing dust particles that kick backwards
                local count = math.random(2, 3)
                for _ = 1, count do
                    local life = 0.18 + math.random() * 0.12
                    local spread_x = (math.random() - 0.5) * 3
                    local kick_back = -player.facing * (8 + math.random() * 14)
                    local lift = -(1 + math.random() * 4)
                    table.insert(world.particles, {
                        x = player.x + 8 - player.facing * (1 + math.random() * 2) + spread_x,
                        y = foot_y - math.random(0, 1),
                        vx = kick_back,
                        vy = lift,
                        life = life,
                        max_life = life,
                        color = ({5, 16, 10})[math.random(1, 3)],
                    })
                end
                player.walk_dust_cd = 0.10
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
                color = ({5, 16, 10})[math.random(1, 3)],
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
