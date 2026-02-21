-- Pixel Wanderer
-- A moody retro pixel prototype

-- Core
local C         = require("core.const")
local world_mod = require("core.world")
local palette   = require("core.palette")
local PAL       = palette.PAL

-- Generators
local gen_char  = require("gen.character")
local gen_ground = require("gen.ground")
local gen_tree  = require("gen.tree")
local gen_cloud = require("gen.cloud")
local gen_sound = require("gen.sound")
local gen_robot = require("gen.robot")

-- Systems
local sys_player  = require("sys.player")
local sys_combat  = require("sys.combat")
local sys_physics = require("sys.physics")
local sys_camera  = require("sys.camera")
local sys_robot   = require("sys.robot")

-- Draw
local draw_sky      = require("draw.sky")
local draw_terrain  = require("draw.terrain")
local draw_trees    = require("draw.trees")
local draw_entities = require("draw.entities")
local draw_player   = require("draw.player")
local draw_robot    = require("draw.robot")
local draw_hud      = require("draw.hud")

local PIXEL  = C.PIXEL
local GAME_W = C.GAME_W
local GAME_H = C.GAME_H

-- Base (virtual) screen size — all draw code targets this
local BASE_W = GAME_W * PIXEL   -- 640
local BASE_H = GAME_H * PIXEL   -- 360

local world
local is_fullscreen = false

-- Compute scale and offset to uniformly fit BASE_W×BASE_H into current window
local function get_scale_and_offset()
    local win_w, win_h = love.graphics.getDimensions()
    local scale = math.min(win_w / BASE_W, win_h / BASE_H)
    local ox = math.floor((win_w - BASE_W * scale) / 2)
    local oy = math.floor((win_h - BASE_H * scale) / 2)
    return scale, ox, oy
end

-- Make this available globally so draw/hud.lua can use it for mouse-hit-testing
_get_scale_and_offset_cached = get_scale_and_offset

-- Transform screen mouse coordinates to virtual (base) coordinates
local function screen_to_game(mx, my)
    local scale, ox, oy = get_scale_and_offset()
    return (mx - ox) / scale, (my - oy) / scale
end

-- ============================================================
-- GAME INITIALIZATION (called at start and on restart)
-- ============================================================
local function init_game(existing_upgrades)
    world = world_mod.new(existing_upgrades)
    world.font = love.graphics.newFont("m5x7.ttf", 16)
    world.font:setFilter("nearest", "nearest")
    love.graphics.setFont(world.font)
    world.canvas = love.graphics.newCanvas(GAME_W, GAME_H)
    world.canvas:setFilter("nearest", "nearest")

    math.randomseed(os.time())

    world.ground = gen_ground.generate()
    sys_player.create(world)
    gen_cloud.generate_cloud_textures(world)
    gen_tree.generate_trees(world)

    sys_camera.init(world)

    if not world.floating_texts then
        world.floating_texts = {}
    end

    -- Battery: 10s base + upgrade bonus
    local base_battery = 10
    local bonus = world.upgrades.battery_bonus or 0
    world.battery = base_battery + bonus

    world.game_state = "playing"

    -- Free robot upgrade: spawn one robot immediately after entrance anim (deferred)
    world._pending_free_robot = world.upgrades.free_robot
end

-- ============================================================
-- LOVE CALLBACKS
-- ============================================================
function love.load()
    love.graphics.setDefaultFilter("nearest", "nearest")

    -- Background music (persists across restarts)
    local bgm = love.audio.newSource("assets/background_music.mp3", "stream")
    bgm:setVolume(0.15)
    bgm:setLooping(true)
    bgm:play()

    init_game(nil)  -- fresh start, no upgrades
end

