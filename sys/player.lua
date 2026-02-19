-- sys/player.lua
-- Player creation, movement, gravity, collision, walk animation

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
        walk_timer = 0,
        walk_frame = 0,
        idle_timer = 0,
        dust_timer = 0,
        moving = false,
        axe_swing = 0,
        axe_cooldown = 0,
        axe_has_hit = false,
        wood_count = 0,
        idle_look_dir = 0,
        idle_look_timer = 0,
        idle_look_next = 2 + math.random() * 2,
    }

    -- Place on ground
    if world.ground then
        local gh = world.ground.heightmap[math.floor(world.player.x)] or world.ground.base_y
        world.player.y = gh - 16
    end
end

function M.update(dt, world)
    local player = world.player

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
    end

    -- Walk animation: 4-frame cycle
    player.moving = moving
    if moving and player.on_ground then
        player.walk_timer = player.walk_timer + dt
        if player.walk_timer > 0.12 then
            player.walk_timer = player.walk_timer - 0.12
            player.walk_frame = (player.walk_frame + 1) % 6
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

    -- Landing dust burst
    if player.on_ground and was_airborne then
        for _ = 1, math.random(2, 3) do
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
end

return M
