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
function M.Assets()
    return {Asset("ANIM","anim/ege_terrain_flood.zip"),Asset("ANIM","anim/ege_terrain_dry.zip"),Asset("ANIM","anim/ege_terrain_salt.zip")}
end
function M.Fit(parent,ground)
    -- Standalone local effect: do not inherit the crack entity's 0.65/1/0.65 scale.
    -- Match the user-approved ice sheet's animation, geometry and uniform scale.
    ground.Transform:SetScale(1.2,1.2,1.2)
    if parent.Transform and parent.Transform.GetWorldPosition then
        ground.Transform:SetPosition(parent.Transform:GetWorldPosition())
    end
end
function M.Apply(parent,ground,cause,alpha)
    if type(cause)=="number" then cause=causes[cause] end
    if cause~="salt" and cause~="flood" and cause~="dry" then alpha=0;cause="dry" end
    local build="ege_terrain_"..cause
    if ground.ege_build~=build then
        ground.ege_build=build
        ground.AnimState:SetBuild(build)
    end
    ground.AnimState:SetMultColour(1,1,1,alpha or 1)
    M.Fit(parent,ground)
end
function M.Create(parent,cause)
    local ground=CreateEntity()
    ground.entity:AddTransform();ground.entity:AddAnimState()
    ground.AnimState:SetBank("ege_terrain")
    ground.AnimState:SetBuild("ege_terrain_dry")
    ground.AnimState:PlayAnimation("idle",true)
    ground.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
    -- Ground material below cracks (WORLD_BACKGROUND), both below characters (WORLD).
    ground.AnimState:SetLayer(LAYER_BACKGROUND);ground.AnimState:SetSortOrder(6)
    ground.AnimState:SetFinalOffset(0)
    ground:AddTag("FX");ground:AddTag("NOCLICK");ground:AddTag("NOBLOCK");ground.persists=false
    M.Apply(parent,ground,cause,1)
    return ground
end
return M
