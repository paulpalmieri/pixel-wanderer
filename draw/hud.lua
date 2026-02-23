-- draw/hud.lua
-- HUD overlay rendering (battery bar, floating text, wood counter, end screens)

local palette = require("core.palette")
local C = require("core.const")

local PAL = palette.PAL
local PIXEL = C.PIXEL
local GAME_W = C.GAME_W
local GAME_H = C.GAME_H

local M = {}

-- Same 4x4 chunk pixel map used in draw/entities.lua
local chunk_map = {
    {  0,  5,  5,  0 },
    {  5,  6,  6,  5 },
    {  2,  6,  6,  2 },
    {  0,  2,  2,  0 },
}

-- Draw a wood chunk at screen position (x, y) with pixel size s and alpha
local function draw_chunk(x, y, s)
    for dy = 1, 4 do
        for dx = 1, 4 do
            local col = chunk_map[dy][dx]
            if col ~= 0 then
                local c = PAL[col]
                love.graphics.setColor(c[1], c[2], c[3], 1.0)
                love.graphics.rectangle("fill", x + (dx-1)*s, y + (dy-1)*s, s, s)
            end
        end
    end
end

-- Ease-out cubic
local function ease_out(t)
    local t1 = 1 - t
    return 1 - t1 * t1 * t1
end


-- ============================================================
-- BATTERY BAR
-- ============================================================
function M.draw_battery(world)
    local max_battery = 60 + (world.upgrades and world.upgrades.battery_bonus or 0)
    local frac = math.max(0, math.min(1, world.battery / max_battery))

    local bx, by = 10, 10
    local bar_w, bar_h = 60, 8
    local nub_w, nub_h = 4, 4

    -- Background (solid shell)
    local bg = PAL[16]
    love.graphics.setColor(bg[1], bg[2], bg[3], 1.0)
    love.graphics.rectangle("fill", bx - 2, by - 2, bar_w + nub_w + 4, bar_h + 4)

    -- Battery nub
    local nub = PAL[16]
    love.graphics.setColor(nub[1], nub[2], nub[3], 1.0)
    love.graphics.rectangle("fill", bx + bar_w + 2, by + (bar_h - nub_h) / 2, nub_w, nub_h)

    -- Color selection (hard thresholds, no lerp)
    local r, g, b
    local color
    if frac > 0.6 then
        color = PAL[8] -- Forest Green
    elseif frac > 0.25 then
        color = PAL[6] -- Warm Gold
    else
        color = PAL[4] -- Brick Red
    end
    
    -- Pulse (binary state for strict palette)
    local visible = true
    if frac <= 0.2 then
        visible = (math.floor(love.timer.getTime() * 8) % 2 == 0)
    end

    if visible then
        local fill_w = math.max(0, math.floor(bar_w * frac))
        love.graphics.setColor(color[1], color[2], color[3], 1.0)
        love.graphics.rectangle("fill", bx, by, fill_w, bar_h)

        -- Highlight (solid, no alpha)
        local white = PAL[20]
        love.graphics.setColor(white[1], white[2], white[3], 1.0)
        love.graphics.rectangle("fill", bx, by, fill_w, 1)
    end

    -- BATT label
    local lbl = PAL[19]
    love.graphics.setColor(lbl[1], lbl[2], lbl[3], 1.0)
    local stime = string.format("%.0fs", math.max(0, world.battery))
    love.graphics.print(stime, bx + bar_w + nub_w + 6, by - 2)
end

