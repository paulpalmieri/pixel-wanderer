-- Pixel Wanderer
-- A moody retro pixel prototype

-- Core
local C         = require("core.const")
local world_mod = require("core.world")

-- Generators
local gen_char  = require("gen.character")
local gen_ground = require("gen.ground")
local gen_tree  = require("gen.tree")
local gen_cloud = require("gen.cloud")

-- Systems
local sys_player  = require("sys.player")
local sys_combat  = require("sys.combat")
local sys_physics = require("sys.physics")
local sys_camera  = require("sys.camera")

-- Draw
local draw_sky      = require("draw.sky")
local draw_terrain  = require("draw.terrain")
local draw_trees    = require("draw.trees")
local draw_entities = require("draw.entities")
local draw_player   = require("draw.player")
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

-- Transform screen mouse coordinates to virtual (base) coordinates
local function screen_to_game(mx, my)
    local scale, ox, oy = get_scale_and_offset()
    return (mx - ox) / scale, (my - oy) / scale
end

-- ============================================================
-- LOVE CALLBACKS
-- ============================================================
function love.load()
    love.graphics.setDefaultFilter("nearest", "nearest")
    world = world_mod.new()
    world.font = love.graphics.newFont("m5x7.ttf", 32)
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
end

function love.keypressed(key)
    if key == "r" then
        world.player.sprite = gen_char.generate()
    end
    if key == "space" and world.player.on_ground then
        world.player.vy = C.JUMP_VEL
        world.player.on_ground = false
    end
    if key == "f5" then
        gen_tree.generate_trees(world)
        gen_cloud.generate_cloud_textures(world)
        world.player.sprite = gen_char.generate()
    end
    if key == "b" then
        is_fullscreen = not is_fullscreen
        love.window.setFullscreen(is_fullscreen, "desktop")
    end
    if key == "escape" then
        love.event.quit()
    end
end

function love.mousepressed(x, y, button)
    -- Transform screen coords to virtual coords for gameplay
    local gx, gy = screen_to_game(x, y)
    if button == 1 and world.player.axe_cooldown <= 0 then
        world.player.axe_swing = 0.001
        world.player.axe_has_hit = false
        world.player.axe_cooldown = 0.4
    end
end

function love.update(dt)
    dt = math.min(dt, 1/30)

    sys_physics.update_pickup_chain(dt, world)
    sys_player.update(dt, world)
    sys_camera.update(dt, world)
    sys_camera.update_clouds(dt, world)
    sys_combat.update(dt, world)
    sys_physics.update_particles(dt, world)
    sys_physics.update_wood_chunks(dt, world)
    sys_physics.update_flying_chunks(dt, world)
    sys_physics.update_floating_texts(dt, world)
    sys_physics.update_resource_log(dt, world)
end

function love.draw()
    local scale, ox, oy = get_scale_and_offset()
    local cam_ix = math.floor(world.camera_x + 0.5)
    local cam_iy = math.floor(world.camera_y + 0.5)

    -- Clear to black (for letterbox bars if aspect doesn't match exactly)
    love.graphics.clear(0, 0, 0, 1)

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
    love.graphics.setColor(1, 1, 1)
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
    local anim = draw_player.draw_player(world)
    draw_player.draw_axe(world, anim)
    draw_entities.draw_particles(world)

    love.graphics.setCanvas()
    love.graphics.pop()
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(world.canvas, 0, 0, 0, PIXEL, PIXEL)

    -- Pass 4: HUD (virtual screen-space)
    draw_hud.draw_hud(world)

    love.graphics.pop()
end
