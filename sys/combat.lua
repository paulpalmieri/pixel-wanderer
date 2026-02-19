-- sys/combat.lua
-- Axe swing, hit detection, tree damage, particle/chunk spawning

local gen_sound = require("gen.sound")

local M = {}

function M.update(dt, world)
    local player = world.player

    -- Axe swing timer
    if player.axe_swing > 0 then
        player.axe_swing = player.axe_swing + dt / 0.25
        if player.axe_swing >= 1 then
            player.axe_swing = 0
        end
    end
    if player.axe_cooldown > 0 then
        player.axe_cooldown = player.axe_cooldown - dt
    end

    -- Hit detection (swing progress 0.3-0.6)
    if player.axe_swing >= 0.3 and player.axe_swing <= 0.6 and not player.axe_has_hit then
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

                    -- Critical strike: 25% chance
                    local is_crit = math.random() < 0.25
                    local damage = is_crit and 2 or 1
                    tree.hp = math.max(0, tree.hp - damage)
                    tree.shake_timer = is_crit and 0.3 or 0.15

                    -- Bend: big on crit, small on normal
                    if is_crit then
                        local bend_strength = 1.4 + math.random() * 0.8
                        tree.bend_timer = 0.9 + math.random() * 0.3
                        tree.bend_dir = player.facing * bend_strength
                        tree.flash_timer = 0.15
                    else
                        local bend_strength = 0.6 + math.random() * 0.4
                        tree.bend_timer = 0.5 + math.random() * 0.15
                        tree.bend_dir = player.facing * bend_strength
                        tree.flash_timer = 0
                    end
                    gen_sound.play_chop_sound()

                    -- Slash effect (position at trunk face, not bounding box edge)
                    local trunk_hw = math.floor((tree.trunk_w or 4) / 2)
                    local slash_x = tree_cx - player.facing * trunk_hw
                    local slash_y = player.y + 9

                    -- Floating damage number — flies out from impact
                    table.insert(world.floating_texts, {
                        x = slash_x,
                        y = slash_y - 2,
                        text = tostring(damage),
                        life = is_crit and 1.0 or 0.7,
                        max_life = is_crit and 1.0 or 0.7,
                        is_crit = is_crit,
                        vx = player.facing * (is_crit and (40 + math.random() * 20) or (25 + math.random() * 15)),
                        vy = -(is_crit and (50 + math.random() * 20) or (30 + math.random() * 15)),
                        scale = is_crit and 1.5 or 1.0,
                    })
                    for i = -2, 2 do
                        local life = 0.09 + math.random() * 0.04
                        table.insert(world.particles, {
                            x = slash_x + i * player.facing * 0.5,
                            y = slash_y + i,
                            vx = player.facing * (3 + math.random() * 5),
                            vy = i * 4,
                            life = life,
                            max_life = life,
                            color = ({19, 19, 14})[math.random(1, 3)],
                        })
                    end
                    -- Sparks (more on crit)
                    local spark_count = is_crit and math.random(5, 8) or math.random(3, 5)
                    for _ = 1, spark_count do
                        local life = 0.12 + math.random() * 0.15
                        table.insert(world.particles, {
                            x = slash_x + (math.random() - 0.5) * 3,
                            y = slash_y + (math.random() - 0.5) * 4,
                            vx = player.facing * (30 + math.random() * 50),
                            vy = (math.random() - 0.5) * 60,
                            life = life,
                            max_life = life,
                            color = ({19, 14, 18})[math.random(1, 3)],
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
                            vx = player.facing * (10 + math.random() * 20) + (math.random() - 0.5) * 30,
                            vy = -math.random(15, 45),
                            life = life,
                            max_life = life,
                            color = ({7, 8, 17, 36})[math.random(1, 4)],
                        })
                    end

                    -- Wood chunk
                    local dir = player.facing * (0.6 + math.random() * 0.8)
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
                        -- (no sound on fall start — silent topple)
                        tree.falling = true
                        tree.fall_dir = player.facing
                        tree.fall_vel = 0.15
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
                                vx = player.facing * (10 + math.random() * 20),
                                vy = -math.random(10, 30),
                                life = life,
                                max_life = life,
                                color = ({15, 16, 18})[math.random(1, 3)],
                            })
                        end

                        -- Leaves shaking off at start
                        local leaf_burst = math.max(4, math.floor(tree.w * tree.h / 200))
                        for _ = 1, math.random(leaf_burst, leaf_burst + 3) do
                            local life = 0.4 + math.random() * 0.4
                            table.insert(world.particles, {
                                x = tree.x + math.random(0, tree.w),
                                y = tree.y + math.random(0, math.floor(tree.h * 0.6)),
                                vx = player.facing * (5 + math.random() * 15) + (math.random() - 0.5) * 20,
                                vy = -math.random(10, 40),
                                life = life,
                                max_life = life,
                                color = ({7, 8, 17, 36})[math.random(1, 4)],
                            })
                        end
                    end

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

        -- Fall physics
        if tree.falling and not tree.fell then
            tree.fall_vel = tree.fall_vel + 4.0 * dt
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
                    color = ({7, 8, 17, 36})[math.random(1, 4)],
                })
            end

            -- Impact when reaching 90 degrees
            if tree.fall_angle >= math.pi / 2 then
                tree.fall_angle = math.pi / 2
                tree.fell = true
                tree.fall_timer = 0.8

                gen_sound.play_tree_fall_sound()

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

                -- Big dust cloud at impact point
                local dust_count = math.max(8, math.floor(tree.h / 4))
                for _ = 1, dust_count do
                    local life = 0.4 + math.random() * 0.5
                    table.insert(world.particles, {
                        x = impact_x + (math.random() - 0.5) * 10,
                        y = base_y + (math.random() - 0.5) * 3,
                        vx = (math.random() - 0.5) * 40,
                        vy = -math.random(10, 40),
                        life = life,
                        max_life = life,
                        color = ({19, 14, 15})[math.random(1, 3)],
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
                        vx = (math.random() - 0.5) * 60,
                        vy = -math.random(20, 70),
                        life = life,
                        max_life = life,
                        color = ({7, 8, 17, 36})[math.random(1, 4)],
                    })
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
