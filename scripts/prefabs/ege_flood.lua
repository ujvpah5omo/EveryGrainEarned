-- A separate networked ground overlay preserves the underlying farmland.
local assets = {Asset("ANIM","anim/ege_terrain_ice.zip"),Asset("ANIM","anim/farm_soil_moisture.zip"),Asset("ANIM","anim/farm_soil_moisture_flood.zip"),
    Asset("ANIM","anim/ia_wave_shimmer_flood.zip"),
    Asset("SHADER","shaders/farm_soil_moisture_flood.ksh")}
local SHADER = resolvefilepath("shaders/farm_soil_moisture_flood.ksh")
local function AddRipples(inst)
    if inst.ripples then return end
    inst.ripples={}
    for _,offset in ipairs({{-0.9,-0.7},{0.8,0.6},{-0.6,0.9}}) do
        -- Local decoration: no additional network traffic per flooded tile.
        local fx=CreateEntity()
        fx.entity:AddTransform()
        fx.entity:AddAnimState()
        fx.entity:SetParent(inst.entity)
        fx.Transform:SetPosition(offset[1],0.02,offset[2])
        fx.Transform:SetScale(0.85,0.85,0.85)
        fx.AnimState:SetBank("ia_wave_shimmer_flood")
        fx.AnimState:SetBuild("ia_wave_shimmer_flood")
        fx.AnimState:PlayAnimation("idle",true)
        fx.AnimState:SetTime(math.random()*fx.AnimState:GetCurrentAnimationLength())
        fx.AnimState:SetLayer(LAYER_BACKGROUND)
        fx.AnimState:SetSortOrder(4)
        fx.AnimState:SetFinalOffset(2)
        fx:AddTag("FX")
        fx:AddTag("NOCLICK")
        fx:AddTag("NOBLOCK")
        fx.persists=false
        inst.ripples[#inst.ripples+1]=fx
    end
end
local function UpdateDepth(inst)
    local depth=math.max(1,inst._depth:value())
    local frozen=inst._frozen:value()
    -- User-selected grey scratch ice: preserve this artwork and enlarge only its visual extent.
    if frozen and not inst.ice then
        local ice=CreateEntity()
        ice.entity:AddTransform();ice.entity:AddAnimState()
        ice.entity:SetParent(inst.entity)
        ice.Transform:SetScale(1.2,1.2,1.2)
        ice.AnimState:SetBank("ege_terrain");ice.AnimState:SetBuild("ege_terrain_ice")
        ice.AnimState:PlayAnimation("idle",true)
        ice.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
        ice.AnimState:SetLayer(LAYER_BACKGROUND);ice.AnimState:SetSortOrder(4)
        ice:AddTag("FX");ice:AddTag("NOCLICK");ice.persists=false
        inst.ice=ice
    end
    if inst.ice then if frozen then inst.ice:Show() else inst.ice:Hide() end end
    if frozen then inst.AnimState:Hide("puddle_dry") else inst.AnimState:Show("puddle_dry") end
    inst.AnimState:SetMultColour(0.75,0.9,1,frozen and 0 or 0.65+depth*0.1)
    inst.AnimState:SetAddColour(0,frozen and 0 or 0.035,frozen and 0 or 0.1,0)
    for i,fx in ipairs(inst.ripples or {}) do
        if not frozen and i<=depth+1 then fx:Show() else fx:Hide() end
    end
end
local function fn()
    local inst=CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()
    inst:AddTag("slipperyfeettarget")
    inst:AddTag("FX")
    inst:AddTag("NOCLICK")
    inst.AnimState:SetBank("farm_soil_moisture")
    inst.AnimState:SetBuild("farm_soil_moisture_flood")
    inst.AnimState:SetPercent("anim",1)
    inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
    -- Draw above the vanilla soil-moisture overlay, which otherwise covers it.
    inst.AnimState:SetLayer(LAYER_BACKGROUND)
    inst.AnimState:SetSortOrder(3)
    inst.AnimState:SetFinalOffset(1)
    inst.AnimState:SetDefaultEffectHandle(SHADER)
    -- IA's bits MASK OUT flooded quadrants in the normal soil overlay.
    -- This separate water overlay must keep every quadrant visible: mask zero.
    local function UpdatePosition()
        local x,y,z=inst.Transform:GetWorldPosition()
        inst.AnimState:SetFloatParams(x,0,z)
    end
    inst:DoTaskInTime(0,UpdatePosition)
    inst:ListenForEvent("entitywake",UpdatePosition)
    inst._frozen=net_bool(inst.GUID,"ege_flood.frozen","depthdirty")
    inst._depth=net_tinybyte(inst.GUID,"ege_flood.depth","depthdirty")
    inst._depth:set(1)
    inst.entity:SetPristine()
    if not TheNet:IsDedicated() then
        inst:ListenForEvent("depthdirty",UpdateDepth)
        inst:DoTaskInTime(0,function(entity) AddRipples(entity); UpdateDepth(entity) end)
        inst:ListenForEvent("onremove",function()
            if inst.ice and inst.ice:IsValid() then inst.ice:Remove() end
            for _,fx in ipairs(inst.ripples or {}) do if fx:IsValid() then fx:Remove() end end
        end)
    end
    if not TheWorld.ismastersim then return inst end
    inst:AddComponent("slipperyfeettarget")
    inst.components.slipperyfeettarget:SetIsSlipperyAtPoint(function(entity,x,y,z)
        if not entity._frozen:value() then return false end
        local ex,ey,ez=entity.Transform:GetWorldPosition()
        local tx,tz=TheWorld.Map:GetTileCoordsAtPoint(x,0,z)
        local fx,fz=TheWorld.Map:GetTileCoordsAtPoint(ex,0,ez)
        return tx==fx and tz==fz
    end)
    inst.components.slipperyfeettarget:SetSlipperyRate(function() return 2.75 end)
    inst.SetFrozen=function(entity,frozen)
        entity._frozen:set(frozen==true)
        if not TheNet:IsDedicated() then UpdateDepth(entity) end
    end
    inst.SetWaterDepth=function(entity,water)
        local depth=water>=240 and 3 or water>=170 and 2 or 1
        if entity._depth:value()~=depth then
            entity._depth:set(depth)
            if not TheNet:IsDedicated() then UpdateDepth(entity) end
        end
    end
    inst.persists=false
    return inst
end
return Prefab("ege_flood",fn,assets)