-- ============================================================
-- GAMEOVER SCREEN
-- ============================================================
function M.draw_gameover(world)
    local SCREEN_W = GAME_W * PIXEL
    local SCREEN_H = GAME_H * PIXEL

    -- Darken background overlay (solid obsidian black)
    local bg = PAL[16]
    love.graphics.setColor(bg[1], bg[2], bg[3], 1.0)
    love.graphics.rectangle("fill", 0, 0, SCREEN_W, SCREEN_H)

    -- Panel
    local pw, ph = 320, 200
    local px = (SCREEN_W - pw) / 2
    local py = (SCREEN_H - ph) / 2

    local pnl = PAL[10] -- Dark Teal Blue base
    love.graphics.setColor(pnl[1], pnl[2], pnl[3], 1.0)
    love.graphics.rectangle("fill", px, py, pw, ph)
    local brd = PAL[19] -- Light Gray border
    love.graphics.setColor(brd[1], brd[2], brd[3], 1.0)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", px, py, pw, ph)

    -- Title: MISSION TERMINATED
    local titl = PAL[20] -- Warm White
    love.graphics.setColor(titl[1], titl[2], titl[3], 1.0)
    local title = "MISSION TERMINATED"
    local tw = world.font:getWidth(title)
    love.graphics.print(title, px + (pw - tw) / 2, py + 24)

    -- Separator line
    local sep = PAL[19]
    love.graphics.setColor(sep[1], sep[2], sep[3], 1.0)
    love.graphics.setLineWidth(1)
    love.graphics.line(px + 48, py + 70, px + pw - 48, py + 70)

    -- Wood gathered
    local txt = PAL[19]
    love.graphics.setColor(txt[1], txt[2], txt[3], 1.0)
    local sub = "Wood gathered this run:"
    local sw = world.font:getWidth(sub)
    love.graphics.print(sub, px + (pw - sw) / 2, py + 82)

    local wc = PAL[12]
    love.graphics.setColor(wc[1], wc[2], wc[3], 1.0)
    local woodstr = tostring(world.wood_at_game_end)
    local icon_s = 5
    local combined_w = world.font:getWidth(woodstr) + icon_s * 5 + 8
    local icon_x = px + (pw - combined_w) / 2
    local text_x = icon_x + icon_s * 5 + 8
    draw_chunk(icon_x, py + 115, icon_s)
    love.graphics.setColor(wc[1], wc[2], wc[3], 1.0)
    love.graphics.print(woodstr, text_x, py + 112)

    -- Continue button
    local btn_w = 160
    local btn_h = 36
    local btn_x = px + (pw - btn_w) / 2
    local btn_y = py + ph - 58

    local mx, my = love.mouse.getPosition()
    local scale, ox, oy = _get_scale_and_offset_cached()
    local gmx = (mx - ox) / scale
    local gmy = (my - oy) / scale
    local hovered = (gmx >= btn_x and gmx <= btn_x + btn_w and gmy >= btn_y and gmy <= btn_y + btn_h)

    if hovered then
        local hov = PAL[12] -- Sage Teal highlight
        love.graphics.setColor(hov[1], hov[2], hov[3], 1.0)
    else
        local btn = PAL[11] -- Steel Blue
        love.graphics.setColor(btn[1], btn[2], btn[3], 1.0)
    end
    love.graphics.rectangle("fill", btn_x, btn_y, btn_w, btn_h)
    local brd = PAL[20] -- Bright border on hover/etc actually keep it subtle
    love.graphics.setColor(1, 1, 1, 0) -- transparent
    if hovered then
        love.graphics.setColor(PAL[20][1], PAL[20][2], PAL[20][3], 1.0)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", btn_x, btn_y, btn_w, btn_h)
    end

    local white = PAL[20]
    love.graphics.setColor(white[1], white[2], white[3], 1.0)
    local btxt = "CONTINUE"
    local bw = world.font:getWidth(btxt)
    love.graphics.print(btxt, btn_x + (btn_w - bw) / 2, btn_y + (btn_h - 20) / 2)

    -- Store button hitbox so mouse events can query it
    world._gameover_btn = { x = btn_x, y = btn_y, w = btn_w, h = btn_h }
end

-- ============================================================
-- SKILL TREE SCREEN
-- ============================================================

