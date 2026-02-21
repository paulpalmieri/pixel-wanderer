-- gen/sound.lua
-- Procedural sound generation + playback

local C = require("core.const")

local M = {}
M.fading_sources = {}

local s_hit = love.audio.newSource("assets/axe_tree_hit.mp3", "static")
local s_break = love.audio.newSource("assets/tree_break.mp3", "static")
local s_fall = love.audio.newSource("assets/tree_fall.mp3", "static")

local function generate_pickup_sound()
    local duration = 0.045 + math.random() * 0.015
    local samples = math.floor(C.SAMPLE_RATE * duration)
    local data = love.sound.newSoundData(samples, C.SAMPLE_RATE, 16, 1)

    local freq = 220 + math.random() * 40

    for i = 0, samples - 1 do
        local t = i / C.SAMPLE_RATE
        local progress = i / samples

        local env = (1.0 - progress) ^ 3

        local wave = math.sin(2 * math.pi * freq * t) * 0.6
                   + math.sin(2 * math.pi * freq * 1.8 * t) * 0.4

        data:setSample(i, wave * env * 0.32)
    end

    return love.audio.newSource(data, "static")
end

function M.play_chop_sound()
    local src = s_hit:clone()
    src:setVolume(0.8)
    src:setPitch(0.9 + math.random() * 0.2)
    src:play()
end

function M.play_tree_break_sound(h)
    local src = s_break:clone()
    local vol = 0.8
    -- Keep a heavy, low pitch
    local p = 0.35 + math.random() * 0.1
    src:setVolume(vol)
    src:setPitch(p)
    src:play()

    -- Fade out the rest of the clip after 1.2 seconds so it doesn't ring through the actual impact
    table.insert(M.fading_sources, {
        src = src, 
        timer = 0,
        fade_start = 1.2,
        vol = vol, 
        fade_rate = 1.5
    })
end

function M.play_tree_fall_sound(h)
    local src = s_fall:clone()
    src:setVolume(0.35)
    local p = 0.9 + math.random() * 0.2
    if h then
        p = p - ((h - 40) / 80) * 0.25
    end
    src:setPitch(math.max(0.1, p))
    src:play()
end

function M.update(dt)
    for i = #M.fading_sources, 1, -1 do
        local fade = M.fading_sources[i]
        if fade.src:isPlaying() then
            fade.timer = fade.timer + dt
            if fade.timer >= fade.fade_start then
                fade.vol = math.max(0, fade.vol - fade.fade_rate * dt)
                fade.src:setVolume(fade.vol)
                if fade.vol == 0 then
                    fade.src:stop()
                    table.remove(M.fading_sources, i)
                end
            end
        else
            table.remove(M.fading_sources, i)
        end
    end
end

function M.play_pickup_sound(world)
    world.pickup_chain = math.min(world.pickup_chain + 1, 8)
    world.pickup_chain_timer = 0.4

    local src = generate_pickup_sound()
    local pitch = 0.9 + world.pickup_chain * 0.05 + math.random() * 0.03
    src:setVolume(0.4)
    src:setPitch(pitch)
    src:play()
end

-- ============================================================
-- STEP SOUND: soft, muffled dirt footstep — deep and "sourd"
-- ============================================================
local function generate_step_sound()
    local duration = 0.06 + math.random() * 0.03   -- 60-90ms, longer for body
    local samples = math.floor(C.SAMPLE_RATE * duration)
    local data = love.sound.newSoundData(samples, C.SAMPLE_RATE, 16, 1)

    local freq = 35 + math.random() * 20          -- very low thump (35-55Hz)

    for i = 0, samples - 1 do
        local t = i / C.SAMPLE_RATE
        local progress = i / samples

        -- Softer, rounder decay — not as snappy, more pillowy
        local env = (1.0 - progress) ^ 3

        -- Deep bass thump
        local thump = math.sin(2 * math.pi * freq * t)

        -- Sub-bass harmonic for body/weight
        local sub = math.sin(2 * math.pi * freq * 0.5 * t) * 0.6

        -- Tiny touch of filtered noise (dirt texture, very quiet)
        local noise = (math.random() * 2 - 1) * 0.12

        -- Mix: heavy on bass, minimal noise
        local sample = (thump * 0.55 + sub * 0.35 + noise * 0.10) * env * 0.35

        data:setSample(i, sample)
    end

    return love.audio.newSource(data, "static")
end

function M.play_step_sound()
    local src = generate_step_sound()
    src:setVolume(0.75 + math.random() * 0.10)   -- ~80% volume
    src:setPitch(0.7 + math.random() * 0.3)       -- pitch range 0.7-1.0
    src:play()
end

return M
