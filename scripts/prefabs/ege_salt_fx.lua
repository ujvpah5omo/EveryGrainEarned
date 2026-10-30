-- Cosmetic salt crust: one networked root; small vanilla salt sprites are local.
local assets={Asset("ANIM","anim/salt.zip"),Asset("ANIM","anim/farm_soil_moisture.zip")}
local function UpdateVisual(inst)
    local level=inst._level:value()
    if level>0 then inst.shownlevel=level end
    local target=level>0 and 0.65+0.1*level or 0
    local delta=target-inst.opacity
    inst.opacity=inst.opacity+math.max(-0.1,math.min(0.1,delta))
    if inst.crust then
        local strength=(inst.shownlevel or 1)*0.13+0.15
        inst.crust.AnimState:SetMultColour(1,1,1,inst.opacity*strength)
    end
    for i,chip in ipairs(inst.chips or {}) do
        if i<=6+4*(inst.shownlevel or 1) and inst.opacity>0.001 then
            chip:Show()
            chip.AnimState:SetMultColour(1,1,1,inst.opacity)
        else chip:Hide() end
    end
end
local function CreateCrystals(inst)
    inst.chips={}
    for i=1,18 do
        local chip=CreateEntity()
        chip.entity:AddTransform()
        chip.entity:AddAnimState()
        chip.entity:SetParent(inst.entity)
        local angle=i*2.399963
        local radius=0.3+0.65*((i*7)%11)/10
        chip.Transform:SetPosition(math.cos(angle)*radius,0.015,math.sin(angle)*radius)
        chip.Transform:SetRotation(i*53)
        local size=0.5+0.07*(i%3)
        chip.Transform:SetScale(size,size,size)
        chip.AnimState:SetBank("salt")
        chip.AnimState:SetBuild("salt")
        chip.AnimState:PlayAnimation("idle",true)
        chip.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
        chip.AnimState:SetLayer(LAYER_BACKGROUND)
        chip.AnimState:SetSortOrder(7)
        chip.AnimState:SetAddColour(0.25,0.25,0.25,0)
        chip.AnimState:SetFinalOffset(0)
        chip:AddTag("FX")
        chip:AddTag("NOCLICK")
        chip:AddTag("NOBLOCK")
        chip.persists=false
        chip:Hide()
        inst.chips[#inst.chips+1]=chip
    end
    local crust=CreateEntity()
    crust.entity:AddTransform();crust.entity:AddAnimState()
    crust.entity:SetParent(inst.entity)
    crust.Transform:SetScale(1/1.8,1,1/1.8)
    crust.AnimState:SetBank("farm_soil_moisture")
    crust.AnimState:SetBuild("farm_soil_moisture")
    crust.AnimState:SetPercent("anim",1)
    crust.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
    crust.AnimState:SetLayer(LAYER_BACKGROUND);crust.AnimState:SetSortOrder(6)
    crust.AnimState:SetAddColour(0.85,0.85,0.85,0)
    crust.AnimState:SetMultColour(1,1,1,0)
    crust:AddTag("FX");crust:AddTag("NOCLICK");crust.persists=false
    inst.crust=crust
    inst.opacity=0
    inst:DoPeriodicTask(0.1,UpdateVisual)
end
local function fn()
    local inst=CreateEntity()
    inst.entity:AddTransform()
    -- Give the replicated root a drawable crystal, instead of relying entirely
    -- on local child decorations attached to a root with no render bounds.
    inst.entity:AddAnimState()
    inst.AnimState:SetBank("salt")
    inst.AnimState:SetBuild("salt")
    inst.AnimState:PlayAnimation("idle",true)
    inst.AnimState:SetLayer(LAYER_BACKGROUND)
    inst.AnimState:SetSortOrder(7)
    inst.AnimState:SetAddColour(0.35,0.35,0.35,0)
    inst.AnimState:SetMultColour(1,1,1,0)
    inst.entity:AddNetwork()
    inst:AddTag("FX")
    inst:AddTag("NOCLICK")
    inst:AddTag("NOBLOCK")
    inst._level=net_tinybyte(inst.GUID,"ege_salt_fx.level","saltleveldirty")
    inst.entity:SetPristine()
    inst.persists=false
    if not TheNet:IsDedicated() then
        inst:DoTaskInTime(0,CreateCrystals)
        inst:ListenForEvent("onremove",function()
            if inst.crust and inst.crust:IsValid() then inst.crust:Remove() end
            for _,chip in ipairs(inst.chips or {}) do if chip:IsValid() then chip:Remove() end end
        end)
    end
    if not TheWorld.ismastersim then return inst end
    inst.SetLevel=function(entity,level)
        level=math.max(0,math.min(3,level))
        entity._level:set(level)
        entity.AnimState:SetMultColour(1,1,1,level>0 and 0.9 or 0)
    end
    return inst
end
return Prefab("ege_salt_fx",fn,assets)
