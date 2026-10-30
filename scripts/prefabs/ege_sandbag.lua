-- Adapted from Island Adventures sandbag.lua; standalone DST compatibility.
require "prefabutil"
local HEALTH=200
local REPAIR_MATERIAL="ege_sandbag"
local CAPACITY=300
local function SoakDamage(inst,dt)
    if inst.ege_absorbed<CAPACITY or inst.components.health:IsDead() then return end
    local fields=TheWorld.components.ege_fields
    local x,y,z=inst.Transform:GetWorldPosition()
    if fields and fields:IsFlooded(x,z) then
        inst.components.health:DoDelta(-HEALTH*dt/TUNING.TOTAL_DAY_TIME,false,"waterlogging")
    end
end
local function UpdateAbsorption(inst)
    local fill=math.max(0,math.min(1,(inst.ege_absorbed or 0)/CAPACITY))
    local full=fill>=1
    local alive=not inst.components.health or not inst.components.health:IsDead()
    if alive and not full then inst:AddTag("ege_drain") else inst:RemoveTag("ege_drain") end
    -- Two silhouettes, switching at half capacity; saturation remains 300.
    local tall=(inst.ege_absorbed or 0)>=150
    local tint=tall and 1 or 0
    inst.Transform:SetScale(1,tall and 1 or 0.45,1)
    inst.AnimState:SetMultColour(1-0.45*tint,1-0.3*tint,1-0.2*tint,1)
    if full then
        inst:AddTag("ege_saturated")
    else
        inst:RemoveTag("ege_saturated")
    end
end

--[[
    SW CHANGES:
        QOL: Now sandbags get repaired to full health instead of half with the sandbag item since the item spawns a full health sandbag anyway.
--]]

local assets =
{
    Asset("ANIM", "anim/sandbag_small.zip"),
    Asset("ANIM", "anim/sandbag.zip"),
    Asset("ATLAS", "images/ege_inventory.xml"),
    Asset("IMAGE", "images/ege_inventory.tex"),
}

local prefabs =
{
	"collapse_small",
    "ege_sandbag",
}

local function OnIsPathFindingDirty(inst)
    if inst._ispathfinding:value() then
        if inst._pfpos == nil then
            inst._pfpos = inst:GetPosition()
			TheWorld.Pathfinder:AddWall(inst._pfpos.x + 0.5, inst._pfpos.y, inst._pfpos.z + 0.5)
			TheWorld.Pathfinder:AddWall(inst._pfpos.x + 0.5, inst._pfpos.y, inst._pfpos.z - 0.5)
			TheWorld.Pathfinder:AddWall(inst._pfpos.x - 0.5, inst._pfpos.y, inst._pfpos.z + 0.5)
			TheWorld.Pathfinder:AddWall(inst._pfpos.x - 0.5, inst._pfpos.y, inst._pfpos.z - 0.5)
        end
    elseif inst._pfpos ~= nil then
		TheWorld.Pathfinder:RemoveWall(inst._pfpos.x + 0.5, inst._pfpos.y, inst._pfpos.z + 0.5)
		TheWorld.Pathfinder:RemoveWall(inst._pfpos.x + 0.5, inst._pfpos.y, inst._pfpos.z - 0.5)
		TheWorld.Pathfinder:RemoveWall(inst._pfpos.x - 0.5, inst._pfpos.y, inst._pfpos.z + 0.5)
		TheWorld.Pathfinder:RemoveWall(inst._pfpos.x - 0.5, inst._pfpos.y, inst._pfpos.z - 0.5)
        inst._pfpos = nil
    end
end

local function InitializePathFinding(inst)
    inst:ListenForEvent("onispathfindingdirty", OnIsPathFindingDirty)
    OnIsPathFindingDirty(inst)
end

local function makeobstacle(inst)
    inst.Physics:SetActive(true)
    UpdateAbsorption(inst)
    inst._ispathfinding:set(false) -- Low-profile drain bag must not reserve four wall path cells.
end

