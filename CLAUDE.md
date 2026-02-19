# Pixel Wanderer

A moody retro pixel prototype built with LÖVE 2D (Lua). Procedural pixel art generation, wood-chopping gameplay, parallax clouds, part-based character animation.

## Running

```bash
love .
```

Requires [LÖVE](https://love2d.org/) 11.x. On macOS: `brew install love`.

## Controls

- **WASD** — move, **Space** — jump
- **LMB** — chop trees
- **R** — randomize character
- **F5** — regenerate all (trees, clouds, character)
- **Escape** — quit

## Architecture

Three concerns, three folders. `main.lua` is a thin orchestrator (~140 lines).

```
01/
├── conf.lua              # LÖVE window config (unchanged)
├── m5x7.ttf              # Pixel font
├── main.lua              # Orchestrator: requires, init, update/draw sequence
├── core/
│   ├── palette.lua       # PAL[1-37], set_color(idx, alpha), draw_pixel(x, y)
│   ├── const.lua         # PIXEL, GAME_W/H, GRAVITY, JUMP_VEL, MOVE_SPEED, WALL dims, SAMPLE_RATE
│   └── world.lua         # world.new() → shared state bag
├── gen/                  # Pure generators — return data tables, no side effects (except sound playback)
│   ├── character.lua     # generate() → parts table {head, body, arms, legs, draw_order}
│   ├── ground.lua        # generate() → {heightmap, decorations, width, base_y}
│   ├── tree.lua          # generate_tree(size_hint) → {grid, w, h, tree_type}
│   │                     # generate_trees(world) → populates world.trees
│   ├── cloud.lua         # generate_cloud_shape(w, h), generate_cloud_textures(world)
│   └── sound.lua         # play_chop_sound(), play_tree_fall_sound(), play_pickup_sound(world)
├── sys/                  # Per-frame game logic — each system owns specific world fields
│   ├── player.lua        # create(world), update(dt, world) — movement, gravity, collision, walk anim
│   ├── combat.lua        # update(dt, world) — axe swing, hit detection, tree damage
│   ├── physics.lua       # update_particles, update_wood_chunks, update_floating_texts, update_pickup_chain
│   └── camera.lua        # init(world), update(dt, world), update_clouds(dt, world)
└── draw/                 # Rendering — reads world, never writes (except draw/player returns anim table)
    ├── sky.lua           # draw_sky(world), draw_clouds(world)
    ├── terrain.lua       # draw_ground(cam_ix, cam_iy, world), draw_walls(cam_ix, cam_iy, world)
    ├── trees.lua         # draw_trees(cam_ix, cam_iy, world)
    ├── entities.lua      # draw_wood_chunks(world), draw_particles(world)
    ├── player.lua        # draw_player(world) → anim, draw_axe(world, anim)
    └── hud.lua           # draw_hud(world)
```

## Module Communication: The World Table

Everything communicates through a single shared data bag created by `core/world.lua`:

```lua
{
    player           -- owned by sys/player
    ground           -- set once by gen/ground
    trees = {}       -- owned by sys/combat (damage), gen/tree (spawning)
    wood_chunks = {} -- owned by sys/physics
    particles = {}   -- owned by sys/physics (spawned by sys/combat, sys/player)
    floating_texts = {} -- owned by sys/physics
    cloud_layers = {} -- set by gen/cloud, scrolled by sys/camera
    camera_x, camera_y -- owned by sys/camera
    canvas, font     -- set in love.load
    pickup_chain, pickup_chain_timer -- used by gen/sound
}
```

Every `sys/` function signature is `update(dt, world)`. Every `draw/` function receives `world` (plus camera offsets where needed). Generators return plain data tables.

## Rendering Pipeline (in main.lua)

Canvas management and pass ordering stays in main.lua:

1. **Sky + clouds** → `draw/sky` (direct to screen)
2. **Ground + walls** → `draw/terrain` (128×96 canvas, upscaled 4×)
3. **Trees** → `draw/trees` (direct to screen at PIXEL scale for sub-pixel bend)
4. **Foreground** → `draw/entities` + `draw/player` (128×96 canvas, upscaled 4×)
5. **HUD** → `draw/hud` (screen-space)

`draw/` modules never call `setCanvas()`, `push()`, or `pop()` — that's `main.lua`'s job.

## Rules for Agents

### General

- **Test after every change**: run `love .` and verify the game works (walk, jump, chop, pickup, clouds scroll, R regenerates).
- **Don't touch `main.lua`** unless adding a new system/draw call or changing the update/draw pipeline order.
- **Don't touch `core/`** unless adding a new world field or palette color. If you add a world field, document ownership in this file.
- **Prefer editing existing files over creating new ones.**

### Generator contracts (`gen/`)

Generators are pure functions with stable return contracts. You can completely rewrite the internals as long as the returned table shape stays the same:

| Generator | Return contract |
|-----------|----------------|
| `gen/character.generate()` | `{head, body, near_arm, far_arm, near_leg, far_leg, draw_order}` — each part has `{ox, oy, pixels}`, pixels are `{dx, dy, palette_idx}` |
| `gen/ground.generate()` | `{heightmap, decorations, width, base_y}` |
| `gen/tree.generate_tree(size_hint)` | `{grid, w, h, tree_type}` — grid is 2D array of palette indices (0 = transparent) |
| `gen/cloud.generate_cloud_shape(w, h)` | List of `{x, y, shade}` where shade is 0/1/2 |

### System ownership (`sys/`)

Each system owns specific fields in `world`. Don't write to fields owned by another system:

| System | Owns (writes to) | Reads |
|--------|-------------------|-------|
| `sys/player` | `world.player.*` | `world.ground`, `world.particles` (appends dust) |
| `sys/combat` | `world.trees[].hp/timers` | `world.player` (position/facing), appends to `world.particles`, `world.wood_chunks` |
| `sys/physics` | `world.wood_chunks`, `world.particles`, `world.floating_texts`, `world.pickup_chain*` | `world.ground.base_y`, `world.player` (position for pickup) |
| `sys/camera` | `world.camera_x`, `world.camera_y`, `world.cloud_layers[].offset` | `world.player.x`, `world.ground.width` |

### Draw modules (`draw/`)

Read-only. Never mutate `world`. Exception: `draw/player.draw_player()` returns an `anim` table (not stored on world) that's passed to `draw_axe()`.

### Adding a new system

1. Create `gen/<thing>.lua` — pure generator returning data tables
2. Create `sys/<thing>.lua` — `update(dt, world)` reading/writing `world.<thing_list>`
3. Create `draw/<thing>.lua` — rendering from world state
4. Add `world.<thing_list> = {}` to `core/world.lua`
5. Add one `require` + one call each to `love.update()` and `love.draw()` in `main.lua`
6. Document the new field ownership in this file

### Style

- No class hierarchy, no event system — just plain tables and functions.
- Use `core/palette.set_color(idx)` and `core/palette.draw_pixel(x, y)` for all pixel rendering.
- Constants go in `core/const.lua`, not inline magic numbers.
- Palette indices are documented in `core/palette.lua` (1–37).
