-- gen/ground.lua
-- Procedural ground generator

local C = require("core.const")

local M = {}

function M.generate()
    local g = {
        heightmap = {},
        decorations = {},
        width = 512,
        base_y = C.GAME_H - 16,
    }

    for x = 0, g.width - 1 do
        g.heightmap[x] = g.base_y
    end

    return g
end

return M