local function makefloodobstacle(inst)
	TheWorld:PushEvent("floodblockercreated",{blocker = inst})
end

local function InitializeFloodObstacle(inst)
	if not inst.components.health:IsDead() then
        makefloodobstacle(inst)
    end
end

local function clearobstacle(inst)
    inst.Physics:SetActive(false)
    inst:RemoveTag("ege_drain")
    inst._ispathfinding:set(false)
    TheWorld:PushEvent("floodblockerremoved",{blocker = inst})
end

local anims =
{
	{ threshold = 0, anim = "rubble" },
	{ threshold = 0.4, anim = "heavy_damage" },
	{ threshold = 0.5, anim = "half" },
	{ threshold = 0.99, anim = "light_damage" },
	{ threshold = 1, anim = "full" },
}

local function resolveanimtoplay(inst, percent)
    for i, v in ipairs(anims) do
        if percent <= v.threshold then
            return v.anim
        end
    end
end

local function onhealthchange(inst, old_percent, new_percent)
    inst.components.repairable:SetHealthRepairable(new_percent < 1)
    local anim_to_play = resolveanimtoplay(inst, new_percent)
	inst.AnimState:PlayAnimation(anim_to_play)
	if new_percent > 0 and old_percent <= 0 then makeobstacle(inst) makefloodobstacle(inst) end
	if old_percent > 0 and new_percent <= 0 then clearobstacle(inst) end
    UpdateAbsorption(inst)
    if new_percent<=0 and not inst.ege_destroy_task then
        local fx=SpawnPrefab("collapse_small")
        if fx then fx.Transform:SetPosition(inst.Transform:GetWorldPosition()) end
        inst.ege_destroy_task=inst:DoTaskInTime(0,inst.Remove)
    end
end

local function onload(inst,data)
    inst.ege_salt_absorbed=math.max(0,tonumber(data and data.ege_salt_absorbed) or 0)
    inst.ege_absorbed=math.max(0,math.min(CAPACITY,tonumber(data and data.ege_absorbed) or 0))
    inst.AnimState:PlayAnimation(resolveanimtoplay(inst, inst.components.health:GetPercent()))
    inst.components.repairable:SetHealthRepairable(inst.components.health:GetPercent() < 1)
    if inst.components.health:IsDead() then
        clearobstacle(inst)
        if not inst.ege_destroy_task then inst.ege_destroy_task=inst:DoTaskInTime(0,inst.Remove) end
	end
    UpdateAbsorption(inst)
end

local function onremove(inst)
    inst._ispathfinding:set_local(false)
    OnIsPathFindingDirty(inst)
	if TheWorld.ismastersim and not inst.components.health:IsDead() then
		TheWorld:PushEvent("floodblockerremoved",{blocker = inst})
	end
end

local function ToFloodGrid(num)
	-- The flood grid is is the center of a 2x2 tile pattern. So 1,3,5,7..
	num = math.floor(num)

    if num % 2 == 0 then
        num = num + 1
    end

    return num
end

local function quantizepos(pt)
    local x, y, z = pt:Get()

    local _flood = TheWorld.components.flooding
    if _flood ~= nil then
        return Vector3(_flood:GetFloodCenterPoint(x,y,z))
    else
        -- Placement outside of Shipwrecked.
        return Vector3(ToFloodGrid(x), 0, ToFloodGrid(z))
    end
end

local function quantizeplacer(inst)
    --TODO, CLEANUP CHECK how... is this working?...
	inst.Transform:SetPosition(quantizepos(inst:GetPosition()):Get())
end

local function placerpostinitfn(inst)
    inst.components.placer.onupdatetransform = quantizeplacer
    inst.components.placer.snap_to_flood = true --GEOPLACEMENT SUPPORT
end

local function ondeploy(inst, pt, deployer)
	local wall = SpawnPrefab("ege_sandbag")

	if wall then
		pt = quantizepos(pt)

		wall.Physics:SetCollides(false)
		wall.Physics:Teleport(pt.x, pt.y, pt.z)
		wall.Physics:SetCollides(true)
		inst.components.stackable:Get():Remove()

		wall.SoundEmitter:PlaySound("eg/common/sandbag")
	end