local SKILLS = {
    -- Center
    { id="core_robot", name="ROBOT", desc="A robot that can\ncut trees", cost=0, icon="robot", gx=0, gy=0, req=nil,
      check=function(upg) return true end, apply=function(upg) end },

    -- Top (Damage)
    { id="axe_dmg_1", name="SHARP EDGE", desc="Pickaxe deals\n+1 damage per hit", cost=30, icon="axe", gx=0, gy=-1, req="core_robot",
      check=function(upg) return upg.axe_damage and upg.axe_damage >= 1 end,
      apply=function(upg) upg.axe_damage = (upg.axe_damage or 0) + 1 end },
    { id="swing_spd_1", name="QUICK SWING", desc="Swing axe faster", cost=50, icon="axe", gx=0, gy=-2, req="axe_dmg_1",
      check=function(upg) return upg.swing_speed and upg.swing_speed >= 1 end,
      apply=function(upg) upg.swing_speed = (upg.swing_speed or 0) + 1 end },

    -- Right (Battery)
    { id="bat_flat_1", name="EXTENDED CELL", desc="Battery capacity\n+5 seconds", cost=40, icon="battery", gx=1, gy=0, req="core_robot",
      check=function(upg) return upg.battery_bonus and upg.battery_bonus >= 5 end,
      apply=function(upg) upg.battery_bonus = (upg.battery_bonus or 0) + 5 end },
    { id="bat_leech_1", name="KINETIC CHARGE", desc="Restore 1s battery\nwhen you cut a tree", cost=80, icon="battery", gx=2, gy=0, req="bat_flat_1",
      check=function(upg) return upg.battery_leech end,
      apply=function(upg) upg.battery_leech = true end },

    -- Bottom (Helper)
    { id="helper_start", name="ROBOT BUDDY", desc="Start each run\nwith one free robot", cost=50, icon="robot", gx=0, gy=1, req="core_robot",
      check=function(upg) return upg.free_robot end,
      apply=function(upg) upg.free_robot = true end },

    -- Left (Tree Upgrades)
    { id="tree_hp_1", name="TOUGH BARK", desc="Trees have more\nhealth and wood", cost=40, icon="tree", gx=-1, gy=0, req="core_robot",
      check=function(upg) return upg.tree_health_bonus and upg.tree_health_bonus >= 1 end,
      apply=function(upg) upg.tree_health_bonus = (upg.tree_health_bonus or 0) + 1 end },
    { id="tree_new_1", name="EXOTIC SEEDS", desc="Unlock new types\nof trees (Coming Soon)", cost=100, icon="tree", gx=-2, gy=0, req="tree_hp_1",
      check=function(upg) return upg.new_trees end,
      apply=function(upg) upg.new_trees = true end },
}

local function draw_skill_icon(icon, cx, cy, col)
    -- simple 8x8 pixel icons
    if icon == "robot" then
        love.graphics.setColor(col[1], col[2], col[3], 1.0)
        love.graphics.rectangle("fill", cx - 3, cy - 4, 6, 4) -- head
        love.graphics.rectangle("fill", cx - 2, cy, 4, 3)     -- body
        love.graphics.rectangle("fill", cx - 4, cy, 1, 2)     -- l arm
        love.graphics.rectangle("fill", cx + 3, cy, 1, 2)     -- r arm
        love.graphics.rectangle("fill", cx - 2, cy + 3, 1, 2) -- l leg
        love.graphics.rectangle("fill", cx + 1, cy + 3, 1, 2) -- r leg
        -- eye
        local eye = PAL[12]
        love.graphics.setColor(eye[1], eye[2], eye[3], 1.0)
        love.graphics.rectangle("fill", cx - 1, cy - 3, 2, 1)
    elseif icon == "battery" then
        love.graphics.setColor(col[1], col[2], col[3], 1.0)
        love.graphics.rectangle("fill", cx - 4, cy - 2, 8, 4)
        love.graphics.rectangle("fill", cx + 4, cy - 1, 1, 2) -- nub
        -- green fill (partial)
        local fill = PAL[8]
        love.graphics.setColor(fill[1], fill[2], fill[3], 1.0)
        love.graphics.rectangle("fill", cx - 3, cy - 1, 5, 2)
    elseif icon == "axe" then
        love.graphics.setColor(col[1], col[2], col[3], 1.0)
        -- handle
        love.graphics.rectangle("fill", cx, cy - 4, 1, 8)
        -- blade
        local pts = {
            cx, cy - 3,
            cx + 3, cy - 2,
            cx + 3, cy + 1,
            cx, cy,
        }
        love.graphics.polygon("fill", pts)
    elseif icon == "tree" then
        love.graphics.setColor(col[1], col[2], col[3], 1.0)
        love.graphics.rectangle("fill", cx - 1, cy, 2, 4) -- trunk
        local pts = {
            cx, cy - 4,
            cx + 3, cy,
            cx - 3, cy
        }
        love.graphics.polygon("fill", pts)
    end
