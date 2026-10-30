local Terrain=require("ege_terrain_visual")
local R=require("ege_rules")
local assets={Asset("ANIM","anim/antlion_sinkhole.zip"),Asset("ANIM","anim/salt.zip"),Asset("ANIM","anim/farm_soil.zip")}
for _,asset in ipairs(Terrain.Assets()) do assets[#assets+1]=asset end
local function UpdateDebris(inst)
    for _,chip in ipairs(inst.debris or {}) do if chip:IsValid() then chip:Remove() end end
    inst.debris={}
    local cause=inst._cause:value()
    Terrain.TintCracks(inst,cause,1)
    if not inst.terrain then inst.terrain=Terrain.Create(inst,cause) end
    Terrain.Apply(inst,inst.terrain,cause,cause>0 and 1 or 0)
    if cause~=1 then return end
    for i=1,7 do
        local chip=CreateEntity()
        chip.entity:AddTransform(); chip.entity:AddAnimState()
        chip.entity:SetParent(inst.entity)
        local angle=i*2.399963
        local radius=0.4+0.22*(i%5)
        chip.Transform:SetPosition(math.cos(angle)*radius,0,math.sin(angle)*radius)
        if cause==1 then
            chip.AnimState:SetBank("salt"); chip.AnimState:SetBuild("salt")
            chip.AnimState:PlayAnimation("idle",true)
            chip.Transform:SetScale(0.5,0.5,0.5)
            chip.AnimState:SetAddColour(0.2,0.2,0.2,0)
        else
            chip.AnimState:SetBank("farm_soil"); chip.AnimState:SetBuild("farm_soil")
            chip.AnimState:PlayAnimation("collapse_idle",true)
            chip.Transform:SetScale(0.65,0.4,0.65)
            chip.AnimState:SetMultColour(0.35,0.28,0.18,0.9)
        end
        chip.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
        chip.AnimState:SetLayer(LAYER_WORLD_BACKGROUND); chip.AnimState:SetSortOrder(8)
        chip:AddTag("FX"); chip:AddTag("NOCLICK"); chip:AddTag("NOBLOCK")
        chip.persists=false
        inst.debris[#inst.debris+1]=chip
    end
end
local function fn()
    local inst=CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()
    inst.AnimState:SetBank("sinkhole")
    inst.AnimState:SetBuild("antlion_sinkhole")
    inst.AnimState:PlayAnimation("idle",true)
    inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
    inst.AnimState:SetLayer(LAYER_WORLD_BACKGROUND)
    inst.AnimState:SetSortOrder(7)
    inst.Transform:SetScale(1,1,1)
    inst:AddTag("ege_ruined_field")
    inst:AddTag("NOBLOCK")
    inst._cause=net_tinybyte(inst.GUID,"ege_ruined_field.cause","egecausedirty")
    inst.entity:SetPristine()
    if not TheNet:IsDedicated() then
        inst:DoTaskInTime(0,UpdateDebris)
        inst:ListenForEvent("egecausedirty",UpdateDebris)
        inst:ListenForEvent("onremove",function(entity)
            if entity.terrain and entity.terrain:IsValid() then entity.terrain:Remove() end
            for _,chip in ipairs(entity.debris or {}) do if chip:IsValid() then chip:Remove() end end
        end)
    end
    if not TheWorld.ismastersim then return inst end
    local function RestoreGround(entity)
        if entity.original_ground~=nil then
            local x,y,z=entity.Transform:GetWorldPosition()
            local tx,tz=TheWorld.Map:GetTileCoordsAtPoint(x,0,z)
            if TheWorld.Map:GetTile(tx,tz)==(entity.damaged_ground or WORLD_TILES.MARSH) then
                TheWorld.Map:SetTile(tx,tz,entity.original_ground)
            end
        end
    end
    inst.SetCause=function(entity,cause)
        entity._cause:set(cause=="salt" and 1 or cause=="flood" and 2 or cause=="dry" and 3 or 0)
        if not TheNet:IsDedicated() then UpdateDebris(entity) end
    end
    inst:AddComponent("inspectable")
    inst.components.inspectable.descriptionfn=function(entity)
        return string.format("土地已毁坏，需休耕约%.1f天才能重新开垦。",entity.remaining/TUNING.TOTAL_DAY_TIME)
    end
    local tuning=TUNING.ANTLION_SINKHOLE or {}
    local times=tuning.REPAIR_TIME or {4*TUNING.TOTAL_DAY_TIME,5*TUNING.TOTAL_DAY_TIME,21*TUNING.TOTAL_DAY_TIME}
    local variance=tuning.REPAIR_TIME_VARIANCE or TUNING.TOTAL_DAY_TIME
    inst.repairtimes={}
    for i=1,3 do inst.repairtimes[i]=(times[i]+math.random()*variance)*0.5 end
    inst.remaining=inst.repairtimes[1]+inst.repairtimes[2]+inst.repairtimes[3]
    local function Refresh(entity)
        local stage=entity.remaining>entity.repairtimes[1]+entity.repairtimes[2] and 3
            or entity.remaining>entity.repairtimes[1] and 2 or 1
        entity.ege_visual_stage=stage
        if stage==3 then entity.AnimState:ClearOverrideSymbol("cracks1")
        else entity.AnimState:OverrideSymbol("cracks1","antlion_sinkhole","cracks_pre"..stage) end
    end
    local function advance(entity,dt)
        entity.remaining=math.max(0,entity.remaining-dt)
        if entity.remaining<=0 then entity:Remove() else Refresh(entity) end
    end
    inst.StartCollapse=function(entity)
        for stage=1,3 do
            entity:DoTaskInTime(stage-1,function(e)
                if stage<3 then e.AnimState:OverrideSymbol("cracks1","antlion_sinkhole","cracks_pre"..stage)
                else e.AnimState:ClearOverrideSymbol("cracks1") end
            end)
        end
    end
    inst:DoPeriodicTask(5,function(entity) advance(entity,5) end)
    inst.OnLongUpdate=advance
    inst.OnSave=function(entity,data)
        data.recovery_scale=0.5
        data.remaining=entity.remaining
        data.repairtimes=entity.repairtimes
        data.cause=entity._cause:value()
    end
    inst.OnLoad=function(entity,data)
        if data then
            entity.original_ground=data.original_ground
            entity.damaged_ground=data.damaged_ground
            -- One-time migration: undo the removed terrain replacement for old ruins.
            -- Leave tiles changed independently by the player or other mods intact.
            RestoreGround(entity)
            entity.original_ground=nil
            entity.damaged_ground=nil
            entity:SetCause(data.cause==1 and "salt" or data.cause==2 and "flood" or (data.cause==0 or data.cause==3) and "dry" or "unknown")
            entity.repairtimes,entity.remaining=R.RuinRecovery(data,entity.repairtimes)
        end
        -- Older versions could spawn a ruin even when Terraform returned false.
        local x,y,z=entity.Transform:GetWorldPosition()
        require("ege_farmland").Clear(TheWorld.Map,TheWorld.components.undertile,x,z)
        advance(entity,0)
    end
    return inst
end
return Prefab("ege_ruined_field",fn,assets)