function love.keypressed(key)
    if key == "r" then
        if world.game_state == "playing" then
            world.player.sprite = gen_char.generate()
        end
    end
    if key == "space" and world.game_state == "playing" and world.entrance_anim_done and world.player.on_ground then
        world.player.vy = C.JUMP_VEL
        world.player.on_ground = false
    end
    if key == "f5" then
        local saved = world.upgrades
        init_game(saved)
    end
    if key == "b" then
        is_fullscreen = not is_fullscreen
        love.window.setFullscreen(is_fullscreen, "desktop")
    end
    if key == "escape" then
        if world.game_state == "gameover" or world.game_state == "skilltree" then
            -- Allow escape to go to skill tree from gameover, or quit from skilltree
            if world.game_state == "gameover" then
                world.game_state = "skilltree"
            else
                love.event.quit()
            end
        else
            love.event.quit()
        end
    end
    if key == "e" and world.game_state == "playing" and world.entrance_anim_done then
        -- Check proximity to entrance button area and wood >= 20
        local px = world.player.x + 8
        local entrance_zone_right = C.WALL_WIDTH + C.ENTRANCE_DOOR_W + 24
        if px < entrance_zone_right and world.player.wood_count >= 20 then
            world.player.wood_count = world.player.wood_count - 20

            -- Queue robot to spawn at entrance
            local rx = C.WALL_WIDTH + math.floor(C.ENTRANCE_DOOR_W / 2) - 8
            local ry = world.ground.base_y - 16
            if not world.robot_queue then world.robot_queue = {} end
            table.insert(world.robot_queue, gen_robot.generate(rx, ry))

            -- Feedback
            local feedback_x = C.WALL_WIDTH + C.ENTRANCE_DOOR_W + 8
            table.insert(world.floating_texts, {
                x = feedback_x, y = ry - 10, vx = 0, vy = -30, text = "ROBOT ASSEMBLED!",
                life = 1.5, max_life = 1.5, scale = 1.0, is_crit = false
            })
            table.insert(world.floating_texts, {
                x = world.player.x, y = world.player.y - 10, vx = 0, vy = -20, text = "-20 wood",
                life = 1.0, max_life = 1.0, scale = 1.0, is_crit = false
            })
        end
    end
end

function love.mousepressed(x, y, button)
    -- Transform screen coords to virtual coords for gameplay
    local gx, gy = screen_to_game(x, y)

    if world.game_state == "playing" then
        if button == 1 and world.entrance_anim_done and world.player.axe_cooldown <= 0 then
            world.player.axe_swing = 0.001
            world.player.axe_has_hit = false
            
            local cooldown = 0.40
            if world.upgrades and world.upgrades.swing_speed then
                cooldown = math.max(0.18, cooldown - 0.08 * world.upgrades.swing_speed)
            end
            world.player.axe_cooldown = cooldown
        end

    elseif world.game_state == "gameover" then
        -- Check continue button
        local btn = world._gameover_btn
        if button == 1 and btn and gx >= btn.x and gx <= btn.x + btn.w and gy >= btn.y and gy <= btn.y + btn.h then
            world.game_state = "skilltree"
        end

    elseif world.game_state == "skilltree" then
        -- Check skill purchase buttons
        if button == 1 and world._skill_btns then
            for _, sb in ipairs(world._skill_btns) do
                if gx >= sb.x and gx <= sb.x + sb.w and gy >= sb.y and gy <= sb.y + sb.h then
                    local sk = sb.skill
                    local owned = sk.check(world.upgrades)
                    -- Wood is the gameover snapshot wood + any from this player session (they share same reference)
                    local wood = world.player and world.player.wood_count or world.wood_at_game_end
                    if not owned and wood >= sk.cost then
                        -- Deduct wood
                        if world.player then
                            world.player.wood_count = world.player.wood_count - sk.cost
                        else
                            world.wood_at_game_end = world.wood_at_game_end - sk.cost
                        end
                        sk.apply(world.upgrades)
                    end
                    break
                end
            end
        end

        -- Check Play Again button
        local pab = world._play_again_btn
        if button == 1 and pab and gx >= pab.x and gx <= pab.x + pab.w and gy >= pab.y and gy <= pab.y + pab.h then
            -- Carry over remaining wood
            local carry_wood = world.player and world.player.wood_count or world.wood_at_game_end
            local saved_upgrades = world.upgrades
            init_game(saved_upgrades)
            -- Restore carried wood
            world.player.wood_count = carry_wood
        end
    end
end