end

function M.draw_skilltree(world)
    local SCREEN_W = GAME_W * PIXEL
    local SCREEN_H = GAME_H * PIXEL

    -- Full background
    local bg = PAL[16]
    love.graphics.setColor(bg[1], bg[2], bg[3], 1.0)
    love.graphics.rectangle("fill", 0, 0, SCREEN_W, SCREEN_H)

    -- Header
    local hdr = PAL[6]
    love.graphics.setColor(hdr[1], hdr[2], hdr[3], 1.0)
    local title = "SKILL TREE"
    local tw = world.font:getWidth(title)
    love.graphics.print(title, (SCREEN_W - tw) / 2, 24)

    -- Wood budget
    local wc = PAL[12]
    love.graphics.setColor(wc[1], wc[2], wc[3], 1.0)
    local budget_str = "Wood: " .. tostring(world.player and world.player.wood_count or world.wood_at_game_end)
    love.graphics.print(budget_str, 20, 24)

    -- Instruction
    local inst = PAL[19]
    love.graphics.setColor(inst[1], inst[2], inst[3], 1.0)
    love.graphics.print("Spend wood to unlock upgrades, then Play Again", (SCREEN_W - world.font:getWidth("Spend wood to unlock upgrades, then Play Again")) / 2, 56)

    -- Skill tree logic
    local node_s = 24
    local spacing = 40
    local center_x = SCREEN_W / 2
    local center_y = SCREEN_H / 2 - 10

    local wood = world.player and world.player.wood_count or world.wood_at_game_end

    -- Build a lookup for skills by id to draw lines
    local skill_by_id = {}
    for _, sk in ipairs(SKILLS) do
        skill_by_id[sk.id] = sk
    end

    -- Draw lines first
    love.graphics.setLineWidth(2)
    for _, sk in ipairs(SKILLS) do
        if sk.req and skill_by_id[sk.req] then
            local p = skill_by_id[sk.req]
            local x1 = center_x + p.gx * spacing
            local y1 = center_y + p.gy * spacing
            local x2 = center_x + sk.gx * spacing
            local y2 = center_y + sk.gy * spacing
            
            local owned = sk.check(world.upgrades)
            local req_owned = p.check(world.upgrades)
            
            if owned then
                local conn = PAL[6] -- Warm Gold
                love.graphics.setColor(conn[1], conn[2], conn[3], 1.0)
            elseif req_owned then
                local conn = PAL[12] -- Sage Teal (Available)
                love.graphics.setColor(conn[1], conn[2], conn[3], 1.0)
            else
                local conn = PAL[10] -- Dark Teal Blue (Locked)
                love.graphics.setColor(conn[1], conn[2], conn[3], 1.0)
            end
            
            love.graphics.line(x1, y1, x2, y2)
        end
    end

    -- init hover table if needed
    world._skill_btns = world._skill_btns or {}
    for i in ipairs(world._skill_btns) do world._skill_btns[i] = nil end
    local btn_idx = 1

    local mx_s, my_s = love.mouse.getPosition()
    local scale, ox, oy = _get_scale_and_offset_cached()
    local gmx = (mx_s - ox) / scale
    local gmy = (my_s - oy) / scale

    local hovered_skill = nil
    
    for _, sk in ipairs(SKILLS) do
        local cx = center_x + sk.gx * spacing
        local cy = center_y + sk.gy * spacing
        local req_owned = (sk.req == nil) or skill_by_id[sk.req].check(world.upgrades)
        local owned = sk.check(world.upgrades)
        local affordable = req_owned and (wood >= sk.cost)
        
        -- rect is centered on cx, cy
        local rx = cx - node_s / 2
        local ry = cy - node_s / 2
        
        local hovered = (gmx >= rx and gmx <= rx + node_s and gmy >= ry and gmy <= ry + node_s)
        
        if hovered then
            hovered_skill = sk
        end
        
        if sk.cost > 0 then
            world._skill_btns[btn_idx] = { x = rx, y = ry, w = node_s, h = node_s, skill = sk }
            btn_idx = btn_idx + 1
        end
        
        -- Node background
        if owned then
            local nbg = PAL[19] -- Light Gray for owned
            love.graphics.setColor(nbg[1], nbg[2], nbg[3], 1.0)
        elseif hovered and affordable then
            local nbg = PAL[12] -- Sage Teal for hover/buy
            love.graphics.setColor(nbg[1], nbg[2], nbg[3], 1.0)
        elseif req_owned then
            local nbg = PAL[10] -- Dark Teal Blue for available
            love.graphics.setColor(nbg[1], nbg[2], nbg[3], 1.0)
        else
            local nbg = PAL[16] -- Black for locked
            love.graphics.setColor(nbg[1], nbg[2], nbg[3], 1.0)
        end
        love.graphics.rectangle("fill", rx, ry, node_s, node_s)

        -- Border
        if owned then
            local nbrd = PAL[6]
            love.graphics.setColor(nbrd[1], nbrd[2], nbrd[3], 1.0)
        elseif affordable then
            local nbrd = PAL[11]
            love.graphics.setColor(nbrd[1], nbrd[2], nbrd[3], 1.0)
        elseif req_owned then
            local nbrd = PAL[19]
            love.graphics.setColor(nbrd[1], nbrd[2], nbrd[3], 1.0)
        else
            local nbrd = PAL[10]
            love.graphics.setColor(nbrd[1], nbrd[2], nbrd[3], 1.0)
        end
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", rx, ry, node_s, node_s)
        
        -- Icon
        local icon_col = owned and PAL[6] or (affordable and PAL[12] or (req_owned and PAL[19] or PAL[16]))
        draw_skill_icon(sk.icon, cx, cy, icon_col)
    end

    -- Play Again button
    local btn_w = 200
    local btn_h = 40
    local btn_x = (SCREEN_W - btn_w) / 2
    local btn_y = SCREEN_H - btn_h - 20

    local hovered_btn = (gmx >= btn_x and gmx <= btn_x + btn_w and gmy >= btn_y and gmy <= btn_y + btn_h)
    if hovered_btn then
        local hov = PAL[12] -- Sage Teal highlight
        love.graphics.setColor(hov[1], hov[2], hov[3], 1.0)
    else
        local btn = PAL[11] -- Steel Blue
        love.graphics.setColor(btn[1], btn[2], btn[3], 1.0)
    end
    love.graphics.rectangle("fill", btn_x, btn_y, btn_w, btn_h)
    if hovered_btn then
        love.graphics.setColor(PAL[20][1], PAL[20][2], PAL[20][3], 1.0)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", btn_x, btn_y, btn_w, btn_h)
    end

    local white = PAL[20]
    love.graphics.setColor(white[1], white[2], white[3], 1.0)
    local btxt = "PLAY AGAIN"
    local bw = world.font:getWidth(btxt)
    love.graphics.print(btxt, btn_x + (btn_w - bw) / 2, btn_y + (btn_h - 20) / 2)

    world._play_again_btn = { x = btn_x, y = btn_y, w = btn_w, h = btn_h }

    -- Draw Tooltip for hovered skill
    if hovered_skill then
        local sk = hovered_skill
        local req_owned = (sk.req == nil) or skill_by_id[sk.req].check(world.upgrades)
        local owned = sk.check(world.upgrades)
        local affordable = req_owned and (wood >= sk.cost)
        
        local tw = 160
        local th = 100
        
        local tx = gmx + 15
        local ty = gmy + 15
        
        if tx + tw > SCREEN_W then tx = gmx - tw - 15 end
        if ty + th > SCREEN_H then ty = gmy - th - 15 end

        local bg = PAL[16]
        love.graphics.setColor(bg[1], bg[2], bg[3], 1.0)
        love.graphics.rectangle("fill", tx, ty, tw, th)
        local brd = PAL[19]
        love.graphics.setColor(brd[1], brd[2], brd[3], 1.0)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", tx, ty, tw, th)
        
        -- Name
        local col = owned and PAL[6] or (affordable and PAL[20] or PAL[19])
        love.graphics.setColor(col[1], col[2], col[3], 1.0)
        local nw = world.font:getWidth(sk.name)
        love.graphics.print(sk.name, tx + (tw - nw) / 2, ty + 8)
        
        -- Status / Cost
        if sk.cost == 0 then
            local c = PAL[6]
            love.graphics.setColor(c[1], c[2], c[3], 1.0)
            local badge = "CORE"
            local bw = world.font:getWidth(badge)
            love.graphics.print(badge, tx + (tw - bw) / 2, ty + 24)
        elseif owned then
            local c = PAL[6]
            love.graphics.setColor(c[1], c[2], c[3], 1.0)
            local badge = "UNLOCKED"
            local bw = world.font:getWidth(badge)
            love.graphics.print(badge, tx + (tw - bw) / 2, ty + 24)
        elseif not req_owned then
            local c = PAL[4]
            love.graphics.setColor(c[1], c[2], c[3], 1.0)
            local badge = "LOCKED"
            local bw = world.font:getWidth(badge)
            love.graphics.print(badge, tx + (tw - bw) / 2, ty + 24)
        else
            local c = affordable and PAL[6] or PAL[4]
            love.graphics.setColor(c[1], c[2], c[3], 1.0)
            local badge = sk.cost .. " wood"
            local bw = world.font:getWidth(badge)
            love.graphics.print(badge, tx + (tw - bw) / 2, ty + 24)
        end
        
        -- Desc
        local desc = PAL[19]
        love.graphics.setColor(desc[1], desc[2], desc[3], 1.0)
        local lines = {}
        for line in (sk.desc .. "\n"):gmatch("([^\n]*)\n") do
            table.insert(lines, line)
        end
        -- handle case where desc has no newlines 
        if #lines == 0 and #sk.desc > 0 then table.insert(lines, sk.desc) end
        
        for li, line in ipairs(lines) do
            local lw = world.font:getWidth(line)
            love.graphics.print(line, tx + (tw - lw) / 2, ty + 50 + (li - 1) * 16)
        end
    end
