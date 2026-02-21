-- core/palette.lua
-- Restricted 31-color palette + drawing helpers

local M = {}

M.PAL = {
    -- sky gradient (murky twilight)
    {0.047, 0.055, 0.090},  -- 1: deep sky              #0c0e17
    {0.090, 0.110, 0.165},  -- 2: mid sky               #171c2a
    {0.145, 0.165, 0.220},  -- 3: warm haze             #252a38
    {0.200, 0.210, 0.255},  -- 4: pale stone            #333641
    {0.255, 0.260, 0.290},  -- 5: warm cloud            #41424a
    {0.340, 0.345, 0.365},  -- 6: cloud highlight       #57585d
    -- foliage (dark, desaturated)
    {0.165, 0.220, 0.145},  -- 7: forest green          #2a3825
    {0.110, 0.165, 0.120},  -- 8: deep forest           #1c2a1f
    -- character base
    {0.145, 0.120, 0.130},  -- 9: void dark             #251f21
    {0.120, 0.137, 0.170},  -- 10: deep shadow          #1f232b
    {0.310, 0.380, 0.480},  -- 11: cold blue            #4f617a
    {0.820, 0.620, 0.310},  -- 12: golden glow          #d19e4f
    {0.850, 0.720, 0.530},  -- 13: warm glow            #d9b887
    {0.780, 0.790, 0.780},  -- 14: ice white            #c7c9c7
    -- bark / wood
    {0.220, 0.155, 0.165},  -- 15: dark bark            #38272a
    {0.420, 0.310, 0.220},  -- 16: light bark           #6b4f38
    -- foliage / wood highlights
    {0.310, 0.380, 0.200},  -- 17: forest highlight     #4f6133
    {0.580, 0.420, 0.200},  -- 18: wood highlight       #946b33
    -- robot steel (hi / mid / shd) -- bright metallic greys
    {0.840, 0.850, 0.870},  -- 19: steel hi             #d6d9de
    {0.530, 0.540, 0.560},  -- 20: steel mid            #878a8f
    {0.260, 0.270, 0.290},  -- 21: steel shd            #42454a
    {0.800, 0.830, 0.790},  -- 22: green-steel hi       #ccd4c9
    {0.490, 0.520, 0.490},  -- 23: green-steel mid      #7d857d
    {0.230, 0.260, 0.240},  -- 24: green-steel shd      #3b423d
    {0.830, 0.810, 0.780},  -- 25: warm-steel hi        #d4cfc7
    {0.520, 0.490, 0.470},  -- 26: warm-steel mid       #857d78
    {0.270, 0.250, 0.240},  -- 27: warm-steel shd       #45403d
    {0.790, 0.820, 0.870},  -- 28: blue-steel hi        #c9d1de
    {0.480, 0.510, 0.570},  -- 29: blue-steel mid       #7a8291
    {0.230, 0.250, 0.300},  -- 30: blue-steel shd       #3b404d
    -- ground: dark earth + stone
    {0.220, 0.230, 0.180},  -- 31: surface bright       #383a2e
    {0.165, 0.180, 0.140},  -- 32: surface shadow       #2a2e24
    {0.310, 0.300, 0.280},  -- 33: dirt light           #4f4d47
    {0.220, 0.165, 0.150},  -- 34: dirt mid             #382a26
    {0.110, 0.095, 0.095},  -- 35: dirt dark            #1c1818
    -- extra foliage shades (richer canopy)
    {0.380, 0.480, 0.255},  -- 36: bright leaf          #617a41
    {0.075, 0.110, 0.075},  -- 37: leaf edge            #131c13
    -- robot colors (industrial yellow/black)
    {0.035, 0.030, 0.045},  -- 38: robot black           #09080b
    {0.980, 0.910, 0.160},  -- 39: robot yellow hi       #fae829
    {0.900, 0.780, 0.060},  -- 40: robot yellow mid      #e6c70f
    {0.660, 0.540, 0.040},  -- 41: robot yellow shd      #a88a0a
    {0.100, 0.500, 0.950},  -- 42: robot eye             #1a80f2
    -- robot variety colors
    {0.950, 0.550, 0.100},  -- 43: warm orange eye        #f28c1a
    {0.900, 0.700, 0.100},  -- 44: amber eye              #e6b31a
    {0.850, 0.200, 0.150},  -- 45: red eye                #d93326
    {0.400, 0.450, 0.500},  -- 46: gunmetal mid           #667380
    {0.200, 0.220, 0.260},  -- 47: gunmetal dark          #333842
    {0.600, 0.630, 0.680},  -- 48: gunmetal hi            #99a1ad
    -- pastel robot palettes (4 palettes × 4 colors: hi, mid, lo, eye)
    -- Dusty Sage
    {0.784, 0.835, 0.725},  -- 49: sage hi                #c8d5b9
    {0.561, 0.682, 0.482},  -- 50: sage mid               #8fae7b
    {0.322, 0.478, 0.322},  -- 51: sage lo                #527a52
    {0.949, 0.835, 0.494},  -- 52: sage eye (warm gold)   #f2d57e
    -- Warm Clay
    {0.910, 0.788, 0.627},  -- 53: clay hi                #e8c9a0
    {0.761, 0.584, 0.420},  -- 54: clay mid               #c2956b
    {0.478, 0.361, 0.259},  -- 55: clay lo                #7a5c42
    {0.494, 0.784, 0.890},  -- 56: clay eye (sky blue)    #7ec8e3
    -- Lavender Steel
    {0.769, 0.722, 0.831},  -- 57: lavender hi            #c4b8d4
    {0.545, 0.471, 0.651},  -- 58: lavender mid           #8b78a6
    {0.353, 0.302, 0.431},  -- 59: lavender lo            #5a4d6e
    {0.949, 0.647, 0.494},  -- 60: lavender eye (peach)   #f2a57e
    -- Pale Sky
    {0.722, 0.847, 0.910},  -- 61: sky hi                 #b8d8e8
    {0.478, 0.686, 0.769},  -- 62: sky mid                #7aafc4
    {0.290, 0.478, 0.561},  -- 63: sky lo                 #4a7a8f
    {0.910, 0.722, 0.494},  -- 64: sky eye (amber)        #e8b87e
}

function M.set_color(idx, alpha)
    local c = M.PAL[idx]
    love.graphics.setColor(c[1], c[2], c[3], alpha or 1)
end

function M.draw_pixel(x, y)
    love.graphics.rectangle("fill", x, y, 1, 1)
end

return M
