local M={}
local causes={"salt","flood","dry"}
-- Tint the native sinkhole's grey soil fill as well as its crack artwork.
-- Dark strokes remain dark; the fill now follows each damage material.
local crack_colours={dry={0.78,0.62,0.34},flood={0.27,0.32,0.50},salt={0.62,0.72,0.74}}
function M.TintCracks(inst,cause,alpha)
    if type(cause)=="number" then cause=causes[cause] end
    local colour=crack_colours[cause] or {1,1,1}
    inst.AnimState:SetMultColour(colour[1],colour[2],colour[3],alpha or 1)
end
local spot_colours = {
    salt={1,1,1,0.85},
    flood={0.34,0.39,0.48,0.12},
    dry={0.78,0.62,0.36,0.34},
}
function M.Assets()
    return {Asset("ANIM","anim/farm_soil_moisture.zip")}
end
function M.Fit(parent,ground,scale)
    ground.Transform:SetScale(scale,scale,scale)
    if parent.Transform and parent.Transform.GetWorldPosition then
        ground.Transform:SetPosition(parent.Transform:GetWorldPosition())
    end
end
function M.Apply(parent,ground,cause,alpha,scale)
    if type(cause)=="number" then cause=causes[cause] end
    local colour=spot_colours[cause] or spot_colours.dry
    ground.AnimState:SetMultColour(colour[1],colour[2],colour[3],cause and (alpha or 1) or 0)
    ground.AnimState:SetAddColour(colour[1]*colour[4],colour[2]*colour[4],colour[3]*colour[4],0)
    M.Fit(parent,ground,scale or 1)
end
function M.Create(parent,cause)
    local ground=CreateEntity()
    ground.entity:AddTransform()
    ground.entity:AddAnimState()
    ground.AnimState:SetBank("farm_soil_moisture")
    ground.AnimState:SetBuild("farm_soil_moisture")
    ground.AnimState:SetPercent("anim",1)
    ground.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
    ground.AnimState:SetLayer(LAYER_BACKGROUND)
    ground.AnimState:SetSortOrder(6)
    ground:AddTag("FX")
    ground:AddTag("NOCLICK")
    ground.persists=false
    M.Apply(parent,ground,cause,0)
    return ground
end
return M
