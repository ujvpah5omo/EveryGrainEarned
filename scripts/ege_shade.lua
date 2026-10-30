local M={}
function M.IsSheltered(x,z)
    local large=TUNING.SHADE_CANOPY_RANGE or 28
    local small=TUNING.SHADE_CANOPY_RANGE_SMALL or 22
    for _,tree in ipairs(TheSim:FindEntities(x,0,z,math.max(large,small),nil,{"INLIMBO"},{"shadecanopy","shadecanopysmall"})) do
        local alive=not tree._hascanopy or tree._hascanopy:value()
        local range=tree:HasTag("shadecanopysmall") and small or large
        local tx,ty,tz=tree.Transform:GetWorldPosition()
        if alive and (tree:HasTag("shadecanopy") or tree:HasTag("shadecanopysmall")) and (tx-x)^2+(tz-z)^2<=range*range then return true end
    end
    return false
end
return M
