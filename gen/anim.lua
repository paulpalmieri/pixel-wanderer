-- gen/anim.lua
-- Keyframe animation data for part-based character system
-- Each animation defines per-frame {dx, dy} offsets for parts
-- Parts not listed in a frame default to {0, 0}
-- All offsets are INTEGER pixels — no interpolation, no rotation

local M = {}

-- ============================================================
-- WALK CYCLE: 6 frames, 0.1s each = 0.6s full cycle
-- Contact/Down/Passing for each side
-- Arms pump in the same direction as their leg (robot march feel)
-- Head/Torso always share Y offset to prevent disconnects
-- ============================================================
M.walk = {
    frame_time = 0.1,
    num_frames = 6,
    frames = {
        -- Frame 0: Contact A — near leg forward, far leg back
        [0] = {
            near_leg  = {1, 0},
            far_leg   = {-1, 0},
            near_arm  = {0, 0},     -- arms held steady (carrying axe)
            far_arm   = {0, 0},
            head      = {0, 0},
            torso     = {0, 0},
        },
        -- Frame 1: Down A — body dips
        [1] = {
            near_leg  = {1, 0},
            far_leg   = {0, -1},
            near_arm  = {0, 1},     -- arms bob with torso
            far_arm   = {0, 1},
            head      = {0, 1},
            torso     = {0, 1},
        },
        -- Frame 2: Passing A
        [2] = {
            near_leg  = {0, 0},
            far_leg   = {0, -1},
            near_arm  = {0, 0},
            far_arm   = {0, 0},
            head      = {0, 0},
            torso     = {0, 0},
        },
        -- Frame 3: Contact B — mirror
        [3] = {
            near_leg  = {-1, 0},
            far_leg   = {1, 0},
            near_arm  = {0, 0},
            far_arm   = {0, 0},
            head      = {0, 0},
            torso     = {0, 0},
        },
        -- Frame 4: Down B — body dips
        [4] = {
            near_leg  = {0, -1},
            far_leg   = {1, 0},
            near_arm  = {0, 1},
            far_arm   = {0, 1},
            head      = {0, 1},
            torso     = {0, 1},
        },
        -- Frame 5: Passing B
        [5] = {
            near_leg  = {0, -1},
            far_leg   = {0, 0},
            near_arm  = {0, 0},
            far_arm   = {0, 0},
            head      = {0, 0},
            torso     = {0, 0},
        },
    },
}

-- ============================================================
-- JUMP OFFSETS: state-based, not frame-timed
-- Returns per-part offsets for each jump phase
-- ============================================================
function M.get_jump_offsets(phase)
    if phase == "crouch" then
        return {
            head      = {0, 1},
            torso     = {0, 1},
            near_leg  = {0, -1},    -- compressed
            far_leg   = {0, -1},
            near_arm  = {0, 1},
            far_arm   = {0, 1},
        }
    elseif phase == "rising" then
        return {
            head      = {0, -1},    -- stretch up
            torso     = {0, 0},
            near_leg  = {0, 1},     -- trail behind
            far_leg   = {0, 1},
            near_arm  = {0, -1},    -- arms up
            far_arm   = {0, -1},
        }
    elseif phase == "falling" then
        return {
            head      = {0, 0},
            torso     = {0, 0},
            near_leg  = {0, -1},    -- tucked up
            far_leg   = {0, -1},
            near_arm  = {0, 1},     -- arms down
            far_arm   = {0, 1},
        }
    end
    -- Default: no offset
    return {}
end

-- ============================================================
-- LANDING BOUNCE: progress-based (0.0 = just landed, 1.0 = settled)
-- 3 phases: squash → stretch → settle
-- Head/torso share Y to prevent gaps
-- ============================================================
function M.get_land_offsets(progress)
    if progress < 0.35 then
        -- SQUASH: body compressed, legs spread, arms flare
        return {
            head      = {0, 2},     -- head pushed down (matches torso intent)
            torso     = {0, 1},     -- torso dips
            near_leg  = {1, -1},    -- legs spread + compress
            far_leg   = {-1, -1},
            near_arm  = {1, 1},     -- arms flare out
            far_arm   = {-1, 1},
        }
    elseif progress < 0.6 then
        -- STRETCH: body bounces up tall, legs snap together
        return {
            head      = {0, -1},    -- head pops up
            torso     = {0, 0},
            near_leg  = {0, 0},     -- legs together
            far_leg   = {0, 0},
            near_arm  = {0, -1},    -- arms lift
            far_arm   = {0, -1},
        }
    elseif progress < 0.85 then
        -- SETTLE: slight dip back toward rest
        return {
            head      = {0, 1},     -- matches torso
            torso     = {0, 0},
            near_leg  = {0, 0},
            far_leg   = {0, 0},
            near_arm  = {0, 0},
            far_arm   = {0, 0},
        }
    end
    -- Done: no offset
    return {}
end

