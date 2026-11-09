local Terrain=require("ege_terrain_visual")
local scales={0.8,0.9,1}
-- Match two, three, and four watering-can uses on dry soil.
local moisture_frames={0.5,0.75,1}
local function UpdateVisual(inst)
    local level=inst._level:value()
    if level>0 then inst.AnimState:SetPercent("anim",moisture_frames[level]) end
    inst.AnimState:SetScale(scales[level] or 1,scales[level] or 1)
    inst.AnimState:SetMultColour(1,1,1,level>0 and 0.5+level*0.15 or 0)
end
local function fn()
    local inst=CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()
    inst.Transform:SetRotation(90)
    inst.AnimState:SetBank("farm_soil_moisture")
    inst.AnimState:SetBuild("farm_soil_moisture")
    inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
    inst.AnimState:SetLayer(LAYER_WORLD_BACKGROUND)
    inst.AnimState:SetSortOrder(6)
    inst.AnimState:SetAddColour(0.85,0.85,0.85,0)
    inst.AnimState:SetMultColour(1,1,1,0)
    inst:AddTag("FX")
    inst:AddTag("NOCLICK")
    inst:AddTag("NOBLOCK")
    inst._level=net_tinybyte(inst.GUID,"ege_salt_fx.level","saltleveldirty")
    inst.entity:SetPristine()
    inst.persists=false
    if not TheWorld.ismastersim then return inst end
    inst.SetLevel=function(entity,level)
        entity._level:set(math.max(0,math.min(3,level)))
        UpdateVisual(entity)
    end
    return inst
end
return Prefab("ege_salt_fx",fn,Terrain.Assets())
