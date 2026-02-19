-- gen/sound.lua
-- Procedural sound generation + playback

local C = require("core.const")

local M = {}

local function generate_chop_sound()
    local duration = 0.08 + math.random() * 0.04
    local samples = math.floor(C.SAMPLE_RATE * duration)
    local data = love.sound.newSoundData(samples, C.SAMPLE_RATE, 16, 1)

    local tone_freq = 120 + math.random() * 80
    local crack_freq = 800 + math.random() * 600
    local noise_mix = 0.3 + math.random() * 0.2
    local tone_mix = 1.0 - noise_mix

    for i = 0, samples - 1 do
        local t = i / C.SAMPLE_RATE
        local progress = i / samples

        local env = math.exp(-progress * 18)
        local attack = math.min(1.0, (i / C.SAMPLE_RATE) / 0.002)
        env = env * attack

        local tone_low = math.sin(2 * math.pi * tone_freq * t)
        local tone_high = math.sin(2 * math.pi * crack_freq * t) * math.exp(-progress * 35)
        local tone = tone_low * 0.6 + tone_high * 0.4

        local noise = math.random() * 2 - 1

        local sample = (tone * tone_mix + noise * noise_mix) * env * 0.45
        sample = math.max(-1, math.min(1, sample))
        data:setSample(i, sample)
    end

    return love.audio.newSource(data, "static")
end

local function generate_tree_fall_sound()
    local duration = 0.25 + math.random() * 0.1
    local samples = math.floor(C.SAMPLE_RATE * duration)
    local data = love.sound.newSoundData(samples, C.SAMPLE_RATE, 16, 1)

    local base_freq = 60 + math.random() * 40

    for i = 0, samples - 1 do
        local t = i / C.SAMPLE_RATE
        local progress = i / samples

        local env
        if progress < 0.15 then
            env = math.exp(-progress * 12)
        else
            env = 0.5 * math.exp(-(progress - 0.15) * 8)
        end
        local attack = math.min(1.0, t / 0.002)
        env = env * attack

        local freq = base_freq * (1.5 - progress * 0.8)
        local tone = math.sin(2 * math.pi * freq * t) * 0.4

        local noise = (math.random() * 2 - 1) * 0.6

        local sample = (tone + noise) * env * 0.5
        sample = math.max(-1, math.min(1, sample))
        data:setSample(i, sample)
    end

    return love.audio.newSource(data, "static")
end

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
    local src = generate_chop_sound()
    src:setVolume(0.6 + math.random() * 0.2)
    src:setPitch(0.9 + math.random() * 0.2)
    src:play()
end

function M.play_tree_fall_sound()
    local src = generate_tree_fall_sound()
    src:setVolume(0.8)
    src:setPitch(0.85 + math.random() * 0.15)
    src:play()
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

return M