end

-- ============================================================
-- MAIN HUD DRAW ENTRY
-- ============================================================
function M.draw_hud(world)
    local SCREEN_W = GAME_W * PIXEL
    local SCREEN_H = GAME_H * PIXEL

    -- Game over and skill tree screens are full-screen — draw instead of normal HUD
    if world.game_state == "gameover" then
        M.draw_gameover(world)
        return
    end
    if world.game_state == "skilltree" then
        M.draw_skilltree(world)
        return
    end

    -- ── Normal playing HUD ──────────────────────────────────

    -- Battery bar (top-left)
    if world.battery then
        M.draw_battery(world)
    end

    -- Floating texts (info)
    for _, ft in ipairs(world.floating_texts) do
        local t = ft.life / ft.max_life
        local alpha = t
        local scale = ft.scale or 1.0
        local age = ft.max_life - ft.life
        if age < 0.1 then
            scale = scale * (1.0 + (1.0 - age / 0.1) * 0.5)
        end

        local cx = math.floor(ft.x - world.camera_x + 0.5)
        local cy = math.floor(ft.y - world.camera_y + 0.5)
        local sx = math.floor(cx * PIXEL)
        local sy = math.floor(cy * PIXEL)

        local shadow = PAL[16]
        love.graphics.setColor(shadow[1], shadow[2], shadow[3], 1.0)
        love.graphics.print(ft.text, sx + 1, sy + 1, 0, scale, scale)
        local white = PAL[20]
        love.graphics.setColor(white[1], white[2], white[3], 1.0)
        love.graphics.print(ft.text, sx, sy, 0, scale, scale)
    end

    -- Resource log (top-right, slides in and fades)
    local log_x = SCREEN_W - 10
    local log_y = 10
    local icon_s = 3
    local line_h = 28
    for i, entry in ipairs(world.resource_log) do
        local t = entry.life / entry.max_life
        -- Fade in first 0.3s, fade out last 1s
        local alpha
        local age = entry.max_life - entry.life
        if age < 0.3 then
            alpha = age / 0.3
        elseif t < 0.25 then
            alpha = t / 0.25
        else
            alpha = 1.0
        end
        -- Slide in from right
        local slide = 0
        if age < 0.2 then
            slide = (1.0 - age / 0.2) * 60
        end

        local text = "x" .. entry.amount
        local tw = world.font:getWidth(text)
        local ex = log_x + slide - tw
        local ey = log_y + (i - 1) * line_h

        -- Icon
        draw_chunk(ex - 5*icon_s, ey + 2, icon_s)

        -- Text
        local shadow = PAL[16]
        love.graphics.setColor(shadow[1], shadow[2], shadow[3], 1.0)
        love.graphics.print(text, ex + 1, ey + 1)
        local c = PAL[12]
        love.graphics.setColor(c[1], c[2], c[3], 1.0)
        love.graphics.print(text, ex, ey)
    end

    -- Flying wood chunks (animate from pickup to HUD counter)
    for _, fc in ipairs(world.flying_chunks) do
        local t = ease_out(fc.t)
        -- Curved path: add an arc offset that peaks at t=0.5
        local arc = -60 * math.sin(t * math.pi)
        local cx = fc.x + (fc.tx - fc.x) * t
        local cy = fc.y + (fc.ty - fc.y) * t + arc
        draw_chunk(cx - 2*PIXEL, cy - 2*PIXEL, PIXEL)
    end

    -- Wood total (top-left, persistent) — move right of battery
    if world.player.wood_count > 0 then
        draw_chunk(10, 38, icon_s)
        local c = PAL[12]
        love.graphics.setColor(c[1], c[2], c[3], 1.0)
        love.graphics.print(tostring(world.player.wood_count), 10 + 5*icon_s, 34)
    end

    -- E-prompt near entrance button when player is nearby and can afford
    if world.entrance_anim_done and world.player then
        local px = world.player.x + 8
        local entrance_zone_right = C.WALL_WIDTH + C.ENTRANCE_DOOR_W + 24
        if px < entrance_zone_right then
            local btn_cx = math.floor((world._btn_x or 19) - world.camera_x + 0.5)
            local btn_cy = math.floor((world._btn_y or 64) - world.camera_y + 0.5)
            local btn_screen_x = math.floor(btn_cx * PIXEL)
            local btn_screen_y = math.floor(btn_cy * PIXEL)
            if world.player.wood_count >= 20 then
                -- Teal prompt (Success)
                local prompt = PAL[12]
                love.graphics.setColor(prompt[1], prompt[2], prompt[3], 1.0)
                love.graphics.print("[E] Spawn Robot (-20 wood)", btn_screen_x - 30, btn_screen_y - 24)
            else
                -- Grey prompt (Fail)
                local prompt = PAL[19]
                love.graphics.setColor(prompt[1], prompt[2], prompt[3], 1.0)
                love.graphics.print("[E] Need 20 wood", btn_screen_x - 20, btn_screen_y - 20)
            end
        end
    end

    -- UI hint
    local c = PAL[19]
    love.graphics.setColor(c[1], c[2], c[3], 1.0)
    love.graphics.print("WASD + SPACE | LMB = chop | E = spawn robot | R = randomize", 8, SCREEN_H - 20)
end

-- Cache accessor for scale/offset (set by main.lua before the HUD is drawn)
_get_scale_and_offset_cached = _get_scale_and_offset_cached or function()
    local win_w, win_h = love.graphics.getDimensions()
    local BASE_W = C.GAME_W * C.PIXEL
    local BASE_H = C.GAME_H * C.PIXEL
    local scale = math.min(win_w / BASE_W, win_h / BASE_H)
    local ox = math.floor((win_w - BASE_W * scale) / 2)
    local oy = math.floor((win_h - BASE_H * scale) / 2)
    return scale, ox, oy
end

return M
