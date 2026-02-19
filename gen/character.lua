-- gen/character.lua
-- Skeleton-based robot character generator
-- Style: dark outlines, colored fill inside. Simple boxy shapes.

local M = {}

-- 3 palettes, 4 colors each: {dark, primary, highlight, eye}
local PALETTES = {
    {24, 23, 22, 42},   -- Green Steel
    {30, 29, 28, 45},   -- Steel Blue
    {27, 26, 25, 44},   -- Warm Steel
}

----------------------------------------------------------------
-- 3 HEADS — dark outline, colored fill
----------------------------------------------------------------

-- Square: 5w x 4h
local function head_square()
    return {w = 5, h = 4, pixels = {
        {0,0,"dk"},{1,0,"dk"},{2,0,"dk"},{3,0,"dk"},{4,0,"dk"},
        {0,1,"dk"},{1,1,"pr"},{2,1,"pr"},{3,1,"ey"},{4,1,"dk"},
        {0,2,"dk"},{1,2,"pr"},{2,2,"pr"},{3,2,"pr"},{4,2,"dk"},
        {1,3,"dk"},{2,3,"dk"},{3,3,"dk"},
    }}
end

-- Tall: 4w x 5h
local function head_tall()
    return {w = 4, h = 5, pixels = {
        {0,0,"dk"},{1,0,"dk"},{2,0,"dk"},{3,0,"dk"},
        {0,1,"dk"},{1,1,"pr"},{2,1,"pr"},{3,1,"dk"},
        {0,2,"dk"},{1,2,"pr"},{2,2,"ey"},{3,2,"dk"},
        {0,3,"dk"},{1,3,"pr"},{2,3,"pr"},{3,3,"dk"},
        {1,4,"dk"},{2,4,"dk"},
    }}
end

-- Round: 5w x 4h, no top corners
local function head_round()
    return {w = 5, h = 4, pixels = {
        {1,0,"dk"},{2,0,"dk"},{3,0,"dk"},
        {0,1,"dk"},{1,1,"pr"},{2,1,"pr"},{3,1,"ey"},{4,1,"dk"},
        {0,2,"dk"},{1,2,"pr"},{2,2,"pr"},{3,2,"pr"},{4,2,"dk"},
        {1,3,"dk"},{2,3,"dk"},{3,3,"dk"},
    }}
end

local HEAD_MAKERS = {head_square, head_tall, head_round}

----------------------------------------------------------------
-- 3 TORSOS — dark outline, colored fill
----------------------------------------------------------------

-- Standard: 6w, big color box
local function torso_standard()
    return {w = 6, h = 6, pixels = {
        {2,0,"dk"},{3,0,"dk"},                                                 -- neck
        {0,1,"dk"},{1,1,"dk"},{2,1,"dk"},{3,1,"dk"},{4,1,"dk"},{5,1,"dk"},     -- outline top
        {0,2,"dk"},{1,2,"pr"},{2,2,"pr"},{3,2,"pr"},{4,2,"pr"},{5,2,"dk"},     -- fill
        {0,3,"dk"},{1,3,"pr"},{2,3,"pr"},{3,3,"pr"},{4,3,"pr"},{5,3,"dk"},     -- fill
        {0,4,"dk"},{1,4,"dk"},{2,4,"dk"},{3,4,"dk"},{4,4,"dk"},{5,4,"dk"},     -- outline bottom
        {1,5,"dk"},{2,5,"dk"},{3,5,"dk"},{4,5,"dk"},                           -- hips
    }}
end

-- Armored: 6w, dark belt splits two color sections
local function torso_armored()
    return {w = 6, h = 6, pixels = {
        {2,0,"dk"},{3,0,"dk"},                                                 -- neck
        {0,1,"dk"},{1,1,"dk"},{2,1,"pr"},{3,1,"pr"},{4,1,"dk"},{5,1,"dk"},     -- outline + narrow fill
        {0,2,"dk"},{1,2,"pr"},{2,2,"pr"},{3,2,"pr"},{4,2,"pr"},{5,2,"dk"},     -- fill
        {0,3,"dk"},{1,3,"dk"},{2,3,"dk"},{3,3,"dk"},{4,3,"dk"},{5,3,"dk"},     -- belt divider
        {0,4,"dk"},{1,4,"pr"},{2,4,"pr"},{3,4,"pr"},{4,4,"pr"},{5,4,"dk"},     -- fill
        {1,5,"dk"},{2,5,"dk"},{3,5,"dk"},{4,5,"dk"},                           -- hips
    }}
