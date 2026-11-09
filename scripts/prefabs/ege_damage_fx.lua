-- Cosmetic only: reuse the native sinkhole crack art without its gameplay components.
local Terrain=require("ege_terrain_visual")
local assets={Asset("ANIM","anim/antlion_sinkhole.zip")}
local function Update(inst)
    local level=inst._level:value()
    if level>0 then inst.lastlevel=level end
    local stage=inst.lastlevel or 1
    local scale=stage==1 and 0.5 or 1
    inst.AnimState:SetScale(scale,scale)
    local target=level>0 and 0.58 or 0
    inst.opacity=inst.opacity+math.max(-0.1,math.min(0.1,target-inst.opacity))
    Terrain.TintCracks(inst,inst._cause:value(),inst.opacity)
end
local function fn()
    local inst=CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()
    inst.AnimState:SetBank("sinkhole")
    inst.AnimState:SetBuild("antlion_sinkhole")
    inst.AnimState:PlayAnimation("idle",true)
    inst.AnimState:OverrideSymbol("cracks1","antlion_sinkhole","cracks_pre1")
    inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
    inst.AnimState:SetLayer(LAYER_WORLD_BACKGROUND)
    inst.AnimState:SetSortOrder(7)
    inst.AnimState:SetFinalOffset(0)
    inst.AnimState:SetMultColour(1,1,1,0)
    for _,tag in ipairs({"FX","NOCLICK","NOBLOCK"}) do inst:AddTag(tag) end
    inst._level=net_tinybyte(inst.GUID,"ege_damage_fx.level","damageleveldirty")
    inst._cause=net_tinybyte(inst.GUID,"ege_damage_fx.cause","damageleveldirty")
    inst._frozen=net_bool(inst.GUID,"ege_damage_fx.frozen","damageleveldirty")
    inst.entity:SetPristine()
    inst.persists=false
    if not TheNet:IsDedicated() then
        inst.opacity=0
        inst:DoPeriodicTask(0.1,Update)
    end
    if not TheWorld.ismastersim then return inst end
    inst.SetCause=function(entity,cause) entity._cause:set(cause=="salt" and 1 or cause=="flood" and 2 or 3) end
    inst.SetFrozen=function(entity,frozen) entity._frozen:set(frozen==true) end
    inst.SetLevel=function(entity,level) entity._level:set(math.max(0,math.min(2,level))) end
    return inst
end
return Prefab("ege_damage_cracks",fn,assets)
