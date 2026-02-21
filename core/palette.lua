-- core/palette.lua
-- Enforced 20-color palette
-- New palette with old->new index mapping:
-- Old 1->19, 2->18, 3->16, 4->5, 5->13, 6->20, 7->6, 8->8, 9->6, 10->4, 11->13, 12->14, 13->12, 14->11, 15->10, 16->16

local M = {}

M.PAL = {
    {  0/255,   0/255,   0/255}, -- 1:  #000000  (Black)
    { 59/255,  34/255,  28/255}, -- 2:  #3b221c  (Dark Brown)
    {105/255,  48/255,  43/255}, -- 3:  #69302b  (Deep Red Brown)
    {153/255,  52/255,  44/255}, -- 4:  #99342c  (Brick Red)
    {184/255, 103/255,  53/255}, -- 5:  #b86735  (Burnt Orange)
    {219/255, 163/255,  79/255}, -- 6:  #dba34f  (Warm Gold)
    {137/255, 153/255,  55/255}, -- 7:  #899937  (Olive Green)
    { 76/255, 105/255,  51/255}, -- 8:  #4c6933  (Forest Green)
    { 56/255,  59/255,  33/255}, -- 9:  #383b21  (Dark Olive)
    { 46/255,  76/255,  94/255}, -- 10: #2e4c5e  (Dark Teal Blue)
    { 92/255, 124/255, 148/255}, -- 11: #5c7c94  (Steel Blue)
    {138/255, 184/255, 172/255}, -- 12: #8ab8ac  (Sage Teal)
    {194/255, 128/255, 128/255}, -- 13: #c28080  (Dusty Rose)
    {138/255,  67/255, 104/255}, -- 14: #8a4368  (Plum)
    { 79/255,  40/255,  78/255}, -- 15: #4f284e  (Deep Purple)
    { 38/255,  30/255,  46/255}, -- 16: #261e2e  (Dark Violet Black)
    { 62/255,  63/255,  69/255}, -- 17: #3e3f45  (Charcoal)
    {105/255,  97/255,  99/255}, -- 18: #696163  (Warm Gray)
    {158/255, 158/255, 152/255}, -- 19: #9e9e98  (Light Gray)
    {230/255, 215/255, 204/255}, -- 20: #e6d7cc  (Warm White)
}

function M.set_color(idx)
    local c = M.PAL[idx]
    if not c then 
        c = M.PAL[16]
    end
    love.graphics.setColor(c[1], c[2], c[3], 1.0)
end

function M.draw_pixel(x, y)
    love.graphics.rectangle("fill", x, y, 1, 1)
end

return M
