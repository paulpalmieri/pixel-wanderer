-- core/music.lua
-- Manages background music tracks and elegant cross-fades between game states

local M = {}

M.tracks = {}
M.fade_speed = 0.4 -- Volume change per second for an "elegant" transition

local VOL_LEVELS = {
    playing = 0.15,
    skilltree = 0.20
}

function M.init()
    -- Main gameplay music
    M.tracks.playing = love.audio.newSource("assets/background_music.mp3", "stream")
    M.tracks.playing:setLooping(true)
    M.tracks.playing:setVolume(0)
    M.tracks.playing:play()

    -- Skill tree music
    M.tracks.skilltree = love.audio.newSource("assets/skill_tree_music.mp3", "stream")
    M.tracks.skilltree:setLooping(true)
    M.tracks.skilltree:setVolume(0)
    M.tracks.skilltree:play()
end

function M.update(dt, state)
    -- Determine target volume for each track based on state
    -- Transitions:
    -- "playing" / "gameover" -> use playing music
    -- "skilltree" -> use skilltree music
    
    for name, src in pairs(M.tracks) do
        local target = 0
        
        if state == "playing" or state == "gameover" then
            if name == "playing" then 
                target = VOL_LEVELS.playing 
            end
        elseif state == "skilltree" then
            if name == "skilltree" then 
                target = VOL_LEVELS.skilltree 
            end
        end

        local cur = src:getVolume()
        if cur < target then
            src:setVolume(math.min(target, cur + M.fade_speed * dt))
        elseif cur > target then
            src:setVolume(math.max(target, cur - M.fade_speed * dt))
        end
    end
end

return M