function love.update(dt)
    dt = math.min(dt, 1/30)

    -- Only update physics/systems when actually playing
    if world.game_state == "playing" then

        -- Spawn pending free robot once player has control
        if world._pending_free_robot and world.entrance_anim_done then
            world._pending_free_robot = false
            local rx = C.WALL_WIDTH + math.floor(C.ENTRANCE_DOOR_W / 2) - 8
            local ry = world.ground.base_y - 16
            if not world.robot_queue then world.robot_queue = {} end
            table.insert(world.robot_queue, gen_robot.generate(rx, ry))
            
            local feedback_x = C.WALL_WIDTH + C.ENTRANCE_DOOR_W + 8
            table.insert(world.floating_texts, {
                x = feedback_x, y = ry - 10, vx = 0, vy = -30, text = "FREE ROBOT!",
                life = 1.5, max_life = 1.5, scale = 1.0, is_crit = false
            })
        end

        -- Battery countdown (only counts down once player has control)
        if world.entrance_anim_done and world.battery then
            world.battery = world.battery - dt
            if world.battery <= 0 then
                world.battery = 0
                world.wood_at_game_end = world.player.wood_count
                world.game_state = "gameover"
                return
            end
        end

        sys_physics.update_pickup_chain(dt, world)
        gen_sound.update(dt)
        sys_player.update(dt, world)
        sys_camera.update(dt, world)
        sys_camera.update_clouds(dt, world)
        sys_combat.update(dt, world)
        sys_robot.update(dt, world)
        sys_physics.update_particles(dt, world)
        sys_physics.update_wood_chunks(dt, world)
        sys_physics.update_flying_chunks(dt, world)
        sys_physics.update_floating_texts(dt, world)
        sys_physics.update_resource_log(dt, world)

    elseif world.game_state == "gameover" or world.game_state == "skilltree" then
        -- Just tick the camera smoothly so the frozen world still looks nice
        -- (no physics, no battery drain)
    end
end

function love.draw()
    local scale, ox, oy = get_scale_and_offset()
    local cam_ix = math.floor(world.camera_x + 0.5)
    local cam_iy = math.floor(world.camera_y + 0.5)

    -- Clear to sky blue
    local bg = PAL[11]
    love.graphics.clear(bg[1], bg[2], bg[3], 1)

    -- Apply global scale transform
    love.graphics.push()
    love.graphics.translate(ox, oy)
    love.graphics.scale(scale, scale)

    -- Pass 1: Sky + clouds (direct to virtual screen)
    draw_sky.draw_sky(world)
    draw_sky.draw_clouds(world)

    -- Pass 2: Ground + walls (GAME_W×GAME_H canvas, upscaled)
    -- Reset transform for canvas rendering (canvas is only 160×90)
    love.graphics.push()
    love.graphics.origin()
    love.graphics.setCanvas(world.canvas)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.translate(-cam_ix, -cam_iy)

    draw_terrain.draw_ground(cam_ix, cam_iy, world)
    draw_terrain.draw_walls(cam_ix, cam_iy, world)

    love.graphics.setCanvas()
    love.graphics.pop()
    local white = PAL[20]
    love.graphics.setColor(white[1], white[2], white[3])
    love.graphics.draw(world.canvas, 0, 0, 0, PIXEL, PIXEL)

    -- Pass 2.5: Trees (direct to virtual screen at PIXEL scale for sub-pixel bend)
    love.graphics.setScissor(ox, oy, BASE_W * scale, BASE_H * scale)
    draw_trees.draw_trees(cam_ix, cam_iy, world)
    love.graphics.setScissor()

    -- Pass 3: Foreground (wood chunks, player, axe, particles — GAME_W×GAME_H canvas)
    -- Reset transform for canvas rendering
    love.graphics.push()
    love.graphics.origin()
    love.graphics.setCanvas(world.canvas)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.translate(-cam_ix, -cam_iy)

    draw_entities.draw_wood_chunks(world)
    draw_robot.draw_robots(world)
    local anim = draw_player.draw_player(world)
    draw_player.draw_axe(world, anim)
    draw_entities.draw_particles(world)

    love.graphics.setCanvas()
    love.graphics.pop()
    local white = PAL[20]
    love.graphics.setColor(white[1], white[2], white[3])
    love.graphics.draw(world.canvas, 0, 0, 0, PIXEL, PIXEL)

    -- Pass 4: HUD (virtual screen-space) — also handles gameover/skilltree screens
    draw_hud.draw_hud(world)

    love.graphics.pop()
end