end

local function IsNearOther(other, pt, min_spacing_sq)
    --FindEntities range check is <=, but we want <
    return other:GetDistanceSqToPoint(pt.x, 0, pt.z) < (other.deploy_extra_spacing ~= nil and math.max(other.deploy_extra_spacing * other.deploy_extra_spacing, min_spacing_sq) or min_spacing_sq)
end

local function IsNearOtherWallOrPlayer(other, pt, min_spacing_sq)
    if other:HasTag("wall") or other:HasTag("player") then
        local x, y, z = other.Transform:GetWorldPosition()
        return math.floor(x) == math.floor(pt.x) and math.floor(z) == math.floor(pt.z)
    end
    return IsNearOther(other, pt, min_spacing_sq)
end

local function spacing_test_sq(inst)
    return 0.01 -- Minimal spacing; same-cell wall check still rejects overlapping bags.
end

local function test_wall(inst, pt, mouseover, deployer)
    local _world = TheWorld
    local _map = _world.Map
    local _flood = _world.components.flooding
    pt = quantizepos(pt)

    local x, y, z = pt:Get()

    local ispassable = _map:IsPassableAtPoint(x, y, z) and not _map:IsPointNearHole(pt)
    local isoverhang = false

    return ispassable and _map:IsDeployPointClear(pt, inst, 0.1, spacing_test_sq, IsNearOtherWallOrPlayer, isoverhang)
end

local function onhammered(inst, worker)
    -- User-defined hammer refund; green staff uses the crafting recipe.
    inst.components.lootdropper:SpawnLootPrefab("rocks")

	local fx = SpawnPrefab("collapse_small")
	fx.Transform:SetPosition(inst.Transform:GetWorldPosition())

	inst:Remove()
end

local function onhit(inst)
	inst.SoundEmitter:PlaySound("eg/common/sandbag")

	local healthpercent = inst.components.health:GetPercent()
	local anim_to_play = resolveanimtoplay(inst, healthpercent)
	inst.AnimState:PushAnimation(anim_to_play)
end

local function onrepaired(inst)
	inst.SoundEmitter:PlaySound("eg/common/sandbag")
	makeobstacle(inst)
    makefloodobstacle(inst)
