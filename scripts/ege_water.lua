local M = { RANGE = 20 }
local function IsFreshPool(entity)
    return entity:HasTag("pond") or entity.prefab=="grotto_pool_big" or entity.prefab=="grotto_pool_small"
end
local function IsOasis(entity) return entity.prefab == "oasislake" end
function M.FindSource(pt)
    local world = TheWorld
    if not world or not world.Map then return nil end
    local map,range = world.Map,M.RANGE
    local kind,point,best=nil,nil,math.huge
    -- Same square and 4-unit sampling used by the Cloud Country patch.
    for x=pt.x-range,pt.x+range,4 do for z=pt.z-range,pt.z+range,4 do
        if map:IsOceanTileAtPoint(x,0,z) and not map:IsVisualGroundAtPoint(x,0,z) then
            local distance=(x-pt.x)^2+(z-pt.z)^2
            if distance<best then kind,point,best="sea",{x=x,y=0,z=z},distance end
        end
    end end
    for _,entity in ipairs(TheSim:FindEntities(pt.x,0,pt.z,range*1.415,{"watersource"},{"INLIMBO"})) do
        if not entity:HasTag("inventoryitem") and not entity:HasTag("_inventoryitem") then
            local source = entity.components and entity.components.watersource
            local available = source == nil or source.available
            local x,y,z=entity.Transform:GetWorldPosition()
            local valid=available and not entity.frozen and math.abs(x-pt.x)<=range and math.abs(z-pt.z)<=range
            local sourcekind=IsOasis(entity) and world.state.issummer and "oasis"
                or not IsOasis(entity) and IsFreshPool(entity) and "pond" or nil
            if valid and sourcekind then
                local distance=(x-pt.x)^2+(z-pt.z)^2
                if kind=="sea" or distance<best then
                    kind,point,best=sourcekind,{x=x,y=0,z=z},distance
                end
            end
        end
    end
    return kind,point
end
function M.CanBuild(pt) return M.FindSource(pt) ~= nil end
return M
