-- sys/robot.lua
-- Robot AI and physics system
-- Seeks trees, chops them, and seeks wood to auto-gather

local C = require("core.const")
local combat = require("sys.combat")
local gen_sound = require("gen.sound")
local sys_player = require("sys.player")

local M = {}

-- Distance helper
local function dist(x1, y1, x2, y2)
    return math.sqrt((x2-x1)^2 + (y2-y1)^2)
end

-- Find nearest standing tree that is not targeted by another robot
local function find_nearest_tree(world, robot)
    local best_tree = nil
    local best_dist = math.huge
    local rx = robot.x
    
    for i, t in ipairs(world.trees) do
        if t.hp > 0 then
            local tx = t.w * 8
            if t.grid.length then 
               tx = #t.grid[1] * C.PIXEL -- rough approximation
            end
            -- use the tree's index combined with typical width to find its world x
            -- actually trees in this game are spaced. Let's look at sys_combat to see how it hits trees
            -- trees spacing: gen/tree places them. Let's rough it as we'll find their real X shortly.
            local real_tx = t.x or (i * 64) -- Need to check how trees store X. Wait, let's just use t.x
            
            -- let's use the center of the tree
            if t.x then
                -- Check if this tree is already targeted by another robot
                local targeted = false
                for _, r in ipairs(world.robots) do
                    if r ~= robot and r.target_tree == t then
                        targeted = true
                        break
                    end
                end
                
                if not targeted then
                    local d = math.abs(t.x + t.w / 2 - rx)
                    if d < best_dist then
                        best_dist = d
                        best_tree = t
                    end
                end
            end
        end
    end
    return best_tree
end

