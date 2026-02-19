-- gen/anim.lua
-- Shared animation keyframe data for skeleton-based characters
-- Each frame defines {joint_name = {dx, dy}} offsets from canonical pose
-- Joints not listed default to {0, 0}

local M = {}

-- Walk cycle: 6 frames, 0.12s each = 0.72s full cycle
-- Frame 0,3 = contact, 1,4 = down, 2,5 = passing
M.walk = {
    frame_time = 0.12,
    frames = {
        -- Frame 0: Contact A — near leg forward stride, far leg back
        [0] = {
            knee_n  = {2, -1},
            foot_n  = {3,  0},
            knee_f  = {-1, 0},
            foot_f  = {-2, 0},
            hand_n  = {0,  1},
            elbow_n = {0,  1},
            hand_f  = {0, -1},
            elbow_f = {0, -1},
            body_dy = 0,
            head_dy = 0,
        },
        -- Frame 1: Down A — weight on near leg, far leg lifting
        [1] = {
            knee_n  = {1,  0},
            foot_n  = {1,  0},
            knee_f  = {0, -1},
            foot_f  = {0, -1},
            body_dy = 0,
            head_dy = 0,
        },
        -- Frame 2: Passing A — near leg straight, far leg swinging through
        [2] = {
            knee_f  = {1, -2},
            foot_f  = {1, -2},
            hand_n  = {0, -1},
            elbow_n = {0, -1},
            hand_f  = {0,  1},
            elbow_f = {0,  1},
            body_dy = -1,
            head_dy = -1,
        },
        -- Frame 3: Contact B — far leg forward, near leg back (mirror of 0)
        [3] = {
            knee_f  = {1, -1},
            foot_f  = {2,  0},
            knee_n  = {-1,  0},
            foot_n  = {-2,  0},
            hand_n  = {0,  -1},
            elbow_n = {0,  -1},
            hand_f  = {0,   1},
            elbow_f = {0,   1},
            body_dy = 0,
            head_dy = 0,
        },
        -- Frame 4: Down B — weight on far leg, near leg lifting
        [4] = {
            knee_f  = {1,  0},
            foot_f  = {1,  0},
            knee_n  = {0, -1},
            foot_n  = {0, -1},
            body_dy = 0,
            head_dy = 0,
        },
        -- Frame 5: Passing B — far leg straight, near leg swinging through
        [5] = {
            knee_n  = {1, -2},
            foot_n  = {1, -2},
            hand_n  = {0,  1},
            elbow_n = {0,  1},
            hand_f  = {0, -1},
            elbow_f = {0, -1},
            body_dy = -1,
            head_dy = -1,
        },
    },
}

-- Hit animation: shoulder-anchored rotation
-- arm_len = distance from shoulder to hand in canonical pose
-- Returns offsets from canonical elbow/hand positions
function M.get_hit_offsets(progress, arm_len)
    -- Angles in standard math (0=right, pi/2=down, pi=left, 3pi/2=up) with Y-down screen
    local REST   = math.pi / 2       -- arm hangs straight down
    local WINDUP = math.pi * 4 / 3   -- ~240° arm raised up-back
    local STRIKE = math.pi / 6       -- ~30° arm forward-slightly-down

    local angle
    if progress <= 0.3 then
        -- Windup: sweep from rest up to windup position
        local t = progress / 0.3
        angle = REST + t * (WINDUP - REST)
    elseif progress <= 0.6 then
        -- Strike: sweep from windup over the top to strike
        local t = (progress - 0.3) / 0.3
        angle = WINDUP + t * (STRIKE + 2 * math.pi - WINDUP)
    else
        -- Follow-through: ease from strike back to rest
        local t = (progress - 0.6) / 0.4
        angle = STRIKE + t * (REST - STRIKE)
    end

    local half = math.floor(arm_len / 2)

    -- Hand offset from canonical position (0, arm_len) relative to shoulder
    local hand_dx = math.floor(arm_len * math.cos(angle) + 0.5)
    local hand_dy = math.floor(arm_len * math.sin(angle) + 0.5) - arm_len

    -- Elbow offset from canonical position (0, half) relative to shoulder
    local elbow_dx = math.floor(half * math.cos(angle) + 0.5)
    local elbow_dy = math.floor(half * math.sin(angle) + 0.5) - half

    return {
        hand_n  = {hand_dx, hand_dy},
        elbow_n = {elbow_dx, elbow_dy},
    }
end

return M
