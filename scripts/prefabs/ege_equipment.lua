require("prefabutil")
local Water = require("ege_water")
local assets={Asset("ANIM","anim/ege_magic_sprinkler.zip"),Asset("ANIM","anim/sprinkler.zip"),Asset("ANIM","anim/sprinkler_meter.zip"),
    Asset("ATLAS","images/ege_magic_sprinkler.xml"),Asset("IMAGE","images/ege_magic_sprinkler.tex"),
    Asset("ANIM","anim/sprinkler_fx.zip"),Asset("ANIM","anim/sprinkler_pipes.zip"),
    Asset("ANIM","anim/sandbag_small.zip"),Asset("ANIM","anim/sandbag.zip"),Asset("ANIM","anim/diseasecurebomb.zip"),
    Asset("ANIM","anim/ui_wortox_souljar_1x1.zip"),
    Asset("ANIM","anim/gems.zip"),Asset("ANIM","anim/alterguardianhatshard.zip"),
    Asset("ATLAS","images/ege_moonoil.xml"),Asset("IMAGE","images/ege_moonoil.tex")}
local function Base(bank,anim,tags,build)
    local inst=CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()
    inst.AnimState:SetBank(bank)
    inst.AnimState:SetBuild(build or bank)
    inst.AnimState:PlayAnimation(anim,true)
    for _,tag in ipairs(tags or {}) do inst:AddTag(tag) end
    return inst
