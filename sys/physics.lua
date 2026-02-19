-- sys/physics.lua
-- Particle, wood chunk, and floating text physics

local C = require("core.const")
local gen_sound = require("gen.sound")

local M = {}

function M.update_particles(dt, world)
    for i = #world.particles, 1, -1 do
        local p = world.particles[i]
        p.vy = p.vy + 80 * dt
        p.vx = p.vx * (1 - 2 * dt)
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.life = p.life - dt
        if p.life <= 0 then
            table.remove(world.particles, i)
        end
    end
end

function M.update_wood_chunks(dt, world)
    local gy = world.ground.base_y
    local CHUNK_SZ = 4
    local player = world.player

    for i = #world.wood_chunks, 1, -1 do
        local c = world.wood_chunks[i]
        if not c.on_ground then
            c.vy = c.vy + C.GRAVITY * dt
            c.x = c.x + c.vx * dt
            c.y = c.y + c.vy * dt

            if c.y + CHUNK_SZ >= gy then
                c.y = gy - CHUNK_SZ
                c.on_ground = true
                c.pickup_ready = true
                c.vx = 0
                c.vy = 0
            end

            if not c.on_ground and c.vy > 0 then
                for j = 1, #world.wood_chunks do
                    if j ~= i and world.wood_chunks[j].on_ground then
                        local other = world.wood_chunks[j]
                        local hx = CHUNK_SZ - math.abs(c.x - other.x)
                        if hx > CHUNK_SZ / 2 then
                            local bottom = c.y + CHUNK_SZ
                            if bottom >= other.y and c.y < other.y then
                                c.y = other.y - CHUNK_SZ
                                c.on_ground = true
                                c.pickup_ready = true
                                c.vx = 0
                                c.vy = 0
                                break
                            end
                        end
                    end
                end
            end
        end

        -- Pickup
        if c.pickup_ready then
            local dx = math.abs((c.x + CHUNK_SZ / 2) - (player.x + 8))
            local dy = math.abs((c.y + CHUNK_SZ / 2) - (player.y + 8))
            if dx < 8 and dy < 8 then
                gen_sound.play_pickup_sound(world)
                player.wood_count = player.wood_count + 1
                world.resource_accum.wood = world.resource_accum.wood + 1
                world.resource_accum_timer = math.max(world.resource_accum_timer, 0.001)
                table.remove(world.wood_chunks, i)
            end
        end
    end

    -- Support check
    for _, c in ipairs(world.wood_chunks) do
        if c.on_ground and c.y + CHUNK_SZ < gy then
            local supported = false
            for _, other in ipairs(world.wood_chunks) do
                if other ~= c and other.on_ground then
                    local hx = CHUNK_SZ - math.abs(c.x - other.x)
                    if hx > CHUNK_SZ / 2 and math.abs((c.y + CHUNK_SZ) - other.y) < 1 then
                        supported = true
                        break
                    end
                end
            end
            if not supported then
                c.on_ground = false
                c.vy = 0
            end
        end
    end

    -- Overlap resolution
    for i = 1, #world.wood_chunks do
        local a = world.wood_chunks[i]
        if a.on_ground then
            for j = i + 1, #world.wood_chunks do
                local b = world.wood_chunks[j]
                if b.on_ground then
                    local ox = CHUNK_SZ - math.abs(a.x - b.x)
                    local oy = CHUNK_SZ - math.abs(a.y - b.y)
                    if ox > 0 and oy > 0 then
                        if oy < ox then
                            if a.y < b.y then
                                a.y = b.y - CHUNK_SZ
                            else
                                b.y = a.y - CHUNK_SZ
                            end
                        else
                            local sign = a.x < b.x and -1 or 1
                            a.x = a.x + sign * ox * 0.5
                            b.x = b.x - sign * ox * 0.5
                        end
                        if a.y + CHUNK_SZ > gy then a.y = gy - CHUNK_SZ end
                        if b.y + CHUNK_SZ > gy then b.y = gy - CHUNK_SZ end
                    end
                end
            end
        end
    end
end

function M.update_floating_texts(dt, world)
    for i = #world.floating_texts, 1, -1 do
        local ft = world.floating_texts[i]
        -- Horizontal movement with drag
        if ft.vx then
            ft.x = ft.x + ft.vx * dt
            ft.vx = ft.vx * (1 - 3.0 * dt)
        end
        -- Vertical: apply velocity + gravity for arc
        local vy = ft.vy or -15
        ft.y = ft.y + vy * dt
        if ft.vy then
            ft.vy = ft.vy + 60 * dt  -- gravity pulls it down into an arc
        end
        ft.life = ft.life - dt
        if ft.life <= 0 then
            table.remove(world.floating_texts, i)
        end
    end
end

function M.update_pickup_chain(dt, world)
    if world.pickup_chain_timer > 0 then
        world.pickup_chain_timer = world.pickup_chain_timer - dt
        if world.pickup_chain_timer <= 0 then
            world.pickup_chain = 0
        end
    end
end

function M.update_resource_log(dt, world)
    -- Accumulate for 3 seconds then flush
    if world.resource_accum_timer > 0 then
        world.resource_accum_timer = world.resource_accum_timer + dt
        if world.resource_accum_timer >= 3.0 then
            local accum = world.resource_accum
            if accum.wood > 0 then
                table.insert(world.resource_log, {
                    kind = "wood",
                    amount = accum.wood,
                    life = 4.0,
                    max_life = 4.0,
                })
            end
            world.resource_accum = { wood = 0 }
            world.resource_accum_timer = 0
        end
    end

    -- Fade out log entries
    for i = #world.resource_log, 1, -1 do
        local entry = world.resource_log[i]
        entry.life = entry.life - dt
        if entry.life <= 0 then
            table.remove(world.resource_log, i)
        end
    end
end

return M