end

-- Slim: 5w, compact color box
local function torso_slim()
    return {w = 5, h = 6, pixels = {
        {1,0,"dk"},{2,0,"dk"},                                           -- neck
        {0,1,"dk"},{1,1,"dk"},{2,1,"dk"},{3,1,"dk"},{4,1,"dk"},         -- outline top
        {0,2,"dk"},{1,2,"pr"},{2,2,"pr"},{3,2,"pr"},{4,2,"dk"},         -- fill
        {0,3,"dk"},{1,3,"pr"},{2,3,"pr"},{3,3,"pr"},{4,3,"dk"},         -- fill
        {0,4,"dk"},{1,4,"dk"},{2,4,"dk"},{3,4,"dk"},{4,4,"dk"},         -- outline bottom
        {1,5,"dk"},{2,5,"dk"},{3,5,"dk"},                               -- hips
    }}
end

local TORSO_MAKERS = {torso_standard, torso_armored, torso_slim}

----------------------------------------------------------------
-- GENERATOR
----------------------------------------------------------------

function M.generate()
    local scheme = PALETTES[math.random(1, #PALETTES)]
    local colors = { dk = scheme[1], pr = scheme[2], hi = scheme[3], ey = scheme[4] }

    local head_block = HEAD_MAKERS[math.random(1, 3)]()
    local body_block = TORSO_MAKERS[math.random(1, 3)]()
    local body_w = body_block.w

    local leg_extra = math.random(0, 1)
    local arm_extra = math.random(0, 1)

    local function resolve(block)
        local out = {}
        for _, p in ipairs(block.pixels) do
            out[#out + 1] = {p[1], p[2], colors[p[3]]}
        end
        return out
    end

    local head_cx = 7
    local head_top_y = 1
    local neck_y = head_top_y + head_block.h
    local shoulder_y = neck_y + 1
    local body_mid = math.floor(body_w / 2)
    local body_ox = head_cx - body_mid

    local elbow_y = shoulder_y + 2 + arm_extra
    local hand_y = elbow_y + 1
    local arm_len = hand_y - shoulder_y

    local hip_y = neck_y + 5
    local knee_y = hip_y + 2 + leg_extra
    local foot_y = knee_y + 2

    local joints = {
        head_top   = {head_cx, head_top_y},
        neck       = {head_cx, neck_y},
        shoulder_n = {body_ox, shoulder_y},
        shoulder_f = {body_ox + body_w - 1, shoulder_y},
        elbow_n    = {body_ox, elbow_y},
        elbow_f    = {body_ox + body_w - 1, elbow_y},
        hand_n     = {body_ox, hand_y},
        hand_f     = {body_ox + body_w - 1, hand_y},
        hip_n      = {head_cx - 1, hip_y},
        hip_f      = {head_cx + 1, hip_y},
        knee_n     = {head_cx - 1, knee_y},
        knee_f     = {head_cx + 1, knee_y},
        foot_n     = {head_cx - 1, foot_y},
        foot_f     = {head_cx + 1, foot_y},
    }

    -- Limbs: near side = dark outline + colored fill, far side = all dark (shadow)
    local limb_defs = {
        far_arm  = {chain = {"shoulder_f","elbow_f","hand_f"}, color = "dk", width_dir = -1},
        far_leg  = {chain = {"hip_f","knee_f","foot_f"}, color = "dk", width_dir = -1, foot = true},
        near_leg = {chain = {"hip_n","knee_n","foot_n"}, color = "dk", fill = "pr",
                    width_dir = 1, foot = true},
        near_arm = {chain = {"shoulder_n","elbow_n","hand_n"}, color = "dk", fill = "pr",
                    width_dir = 1},
    }

    return {
        joints = joints,
        colors = colors,
        limb_defs = limb_defs,
        draw_order = {"far_arm","far_leg","body","head","near_leg","near_arm"},
        arm_len = arm_len,
        skeleton = true,
        head = {
            ox = head_cx - math.floor(head_block.w / 2),
            oy = head_top_y,
            w = head_block.w,
            h = head_block.h,
            pixels = resolve(head_block),
        },
        body = {
            ox = body_ox,
            oy = neck_y,
            w = body_w,
            h = 6,
            pixels = resolve(body_block),
        },
    }
end

return M