-- ============================================================
-- SWING OFFSETS: progress-based (0.0 to 1.0)
-- Returns per-part offsets for axe swing phases
-- Head and torso always share the same Y offset to prevent gaps
-- Phases tuned for a snappy, grounded chop:
--   windup (pull back) → strike → impact freeze → recovery
-- Legs stay planted, lateral body movement is minimal (1px max)
-- ============================================================
function M.get_swing_offsets(progress, facing)
    -- Phases for 1-arm shoulder rotation:
    -- 0.00-0.25: Windup (pulling back and up)
    -- 0.25-0.35: Peak/Hold (arm max height, body stretched)
    -- 0.35-0.45: Strike (fast arc over top)
    -- 0.45-0.65: Impact (body crunch, heavy hit)
    -- 0.65-0.80: Rebound
    -- 0.80-1.00: Recovery
    
    if progress <= 0.25 then
        -- Windup: shift weight back, arm starts pulling back
        return {
            head      = {-1, 0},
            torso     = {-1, 0},
            near_arm  = {-1, 0},    -- slightly back
            far_arm   = {0, 0},
            near_leg  = {-1, 0},
            far_leg   = {0, 0},
        }
    elseif progress <= 0.35 then
        -- Peak: Max stretch before throwing the weight
        return {
            head      = {-1, -1},
            torso     = {-1, 0},
            near_arm  = {-3, 0},    -- back further
            far_arm   = {0, -1},
            near_leg  = {0, 0},
            far_leg   = {0, 0},
        }
    elseif progress <= 0.45 then
        -- STRIKE: Snapping over the top. Fast smear phase.
        return {
            head      = {1, 0},
            torso     = {1, 0},
            near_arm  = {1, -1},
            far_arm   = {0, 0},
            near_leg  = {1, 0},
            far_leg   = {0, 0},
        }
    elseif progress <= 0.65 then
        -- IMPACT: Heavy hit, but ends earlier (less compression)
        return {
            head      = {1, 1},     -- shallow dip
            torso     = {1, 1},
            near_arm  = {1, 1},     -- arm not pulled as far down
            far_arm   = {0, 1},
            near_leg  = {1, 0},     -- less leg compression
            far_leg   = {1, 0},
        }
    elseif progress <= 0.80 then
        -- REBOUND
        return {
            head      = {0, 0},
            torso     = {0, 0},
            near_arm  = {0, 0},
            far_arm   = {0, 0},
            near_leg  = {0, 0},
            far_leg   = {0, 0},
        }
    elseif progress <= 1.0 then
        -- Recovery back to idle
        return {
            head      = {0, 0},
            torso     = {0, 0},
            near_arm  = {0, 0},
            far_arm   = {0, 0},
            near_leg  = {0, 0},
            far_leg   = {0, 0},
        }
    end
    return {}
end

function M.get_swing_arm_shape(progress)
    -- Returns arm pixels relative to shoulder. +x is FORWARD, +y is DOWN
    if progress <= 0.25 then
        -- WINDUP: arm points back and slightly down
        return { {dx=0, dy=0}, {dx=-1, dy=0}, {dx=-1, dy=1}, {dx=-2, dy=1} }
    elseif progress <= 0.35 then
        -- PEAK: arm points flat back
        return { {dx=0, dy=0}, {dx=-1, dy=0}, {dx=-2, dy=0}, {dx=-2, dy=1} }
    elseif progress <= 0.45 then
        -- STRIKE: arm swings forward-down
        return { {dx=0, dy=0}, {dx=1, dy=1}, {dx=1, dy=2}, {dx=2, dy=2} }
    elseif progress <= 0.65 then
        -- IMPACT: arm straight down (slightly forward)
        return { {dx=0, dy=0}, {dx=0, dy=1}, {dx=1, dy=2}, {dx=1, dy=3} }
    elseif progress <= 0.80 then
        -- REBOUND: slightly forward
        return { {dx=0, dy=0}, {dx=0, dy=1}, {dx=0, dy=2}, {dx=1, dy=3} }
    else
        -- RECOVERY: normal
        return nil
    end
end

-- ============================================================
-- IDLE OFFSETS: time-based continuous
-- ONE breath cycle drives everything in sync
-- Torso + head + arms all share the same Y offset
-- ============================================================
function M.get_idle_offsets(time)
    -- Slow breathing: ~2.5s cycle, snapped to 0 or 1
    local breath = math.sin(time * 0.8 * math.pi)
    local breath_px = breath > 0.5 and 1 or 0

    -- Everything moves together — no desync
    return {
        head      = {0, breath_px},
        torso     = {0, breath_px},
        near_arm  = {0, breath_px},
        far_arm   = {0, breath_px},
    }
end

-- ============================================================
-- AXE SWING HIT OFFSETS (kept for compatibility with combat.lua)
-- Returns hand position for axe drawing
-- ============================================================
function M.get_hit_offsets(progress, arm_len)
    local REST   = math.pi / 2
    local WINDUP = math.pi * 4 / 3
    local STRIKE = math.pi / 6

    local angle
    if progress <= 0.3 then
        local t = progress / 0.3
        angle = REST + t * (WINDUP - REST)
    elseif progress <= 0.6 then
        local t = (progress - 0.3) / 0.3
        angle = WINDUP + t * (STRIKE + 2 * math.pi - WINDUP)
    else
        local t = (progress - 0.6) / 0.4
        angle = STRIKE + t * (REST - STRIKE)
    end

    local half = math.floor(arm_len / 2)
    local hand_dx = math.floor(arm_len * math.cos(angle) + 0.5)
    local hand_dy = math.floor(arm_len * math.sin(angle) + 0.5) - arm_len
    local elbow_dx = math.floor(half * math.cos(angle) + 0.5)
    local elbow_dy = math.floor(half * math.sin(angle) + 0.5) - half

    return {
        hand_n  = {hand_dx, hand_dy},
        elbow_n = {elbow_dx, elbow_dy},
    }
end

return M
