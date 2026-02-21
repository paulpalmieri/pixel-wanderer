-- sys/combat.lua
-- Axe swing, hit detection, tree damage, particle/chunk spawning

local gen_sound = require("gen.sound")

local M = {}

function M.hit_tree(world, entity, tree)
    local tree_cx = tree.x + tree.w / 2

    -- Critical strike: 25% chance
    local is_crit = math.random() < 0.25
    local bonus = (world.upgrades and world.upgrades.axe_damage) or 0
    local damage = (is_crit and 2 or 1) + bonus
    tree.hp = math.max(0, tree.hp - damage)
    tree.shake_timer = is_crit and 0.3 or 0.15

    -- Bend: big on crit, small on normal
    if is_crit then
        local bend_strength = 2.0 + math.random() * 0.8
        tree.bend_timer = 0.9 + math.random() * 0.3
        tree.bend_dir = entity.facing * bend_strength
        tree.flash_timer = 0.15
    else
        local bend_strength = 1.2 + math.random() * 0.5
        tree.bend_timer = 0.6 + math.random() * 0.15
        tree.bend_dir = entity.facing * bend_strength
        tree.flash_timer = 0.1
    end
    gen_sound.play_chop_sound()

    -- Slash effect (position at trunk face, not bounding box edge)
    local trunk_hw = math.floor((tree.trunk_w or 4) / 2)
    local slash_x = tree_cx - entity.facing * trunk_hw
    local slash_y = entity.y + 9

    -- Floating damage number — flies out from impact
    table.insert(world.floating_texts, {
        x = slash_x,
        y = slash_y - 2,
        text = tostring(damage),
        life = is_crit and 1.0 or 0.7,
        max_life = is_crit and 1.0 or 0.7,
        is_crit = is_crit,
        vx = entity.facing * (is_crit and (40 + math.random() * 20) or (25 + math.random() * 15)),
        vy = -(is_crit and (50 + math.random() * 20) or (30 + math.random() * 15)),
        scale = is_crit and 1.5 or 1.0,
    })
    for i = -2, 2 do
        local life = 0.09 + math.random() * 0.04
        table.insert(world.particles, {
            x = slash_x + i * entity.facing * 0.5,
            y = slash_y + i,
            vx = entity.facing * (3 + math.random() * 5),
            vy = i * 4,
            life = life,
            max_life = life,
            color = ({12, 12, 11})[math.random(1, 3)], -- Impact (Sage Teal/Steel Blue)
        })
    end
    -- Sparks (more on crit)
    local spark_count = is_crit and math.random(5, 8) or math.random(3, 5)
    for _ = 1, spark_count do
        local life = 0.12 + math.random() * 0.15
        table.insert(world.particles, {
            x = slash_x + (math.random() - 0.5) * 3,
            y = slash_y + (math.random() - 0.5) * 4,
            vx = entity.facing * (30 + math.random() * 50),
            vy = (math.random() - 0.5) * 60,
            life = life,
            max_life = life,
            color = ({12, 20, 6})[math.random(1, 3)], -- Sparks (Sage Teal, Warm White, Warm Gold)
        })
    end

    -- Leaf particles — scale with tree size, more on crit
    local leaf_count = math.max(2, math.floor(tree.w * tree.h / 200))
    if is_crit then leaf_count = leaf_count + 3 end
    leaf_count = math.random(leaf_count, leaf_count + 3)
    for _ = 1, leaf_count do
        local life = 0.4 + math.random() * 0.4
        table.insert(world.particles, {
            x = tree.x + math.random(0, tree.w),
            y = tree.y + math.random(0, math.floor(tree.h * 0.6)),
            vx = entity.facing * (10 + math.random() * 20) + (math.random() - 0.5) * 30,
            vy = -math.random(15, 45),
            life = life,
            max_life = life,
            color = ({9, 7, 8, 7})[math.random(1, 4)], -- Leaves (Dark Olive, Olive Green, Forest Green)
        })
    end

    -- Wood chunk
    local dir = entity.facing * (0.6 + math.random() * 0.8)
    table.insert(world.wood_chunks, {
        x = tree.x + tree.w / 2 + (math.random() - 0.5) * 8,
        y = tree.y + tree.h * (0.3 + math.random() * 0.3),
        vx = dir * (25 + math.random() * 35),
        vy = -math.random(50, 100),
        on_ground = false,
        pickup_ready = false,
    })

    -- Tree dies — initiate fall instead of instant removal
    if tree.hp <= 0 then
        if world.upgrades and world.upgrades.battery_leech and world.battery then
            local max_batt = 10 + (world.upgrades.battery_bonus or 0)
            world.battery = math.min(world.battery + 1, max_batt)
        end
        local pre_fall = 0.15 + (tree.h / 80) * 0.4
        
        gen_sound.play_tree_break_sound(tree.h)
        tree.falling = false
        tree.pre_fall_timer = pre_fall
        tree.fall_dir = entity.facing
        tree.fall_vel = 0.0
        tree.fall_angle = 0
        tree.fell = false
        tree.fall_timer = 0

        -- Crack/splinter particles at cut point
        local cut_x = tree.x + tree.w / 2
        local cut_y = tree.y + tree.h - tree.stump_h
        for _ = 1, math.random(4, 7) do
            local life = 0.3 + math.random() * 0.3
            table.insert(world.particles, {
                x = cut_x + (math.random() - 0.5) * 4,
                y = cut_y + (math.random() - 0.5) * 2,
                vx = entity.facing * (10 + math.random() * 20),
                vy = -math.random(10, 30),
                life = life,
                max_life = life,
                color = ({2, 5, 6})[math.random(1, 3)], -- Wood splinters (Dark Brown, Burnt Orange, Warm Gold)
            })
        end

        -- Leaves shaking off at start
        local leaf_burst = math.max(4, math.floor(tree.w * tree.h / 200))
        for _ = 1, math.random(leaf_burst, leaf_burst + 3) do
            local life = 0.4 + math.random() * 0.4
            table.insert(world.particles, {
                x = tree.x + math.random(0, tree.w),
                y = tree.y + math.random(0, math.floor(tree.h * 0.6)),
                vx = entity.facing * (5 + math.random() * 15) + (math.random() - 0.5) * 20,
                vy = -math.random(10, 40),
                life = life,
                max_life = life,
                color = ({9, 7, 8, 7})[math.random(1, 4)], -- Leaves (Dark Olive, Olive Green, Forest Green)
            })
        end
    end