end
local function RetractPipes(inst)
    if inst.ege_retract_started then return end
    inst.ege_retract_started=true
    local valid={}
    for _,pipe in ipairs(inst.pipes or {}) do
        if pipe:IsValid() then valid[#valid+1]=pipe end
    end
    for i,pipe in ipairs(valid) do
        pipe._prev=valid[i-1]
        pipe._next=nil
        -- This task belongs to the pipe, not the destroyed sprinkler.
        pipe.ege_cleanup=pipe:DoTaskInTime(#valid*2+2,function(entity)
            if entity:IsValid() then entity:Remove() end
        end)
    end
    local last=valid[#valid]
    if last then
        if last.sg then last.sg:GoToState("retract")
        else for _,pipe in ipairs(valid) do pipe:Remove() end end
    end
    inst.pipes={}
    inst.pipepoint=nil
end
local function Workable(inst,loot)
    inst:AddComponent("inspectable")
    inst:AddComponent("lootdropper")
    -- Fixed hammer loot must not be added to the automatic recipe refund.
    inst.components.lootdropper.droprecipeloot=false
    inst.components.lootdropper:SetLoot(loot)
    inst:AddComponent("workable")
    inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
    inst.components.workable:SetWorkLeft(3)
    inst.components.workable:SetOnFinishCallback(function(entity)
        RetractPipes(entity)
        if entity.components.container then entity.components.container:DropEverything() end
        entity.components.lootdropper.droprecipeloot=false
        entity.components.lootdropper:DropLoot()
        entity:Remove()
    end)
end
local function ClearSprayTargets(inst)
    for _,ent in pairs(inst.moisture_targets or {}) do
        if ent:IsValid() then
            if ent.components.moisture then ent.components.moisture:RemoveRateBonus(inst) end
            if ent.components.moistureoverride then ent.components.moistureoverride:RemoveAddMoisture(inst) end
        end
    end
    inst.moisture_targets={}
end
local function UpdateSprayColour(inst,fresh_fraction)
    if not inst.water_spray then return end
    local desal=inst.components.ege_desalinator
    if fresh_fraction==nil then
        fresh_fraction=inst.ege_water_source~="sea" and 1
            or desal and (desal:HasShard() or desal.remaining>0) and 1 or 0
    end
    local sea=1-fresh_fraction
    inst.water_spray.AnimState:SetMultColour(1-0.35*sea,1-0.15*sea,1,1)
end
local function Spray(inst)
    if not inst.components.machine:IsOn() then return end
    UpdateSprayColour(inst)
    local map,manager=TheWorld.Map,TheWorld.components.farming_manager
    local x,y,z=inst.Transform:GetWorldPosition()
    local previous=inst.moisture_targets
    inst.moisture_targets={}
    local tick=0.2
    local delta=TUNING.MOISTURE_SPRINKLER_PERCENT_INCREASE_PER_SPRAY or 0.5
    for _,ent in ipairs(TheSim:FindEntities(x,y,z,8,nil,{"INLIMBO","FX","NOBLOCK","NOCLICK"})) do
        if ent~=inst then
            inst.moisture_targets[ent.GUID]=ent
            if ent.components.moisture then
                ent.components.moisture:AddRateBonus(inst,delta/tick)
            elseif ent.components.inventoryitemmoisture then
                ent.components.inventoryitemmoisture:DoDelta(delta)
            elseif ent.components.moistureoverride then
                ent.components.moistureoverride:SetAddMoisture(inst,delta/tick)
            else
                -- Use the vanilla wetting helper where the Cloud component is absent.
                DoDeltaMoistureToEntity(ent,delta)
            end
            if ent.components.crop and ent.components.crop.task then ent.components.crop:DoGrow(tick) end
            if ent.components.burnable then ent.components.burnable:Extinguish() end
        end
    end
    for guid,ent in pairs(previous) do
        if not inst.moisture_targets[guid] and ent:IsValid() then
            if ent.components.moisture then ent.components.moisture:RemoveRateBonus(inst) end
            if ent.components.moistureoverride then ent.components.moistureoverride:RemoveAddMoisture(inst) end
        end
    end
    if inst.components.ege_desalinator then inst.components.ege_desalinator:RefreshVisual() end
    inst.SoilMoistureTask=inst.SoilMoistureTask+1
    if inst.SoilMoistureTask>10 then
        -- Preserve the patch's point sampling, including repeated water per tile.
        if manager then
            local points={}
            for i=x-6.5,x+6.5 do for j=z-6.5,z+6.5 do
                if map:GetTileAtPoint(i,0,j)==WORLD_TILES.FARMING_SOIL then
                    points[#points+1]={i,j}
                end
            end end
            local fresh=inst.ege_water_source=="sea" and 0 or 1
            if inst.ege_water_source=="sea" and inst.components.ege_desalinator then
                fresh=inst.components.ege_desalinator:Process(2)
            end
            UpdateSprayColour(inst,fresh)
            for _,point in ipairs(points) do
                if fresh<1 then manager:AddSoilMoistureAtPoint(point[1],0,point[2],0.05*(1-fresh),"ege_sea") end
                if fresh>0 then manager:AddSoilMoistureAtPoint(point[1],0,point[2],0.05*fresh,"ege_fresh") end
            end
        end
        for _,ent in pairs(inst.moisture_targets) do
            if ent.components.burnable and ent.components.witherable then
                ent.components.witherable:Protect(TUNING.WATERINGCAN_PROTECTION_TIME)
            end
        end
        inst.SoilMoistureTask=1
    end
end
local function CreatePipes(inst,point)
    if point and inst.pipepoint and inst.pipepoint.x==point.x and inst.pipepoint.z==point.z
        and inst.pipes[1] and inst.pipes[1]:IsValid() then return end
    for _,pipe in ipairs(inst.pipes or {}) do if pipe:IsValid() then pipe:Remove() end end
    inst.pipes={}
    inst.pipepoint=point
    if not point then return end
    local x,y,z=inst.Transform:GetWorldPosition()
    local dx,dz=point.x-x,point.z-z
    local distance=math.sqrt(dx*dx+dz*dz)
    -- Include the first full segment at/beyond the intake, rather than
    -- stopping with the final segment's origin on the landward side.
    local sea=TheWorld.Map:IsOceanTileAtPoint(point.x,0,point.z)
    local segments=math.floor(distance/2)+(sea and 1 or 0)
    local angle=math.atan2(-dz,dx)/DEGREES-90
    for i=0,segments do
        local pipe=SpawnPrefab("ege_water_pipe")
        if pipe then
            local t=distance>0 and 2*i/distance or 0
            pipe.Transform:SetPosition(x+dx*t,0,z+dz*t)
            pipe.Transform:SetRotation(angle)
            inst.pipes[#inst.pipes+1]=pipe
        end
    end
    for i,pipe in ipairs(inst.pipes) do
        pipe._prev=inst.pipes[i-1]
        pipe._next=inst.pipes[i+1]
        if inst.loaded then pipe.sg:GoToState("idle") end
    end
    if not inst.loaded and inst.pipes[1] then inst.pipes[1].sg:GoToState("extend",1) end
end
local function sprinklerfn(magic)
    local inst=Base("sprinkler","idle_off",{"structure","machine"})
    inst.ege_magic=magic==true
    inst.AnimState:Hide("snow")
    if magic then
        inst:AddTag("ege_magic_sprinkler")
        inst.AnimState:SetBuild("ege_magic_sprinkler")
        for _,symbol in ipairs({"spinner_01","spinner_02","spinner_03","sidecrank","sidepipe","top","shdw"}) do
            inst.AnimState:OverrideSymbol(symbol,"sprinkler",symbol)
        end
    end
    MakeObstaclePhysics(inst,0.5)
    inst.AnimState:OverrideSymbol("swap_meter","sprinkler_meter","10")
    if magic then
        inst.OnEntityReplicated=function(entity)
            if entity.replica.container then entity.replica.container:WidgetSetup("ege_magic_sprinkler") end
        end
    end
    inst.entity:SetPristine()
    if not TheWorld.ismastersim then return inst end
    -- Hammer refunds half the crafting cost per ingredient, rounded down.
    local function UpdateSnow(entity,covered)
        if covered then entity.AnimState:Show("snow") else entity.AnimState:Hide("snow") end
    end
    UpdateSnow(inst,TheWorld.state.issnowcovered)
    inst:WatchWorldState("issnowcovered",UpdateSnow)
    Workable(inst,magic and {"gears","bluegem","bluegem","livinglog"} or {"gears","goldnugget","goldnugget","boards"})
    inst.components.inspectable.descriptionfn=function(entity)
        if not Water.CanBuild(entity:GetPosition()) then return "附近20范围内没有可用水源。绿洲只在夏季供水。" end
        local desal=entity.components.ege_desalinator
        if not desal then
            return string.format("燃料：%.2f%%。抽取海水会使农田积盐。",entity.components.fueled:GetPercent()*100)
        end
        local status=desal:HasShard() and "启迪碎片：持续淡化，不消耗。"
            or string.format("蓝宝石淡化余时：%.0f秒（%s）。",math.ceil(desal.remaining),
                not entity.components.machine:IsOn() and "已停机，暂停计时"
                or entity.ege_water_source~="sea" and "淡水供水，暂停计时"
                or "海水淡化中，每2秒扣除")
        return string.format("燃料：%.2f%%。右键开关机器，打开容器可更换淡化材料。\n%s",entity.components.fueled:GetPercent()*100,status)
    end
    inst.moisture_targets={}
    inst.pipes={}
    inst.OnLoad=function(entity) entity.loaded=true end
    inst.UpdateSpray=Spray
    inst.UpdateSprayColour=UpdateSprayColour
    inst.SoilMoistureTask=0
    inst:AddComponent("watersource")
    inst.components.watersource.available=false
    inst:AddComponent("fueled")
    inst.components.fueled.fueltype=FUELTYPE.BURNABLE
    inst.components.fueled:SetSections(10)
    inst.components.fueled:SetSectionCallback(function(newsection,oldsection,entity)
        entity.AnimState:OverrideSymbol("swap_meter","sprinkler_meter",tostring(entity.components.fueled:GetCurrentSection()))
    end)
    inst.components.fueled:InitializeFuelLevel(TUNING.TOTAL_DAY_TIME*3)
    inst.components.fueled:SetUpdateFn(function(entity)
        entity.AnimState:OverrideSymbol("swap_meter","sprinkler_meter",tostring(entity.components.fueled:GetCurrentSection()))
    end)
    inst.components.fueled.accepting=true
    inst.components.fueled.bonusmult=5
    inst.components.fueled.secondaryfueltype=FUELTYPE.CHEMICAL
    inst.components.fueled:SetDepletedFn(function() inst.components.machine:TurnOff() end)
    inst:AddComponent("machine")
    if magic then
        -- Both variants keep the native machine toggle; the container remains available.
        inst:AddComponent("container")
        inst.components.container:WidgetSetup("ege_magic_sprinkler")
        inst:AddComponent("ege_desalinator")
        inst.magic_core=SpawnPrefab("ege_sprinkler_core")
        inst.magic_shard_core=SpawnPrefab("ege_sprinkler_shard_core")
        if inst.magic_core then
            inst.magic_core.entity:AddFollower():FollowSymbol(inst.GUID,"top",0,-20,0)
            inst.magic_core.shard_core=inst.magic_shard_core
        end
        if inst.magic_shard_core then
            inst.magic_shard_core.entity:AddFollower():FollowSymbol(inst.GUID,"top",0,-20,0)
        end
        inst:ListenForEvent("itemget",function(entity) entity.components.ege_desalinator:RefreshVisual() end)
        inst:ListenForEvent("itemlose",function(entity) entity.components.ege_desalinator:RefreshVisual() end)
        inst.components.ege_desalinator:RefreshVisual()
    end
    local original_turnon=inst.components.machine.TurnOn
    inst.components.machine.TurnOn=function(machine)
        local source,point=Water.FindSource(inst:GetPosition())
        if inst.components.fueled:IsEmpty() or not source then
            machine:TurnOff()
            return false
        end
        inst.ege_water_source=source
        CreatePipes(inst,point)
        original_turnon(machine)
        if inst.components.ege_desalinator then inst.components.ege_desalinator:RefreshVisual() end
        return true
    end
    inst.components.machine.turnonfn=function(entity)
        entity.SoundEmitter:PlaySound("everygrain_DLC003/common/crafted/sprinkler/on")
        entity.SoundEmitter:KillSound("ege_sprinkler_working")
        entity.SoundEmitter:PlaySound("everygrain_DLC003/common/crafted/sprinkler/working","ege_sprinkler_working")
        entity.AnimState:PlayAnimation("launch",true)
        entity.components.fueled:StartConsuming()
        entity.components.watersource.available=true
        if not entity.water_spray then
            entity.water_spray=SpawnPrefab("ege_water_spray")
            local follower=entity.water_spray.entity:AddFollower()
            follower:FollowSymbol(entity.GUID,"top",0,-100,0)
        end
        UpdateSprayColour(entity)
        if not entity.spraytask then entity.spraytask=entity:DoPeriodicTask(0.2,Spray,0) end
    end
    inst.components.machine.turnofffn=function(entity)
        entity.SoundEmitter:KillSound("ege_sprinkler_working")
        if entity.spraytask then entity.SoundEmitter:PlaySound("everygrain_DLC003/common/crafted/sprinkler/off") end
        entity.AnimState:PlayAnimation("idle_off",true)
        entity.components.fueled:StopConsuming()
        entity.components.watersource.available=false
        if entity.spraytask then entity.spraytask:Cancel(); entity.spraytask=nil end
        if entity.water_spray then entity.water_spray:Remove(); entity.water_spray=nil end
        ClearSprayTargets(entity)
        if entity.components.ege_desalinator then entity.components.ege_desalinator:RefreshVisual() end
    end
    inst:WatchWorldState("issummer",function(entity,issummer)
        if not issummer and entity.ege_water_source == "oasis" then
            entity.components.machine:TurnOff()
        end
    end)
    inst:DoTaskInTime(0.1,function(entity)
        if #entity.pipes==0 then
            local kind,point=Water.FindSource(entity:GetPosition())
            CreatePipes(entity,point)
        end
    end)
    inst:ListenForEvent("onremove",function(entity)
        entity.SoundEmitter:KillSound("ege_sprinkler_working")
        ClearSprayTargets(entity)
        if entity.water_spray then entity.water_spray:Remove() end
        if entity.magic_core and entity.magic_core:IsValid() then entity.magic_core:Remove() end
        if entity.magic_shard_core and entity.magic_shard_core:IsValid() then entity.magic_shard_core:Remove() end
        RetractPipes(entity)
    end)
    return inst
end
local function corefn()
    local inst=Base("gems","bluegem_idle",{"FX","NOCLICK","NOBLOCK"})
    inst.Transform:SetScale(0.5,0.5,0.5)
    inst.AnimState:SetLightOverride(0.1)
    inst.AnimState:SetFinalOffset(2)
    inst.entity:SetPristine()
    inst.persists=false
    if not TheWorld.ismastersim then return inst end
    inst.SetCore=function(entity,shard,active)
        -- Keep each animation in its own bank; swapping banks while a different
        -- bank's animation is playing generates missing-animation warnings.
        entity.shard=shard
        if shard then entity:Hide() else entity:Show() end
        if entity.shard_core and entity.shard_core:IsValid() then
            if shard then entity.shard_core:Show() else entity.shard_core:Hide() end
            entity.shard_core.AnimState:SetLightOverride(active and 0.7 or 0.1)
        end
        entity.AnimState:SetLightOverride(active and 0.7 or 0.1)
        entity.AnimState:SetAddColour(0,0,0,0)
    end
    return inst
end
local function shardcorefn()
    local inst=Base("alterguardianhatshard","idle",{"FX","NOCLICK","NOBLOCK"})
    inst.Transform:SetScale(0.65,0.65,0.65)
    inst.AnimState:SetLightOverride(0.1)
    inst.AnimState:SetFinalOffset(2)
    inst:Hide()
    inst.entity:SetPristine()
    inst.persists=false
    return inst
end
local function pipefn()
    local inst=Base("sprinkler_pipes","idle",{"NOCLICK","NOBLOCK","FX"})
    inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
    inst.AnimState:SetLayer(LAYER_BACKGROUND)
    inst.AnimState:SetSortOrder(3)
    for i=1,3 do inst.AnimState:Hide("joint"..i); inst.AnimState:Hide("pipe"..i) end
    inst.AnimState:Show("joint"..math.random(1,3))
    inst.AnimState:Show("pipe"..math.random(1,3))
    inst.entity:SetPristine()
    inst.persists=false
    if TheWorld.ismastersim then inst:SetStateGraph("SGege_water_pipe") end
    return inst
end
local function sprayfn()
    local inst=Base("sprinkler_fx","spray_loop",{"FX","NOCLICK"})
    inst.entity:SetPristine()
    inst.persists=false
    return inst
end
return Prefab("ege_sprinkler",function() return sprinklerfn(false) end,assets),
    Prefab("ege_water_pipe",pipefn,assets),
    Prefab("ege_water_spray",sprayfn,assets),
    Prefab("ege_magic_sprinkler",function() return sprinklerfn(true) end,assets,{"ege_sprinkler_core","ege_sprinkler_shard_core","ege_water_pipe","ege_water_spray"}),
    Prefab("ege_sprinkler_core",corefn,assets),
    Prefab("ege_sprinkler_shard_core",shardcorefn,assets),
    MakePlacer("ege_sprinkler_placer","sprinkler","sprinkler","idle_off"),
    MakePlacer("ege_magic_sprinkler_placer","sprinkler","ege_magic_sprinkler","idle_off",false,false,false,1,nil,nil,function(inst)
        inst.AnimState:SetBuild("ege_magic_sprinkler")
        for _,symbol in ipairs({"spinner_01","spinner_02","spinner_03","sidecrank","sidepipe","top","shdw"}) do
            inst.AnimState:OverrideSymbol(symbol,"sprinkler",symbol)
        end
    end)
