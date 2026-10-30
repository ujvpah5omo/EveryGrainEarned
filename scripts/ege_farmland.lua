-- Automatic farmland removal follows the native terraformer undertile rule,
-- without tool restrictions, dug-ground particles, sound, or turf item drops.
local M={}
function M.Clear(map,undertile,x,z)
    local tx,tz=map:GetTileCoordsAtPoint(x,0,z)
    if map:GetTile(tx,tz)~=WORLD_TILES.FARMING_SOIL then return false end
    local ground=undertile and undertile:GetTileUnderneath(tx,tz) or WORLD_TILES.DIRT
    if ground==nil or ground==WORLD_TILES.FARMING_SOIL then ground=WORLD_TILES.DIRT end
    map:SetTile(tx,tz,ground)
    return map:GetTile(tx,tz)~=WORLD_TILES.FARMING_SOIL
end
return M