end

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
	inst.entity:AddNetwork()

	inst.Transform:SetEightFaced()

	MakeObstaclePhysics(inst, 0.1)
	inst.Physics:SetDontRemoveOnSleep(true)

    inst:SetDeployExtraSpacing(0.1)

	inst:AddTag("floodblocker")
    inst:AddTag("ege_drain")
    inst:AddTag("structure")
	inst:AddTag("sandbag")
	inst:AddTag("wall")
	inst:AddTag("noauradamage")
	inst:AddTag("nointerpolate")
    inst:AddTag("ignorewalkableplatforms")
    inst:AddTag("electricdamageimmune")

	inst.AnimState:SetBank("sandbag_small")
	inst.AnimState:SetBuild("sandbag_small")
	inst.AnimState:PlayAnimation("full", false)

	inst.scrapbook_specialinfo = "SANDBAGS"

	inst._pfpos = nil
	inst._ispathfinding = net_bool(inst.GUID, "_ispathfinding", "onispathfindingdirty")
    makeobstacle(inst)
	--Delay this because makeobstacle sets pathfinding on by default
	--but we don't to handle it until after our position is set
	inst:DoTaskInTime(0, InitializePathFinding)

	inst.OnRemoveEntity = onremove

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

    inst:DoTaskInTime(0, InitializeFloodObstacle)

	inst:AddComponent("inspectable")
    inst.ege_absorbed=0
    inst.ege_salt_absorbed=0
    inst.RecordSalt=function(entity,amount) entity.ege_salt_absorbed=entity.ege_salt_absorbed+math.max(0,amount) end
    inst.components.inspectable.descriptionfn=function(entity)
        local remaining=math.ceil(CAPACITY-entity.ege_absorbed)
        local salt=entity.ege_salt_absorbed or 0
        local ratio=entity.ege_absorbed>0 and salt/entity.ege_absorbed or 0
        local detail=string.format("已吸水：%.1f/%d；累计吸盐：%.2f。\n袋内平均盐水比：%.4f（每100水含%.2f盐）。",entity.ege_absorbed,CAPACITY,salt,ratio,ratio*100)
        if entity.components.health:IsDead() then return "沙袋已损坏，无法吸水。\n"..detail end
        if remaining<=0 then return "沙袋已经吸满；继续浸泡会损坏，可敲掉更换。\n"..detail end
        return detail

    end
    inst.AbsorbWater=function(entity,amount)
        if entity.components.health:IsDead() then return 0 end
        local accepted=math.min(math.max(0,amount),CAPACITY-entity.ege_absorbed)
        entity.ege_absorbed=entity.ege_absorbed+accepted
        UpdateAbsorption(entity)
        return accepted
    end
    inst.OnSave=function(entity,data)
        data.ege_absorbed=entity.ege_absorbed
        data.ege_salt_absorbed=entity.ege_salt_absorbed
    end
	inst:AddComponent("lootdropper")

	inst:AddComponent("repairable")
	inst.components.repairable.repairmaterial = REPAIR_MATERIAL
	inst.components.repairable.onrepaired = onrepaired
    inst.components.repairable.testvalidrepairfn=function(entity) return not entity.components.health:IsDead() end

	inst:AddComponent("combat")
	inst.components.combat.onhitfn = onhit

	inst:AddComponent("health")
	inst.components.health:SetMaxHealth(HEALTH)
	inst.components.health.currenthealth = HEALTH
	inst.components.health.ondelta = onhealthchange
	inst.components.health.nofadeout = true
	inst.components.health.canheal = false
    inst.UpdateSoak=SoakDamage
    inst.ege_soaktask=inst:DoPeriodicTask(5,function(entity) SoakDamage(entity,5) end)

	inst:AddComponent("workable")
	inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
	inst.components.workable:SetWorkLeft(3)
	inst.components.workable:SetOnFinishCallback(onhammered)
	inst.components.workable:SetOnWorkCallback(onhit)

	inst.OnLoad = onload

    MakeHauntableWork(inst)

	return inst
end

local function itemfn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddNetwork()

	MakeInventoryPhysics(inst)

	inst:AddTag("wallbuilder")

	inst.AnimState:SetBank("sandbag")
	inst.AnimState:SetBuild("sandbag")
	inst.AnimState:PlayAnimation("idle")

    inst._custom_candeploy_fn = test_wall

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
	    return inst
	end

	inst:AddComponent("repairer")
	inst.components.repairer.repairmaterial = REPAIR_MATERIAL
	inst.components.repairer.healthrepairvalue = HEALTH -- HEALTH / 2

	inst:AddComponent("stackable")
	inst.components.stackable.maxsize = TUNING.STACK_SIZE_MEDITEM

	inst:AddComponent("inspectable")
	inst:AddComponent("inventoryitem")
	inst.components.inventoryitem:SetSinks(true)
    inst.components.inventoryitem.atlasname="images/ege_inventory.xml"
    inst.components.inventoryitem:ChangeImageName("ege_sandbag")

	inst:AddComponent("deployable")
	inst.components.deployable.ondeploy = ondeploy
	inst.components.deployable:SetDeployMode(DEPLOYMODE.CUSTOM)
	inst.components.deployable.deploydistance = 2

	MakeHauntableLaunch(inst)

	return inst
end

return Prefab("ege_sandbag", fn, assets, {"collapse_small"} ),
    Prefab("ege_sandbag_item", itemfn, assets, prefabs ),
    MakePlacer("ege_sandbag_item_placer",  "sandbag_small", "sandbag_small", "full", false, false, false, 1.0, nil, "eight", placerpostinitfn)
