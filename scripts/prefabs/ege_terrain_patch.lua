local assets={Asset("ANIM","anim/ege_terrain_flood.zip"),Asset("ANIM","anim/ege_terrain_dry.zip"),Asset("ANIM","anim/ege_terrain_salt.zip")}
local function fn()
    local inst=CreateEntity()
    inst.entity:AddTransform();inst.entity:AddAnimState();inst.entity:AddNetwork()
    inst.AnimState:SetBank("ege_terrain");inst.AnimState:SetBuild("ege_terrain_dry")
    inst.AnimState:PlayAnimation("idle",true)
    inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
    inst.AnimState:SetLayer(LAYER_BACKGROUND);inst.AnimState:SetSortOrder(6)
    inst:AddTag("FX");inst:AddTag("NOCLICK");inst:AddTag("NOBLOCK")
    inst.entity:SetPristine();inst.persists=false
    return inst
end
return Prefab("ege_terrain_patch",fn,assets)