function M.update(dt, world)
    -- handle spawner door logic
    if world.entrance_anim_done then
        if not world.robot_queue then world.robot_queue = {} end
        
        if world.door_state == "done" then
            if #world.robot_queue > 0 then
                world.door_state = "robot_opening"
                world.door_timer = 0
                world.spawning_robot = table.remove(world.robot_queue, 1)
                
                local door_sfx = love.audio.newSource("assets/door_opening.mp3", "static")
                door_sfx:setVolume(0.3)
                door_sfx:play()
            end
        elseif world.door_state == "robot_opening" then
            world.door_timer = world.door_timer + dt
            world.door_open_amount = math.min(1.0, world.door_timer / 0.8)
            if world.door_open_amount >= 1.0 then
                world.door_state = "robot_walk_in"
                world.door_timer = 0
                local r = world.spawning_robot
                r.state = "ENTRANCE_WALK"
                r.facing = 1
                r.moving = true
                table.insert(world.robots, r)
            end
        elseif world.door_state == "robot_walk_in" then
            if world.spawning_robot.state ~= "ENTRANCE_WALK" then
                world.door_state = "robot_closing"
                world.door_timer = 0
            end
        elseif world.door_state == "robot_closing" then
            world.door_timer = world.door_timer + dt
            world.door_open_amount = math.max(0, 1.0 - world.door_timer / 0.6)
            if world.door_open_amount <= 0 then
                world.door_state = "done"
            end
        end
    end

    for _, robot in ipairs(world.robots) do
        local moving = false
        
        -- State Machine Transitions
        if robot.state == "ENTRANCE_WALK" then
            moving = true
            local walk_speed = C.MOVE_SPEED * 0.8
            robot.x = robot.x + walk_speed * dt
            if robot.x >= C.WALL_WIDTH + C.ENTRANCE_DOOR_W + 20 then
                robot.state = "IDLE"
                robot.timer = 0.5
                moving = false
            end
        elseif robot.state == "IDLE" then
            robot.timer = robot.timer - dt
            if robot.timer <= 0 then
                robot.target_tree = find_nearest_tree(world, robot)
                if robot.target_tree then
                    robot.state = "SEEK_TREE"
                else
                    robot.timer = 1.0 + math.random() -- wait before looking again
                end
            end
        elseif robot.state == "SEEK_TREE" then
            if not robot.target_tree or robot.target_tree.hp <= 0 then
                robot.state = "IDLE"
                robot.target_tree = nil
                robot.timer = 0.5
            else
                local tree_cx = robot.target_tree.x + robot.target_tree.w / 2
                local robot_cx = robot.x + 8
                local dist = math.abs(tree_cx - robot_cx)
                
                if dist > 12 then
                    robot.facing = (tree_cx > robot_cx) and 1 or -1
                    local new_x = robot.x + robot.facing * C.MOVE_SPEED * dt
                    -- Check tree collision before applying movement
                    local _, push_x = sys_player.check_tree_collision(world, new_x, 16, robot.facing)
                    if push_x then
                        robot.x = push_x
                        -- If blocked by a tree that isn't our target, switch to chop it
                        local blocking_tree, _ = sys_player.check_tree_collision(world, new_x, 16, robot.facing)
                        if blocking_tree and blocking_tree ~= robot.target_tree then
                            robot.target_tree = blocking_tree
                            robot.state = "CHOP"
                            robot.timer = 0.2
                        end
                    else
                        robot.x = new_x
                    end
                    moving = true
                else
                    robot.state = "CHOP"
                    robot.timer = 0.2 -- short pause before swing
                end
            end
        elseif robot.state == "CHOP" then
            if not robot.target_tree or robot.target_tree.hp <= 0 then
                robot.state = "IDLE"
                robot.target_tree = nil
                robot.timer = 0.5
            else
                local tx = robot.target_tree.x + robot.target_tree.w / 2
                local dx = tx - robot.x
                robot.facing = dx > 0 and 1 or -1
                
                robot.timer = robot.timer - dt
                if robot.timer <= 0 and robot.axe_cooldown <= 0 then
                    -- SWING!
                    robot.axe_swing = 0.001
                    robot.axe_has_hit = false
                    local cooldown = 0.40
                    if world.upgrades and world.upgrades.swing_speed then
                        cooldown = math.max(0.18, cooldown - 0.08 * world.upgrades.swing_speed)
                    end
                    robot.axe_cooldown = cooldown
                    robot.timer = cooldown + 0.6 -- Time between chops
                end
            end
        end

        -- Handle Axe Swing Animation and Hit Detection
        if robot.axe_cooldown > 0 then
            robot.axe_cooldown = robot.axe_cooldown - dt
        end

        if robot.axe_swing > 0 then
            local swing_speed = 4.0
            if world.upgrades and world.upgrades.swing_speed then
                local duration = math.max(0.15, 0.38 - 0.08 * world.upgrades.swing_speed)
                swing_speed = 1.0 / duration
            end
            robot.axe_swing = robot.axe_swing + dt * swing_speed
            
            -- The hit happens exactly when swing crosses 0.5 (peak of strike)
            if robot.axe_swing >= 0.5 and not robot.axe_has_hit then
                robot.axe_has_hit = true
                
                -- Detect hit on tree
                local reach = 22
                local hit_x = robot.x + robot.facing * reach
                local hit_y = robot.y + 8 
                
                
                for _, t in ipairs(world.trees) do
                    if t.hp > 0 and t.x then
                        local tree_center_x = t.x + t.w / 2
                        local robot_cx = robot.x + 8
                        local dist_x = math.abs(robot_cx - tree_center_x)
                        
                        -- Base check if within distance
                        if dist_x < 16 then
                            combat.hit_tree(world, robot, t)
                            break
                        end
                    end
                end
            end
            
            if robot.axe_swing >= 1.0 then
                robot.axe_swing = 0
            end
        end

        -- Walk animation
        robot.moving = moving
        if moving then
            robot.walk_timer = robot.walk_timer + dt
            local frame_time = 0.1
            if robot.walk_timer > frame_time then
                robot.walk_timer = robot.walk_timer - frame_time
                robot.walk_frame = (robot.walk_frame + 1) % 6

                if (robot.walk_frame == 0 or robot.walk_frame == 3) and robot.walk_dust_cd <= 0 then
                    gen_sound.play_step_sound()
                    local foot_y = robot.y + 16
                    -- Spawn 2-3 trailing dust particles that kick backwards
                    local count = math.random(2, 3)
                    for _ = 1, count do
                        local life = 0.18 + math.random() * 0.12
                        local spread_x = (math.random() - 0.5) * 3
                        local kick_back = -robot.facing * (8 + math.random() * 14)
                        local lift = -(1 + math.random() * 4)
                        table.insert(world.particles, {
                            x = robot.x + 8 - robot.facing * (1 + math.random() * 2) + spread_x,
                            y = foot_y - math.random(0, 1),
                            vx = kick_back,
                            vy = lift,
                            life = life,
                            max_life = life,
                            color = ({5, 16, 10})[math.random(1, 3)],
                        })
                    end
                    robot.walk_dust_cd = 0.15
                end
            end
            robot.idle_timer = 0
        else
            robot.walk_timer = 0
            robot.walk_frame = 0
            robot.idle_timer = robot.idle_timer + dt
        end

        if robot.walk_dust_cd > 0 then
            robot.walk_dust_cd = robot.walk_dust_cd - dt
        end

        -- Idle look
        if robot.idle_timer > 2 then
            robot.idle_look_timer = robot.idle_look_timer + dt
            if robot.idle_look_timer >= robot.idle_look_next then
                robot.idle_look_timer = 0
                robot.idle_look_next = 1.5 + math.random() * 2
                local dirs = {-1, 0, 0, 1}
                robot.idle_look_dir = dirs[math.random(1, #dirs)]
            end
        else
            robot.idle_look_dir = 0
            robot.idle_look_timer = 0
        end

        -- Gravity and ground collision
        robot.vy = robot.vy + C.GRAVITY * dt
        robot.y = robot.y + robot.vy * dt

        local foot_x = math.floor(robot.x + 8)
        local gx = math.max(0, math.min(world.ground.width - 1, foot_x))
        local ground_y = world.ground.heightmap[gx] or world.ground.base_y

        if robot.y + 16 >= ground_y then
            robot.y = ground_y - 16
            robot.vy = 0
            robot.on_ground = true
        else
            robot.on_ground = false
        end
        
        -- Pick up wood chunks nearby (auto-gather)
        for i = #world.wood_chunks, 1, -1 do
            local wc = world.wood_chunks[i]
            local dx = (robot.x + 8) - wc.x
            local dy = (robot.y + 8) - wc.y
            if dx*dx + dy*dy < 400 then -- within 20px radius
                wc.x = robot.x + 8
                wc.y = robot.y + 8
                -- We let sys_physics handle the actual collection if it touches the player? 
                -- Wait, if it's the robot picking it up, we should redirect it to the player's resource accumulation.
                -- For simplicity, since robot gathers for base/player, we just consume it and add to wood.
                table.remove(world.wood_chunks, i)
                world.player.wood_count = world.player.wood_count + 1
            end
        end
    end
end

return M