end

function M.update(dt, world)
    -- Skip combat updates when not actively playing
    if world.game_state ~= "playing" then return end

    local player = world.player

    -- Axe swing timer
    local swing_duration = 0.38
    if world.upgrades and world.upgrades.swing_speed then
        swing_duration = math.max(0.15, swing_duration - 0.08 * world.upgrades.swing_speed)
    end
    
    if player.axe_swing > 0 then
        player.axe_swing = player.axe_swing + dt / swing_duration
        if player.axe_swing >= 1 then
            player.axe_swing = 0
        end
    end
    if player.axe_cooldown > 0 then
        player.axe_cooldown = player.axe_cooldown - dt
    end

    -- Hit detection (swing progress 0.30-0.45 = strike phase)
    if player.axe_swing >= 0.30 and player.axe_swing <= 0.45 and not player.axe_has_hit then
        for ti = #world.trees, 1, -1 do
            local tree = world.trees[ti]
            if tree.hp > 0 then
                local tree_cx = tree.x + tree.w / 2
                local player_cx = player.x + 8
                local dist = math.abs(tree_cx - player_cx)
                local facing_tree = (player.facing == 1 and tree_cx >= player_cx) or
                                    (player.facing == -1 and tree_cx <= player_cx)
                if dist < 14 and facing_tree then
                    player.axe_has_hit = true
                    M.hit_tree(world, player, tree)

                    break  -- one tree per swing
                end
            end
        end
    end

    -- Tree timers + fall physics + removal
    for _, tree in ipairs(world.trees) do
        if tree.shake_timer > 0 then tree.shake_timer = tree.shake_timer - dt end
        if tree.flash_timer > 0 then tree.flash_timer = tree.flash_timer - dt end
        if tree.bend_timer > 0 then tree.bend_timer = tree.bend_timer - dt end

        -- Pre-fall hesitation
        if tree.hp <= 0 and not tree.falling then
            if tree.pre_fall_timer then
                tree.pre_fall_timer = tree.pre_fall_timer - dt
                if tree.pre_fall_timer <= 0 then
                    tree.falling = true
                end
            end
        end

        -- Fall physics
        if tree.falling and not tree.fell then
            local gravity_factor = 100.0 -- significantly reduced gravity to let break sound play through
            local angular_accel = (gravity_factor * math.sin(math.max(0.1, tree.fall_angle))) / tree.h
            
            if tree.fall_angle < 0.05 then
                angular_accel = angular_accel + 10.0 / (tree.h * 0.5) -- slower initial tipping push
            end

            tree.fall_vel = tree.fall_vel + angular_accel * dt
            tree.fall_angle = tree.fall_angle + tree.fall_vel * dt

            -- Occasional leaf particle during fall
            if math.random() < 8 * dt then
                local life = 0.5 + math.random() * 0.4
                table.insert(world.particles, {
                    x = tree.x + math.random(0, tree.w),
                    y = tree.y + math.random(0, math.floor(tree.h * 0.5)),
                    vx = tree.fall_dir * (5 + math.random() * 10) + (math.random() - 0.5) * 15,
                    vy = -math.random(5, 20),
                    life = life,
                    max_life = life,
                    color = ({9, 7, 8, 7})[math.random(1, 4)], -- Leaves (Dark Olive, Olive Green, Forest Green)
                })
            end

            -- Impact when reaching 90 degrees
            if tree.fall_angle >= math.pi / 2 then
                if not tree.bounced then
                    -- First heavy impact
                    tree.bounced = true
                    tree.fall_angle = math.pi / 2
                    -- Bounce back based on fall velocity, capped
                    tree.fall_vel = -math.min(tree.fall_vel * 0.18, 1.0)

                    gen_sound.play_tree_fall_sound(tree.h)

                    -- Wood chunks burst from impact zone (scattered along fallen length)
                    local base_y = tree.y + tree.h - tree.stump_h
                    local impact_x = tree.x + tree.w / 2 + tree.fall_dir * (tree.h - tree.stump_h)
                    local death_chunks = math.max(3, math.floor(tree.w * tree.h / 300))
                    for _ = 1, math.random(death_chunks, death_chunks + 2) do
                        local spread = math.random() * (tree.h - tree.stump_h)
                        local cx = tree.x + tree.w / 2 + tree.fall_dir * spread
                        table.insert(world.wood_chunks, {
                            x = cx + (math.random() - 0.5) * 4,
                            y = base_y - math.random(0, 4),
                            vx = tree.fall_dir * (10 + math.random() * 40) + (math.random() - 0.5) * 30,
                            vy = -math.random(40, 100),
                            on_ground = false,
                            pickup_ready = false,
                        })
                    end

                    -- Heavy dust particles along the trunk
                    local dust_count = math.max(12, math.floor(tree.h / 2))
                    for _ = 1, dust_count do
                        local life = 0.6 + math.random() * 0.8
                        local spread = math.random() * (tree.h - tree.stump_h)
                        local cx = tree.x + tree.w / 2 + tree.fall_dir * spread
                        
                        table.insert(world.particles, {
                            x = cx + (math.random() - 0.5) * 6,
                            y = base_y + (math.random() - 0.5) * 4,
                            vx = (math.random() - 0.5) * 20 + tree.fall_dir * 5,
                            vy = -math.random(5, 15), -- Rises slowly
                            life = life,
                            max_life = life,
                            color = ({5, 2, 3, 18})[math.random(1, 4)], -- dirt and bark colors
                        })
                    end

                    -- Big, thick dust poof at the exact impact point
                    for _ = 1, math.max(8, math.floor(tree.h / 3)) do
                        local life = 0.8 + math.random() * 0.5
                        table.insert(world.particles, {
                            x = impact_x + (math.random() - 0.5) * 15,
                            y = base_y,
                            vx = (math.random() - 0.5) * 30 + tree.fall_dir * 10,
                            vy = -math.random(10, 20),
                            life = life,
                            max_life = life,
                            color = ({5, 2, 3, 18})[math.random(1, 4)],
                        })
                    end

                    -- Leaf explosion
                    local leaf_burst = math.max(6, math.floor(tree.w * tree.h / 150))
                    for _ = 1, math.random(leaf_burst, leaf_burst + 4) do
                        local life = 0.3 + math.random() * 0.4
                        local spread = math.random() * (tree.h - tree.stump_h)
                        table.insert(world.particles, {
                            x = tree.x + tree.w / 2 + tree.fall_dir * spread,
                            y = base_y - math.random(0, 6),
                            vx = (math.random() - 0.5) * 50,
                            vy = -math.random(20, 60),
                            life = life,
                            max_life = life,
                            color = ({7, 8, 9, 2})[math.random(1, 4)],
                        })
                    end
                else
                    -- It already bounced, now it's settling
                    tree.fall_angle = math.pi / 2
                    if tree.fall_vel > 0.5 then
                        -- Bounce again slightly if still moving fast enough
                        tree.fall_vel = -tree.fall_vel * 0.4
                        
                        -- Optional: tiny dust puff on second bounce
                        local base_y = tree.y + tree.h - tree.stump_h
                        local impact_x = tree.x + tree.w / 2 + tree.fall_dir * (tree.h - tree.stump_h)
                        for _ = 1, 3 do
                            table.insert(world.particles, {
                                x = impact_x + (math.random() - 0.5) * 8,
                                y = base_y,
                                vx = (math.random() - 0.5) * 15,
                                vy = -math.random(5, 15),
                                life = 0.3 + math.random() * 0.2,
                                max_life = 0.5,
                                color = ({5, 2, 3})[math.random(1, 3)],
                            })
                        end
                    else
                        -- Settle completely
                        tree.fall_vel = 0
                        tree.fell = true
                        tree.fall_timer = 0.8
                    end
                end
            end
        end

        -- Post-impact fade timer
        if tree.fell then
            tree.fall_timer = tree.fall_timer - dt
        end
    end
    for i = #world.trees, 1, -1 do
        if world.trees[i].fell and world.trees[i].fall_timer <= 0 then
            table.remove(world.trees, i)
        end
    end
end

return M
