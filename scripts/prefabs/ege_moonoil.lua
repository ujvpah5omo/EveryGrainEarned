-- Bottle/projectile controls follow vanilla throwing bottles and UM Moon Oil.
-- Treatment delegates to ege_crop so stage/stress data is never rebuilt.
local assets={
    Asset("ANIM","anim/bottle.zip"),Asset("ANIM","anim/swap_gelblobbottle.zip"),
    Asset("ANIM","anim/reticuleaoe.zip"),Asset("ANIM","anim/sleepcloud.zip"),Asset("ANIM","anim/sporecloud_base.zip"),
    Asset("ATLAS","images/ege_moonoil.xml"),Asset("IMAGE","images/ege_moonoil.tex"),
}
local prefabs={"ege_moonoil_reticule","ege_moonoil_cloud","ege_moonoil_ground","messagebottle_break_fx","halloween_moonpuff"}
local TREAT_RADIUS=4*math.sqrt(2)
-- Keep the committed cloud size. The splash artwork extends past the
-- treatment area, so it must not scale with the gameplay radius.
local CLOUD_SCALE=4/3.5
local function ReticuleFn()
    local inst=CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.AnimState:SetBank("reticuleaoe")
    inst.AnimState:SetBuild("reticuleaoe")
    inst.AnimState:PlayAnimation("idle",true)
    inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGroundFixed)
    inst.AnimState:SetLayer(LAYER_WORLD_BACKGROUND)
    inst.AnimState:SetSortOrder(10)
    local scale=1.5*TREAT_RADIUS/4
    inst.AnimState:SetScale(scale,scale)
    inst:AddTag("FX")
    inst:AddTag("NOCLICK")
    inst.persists=false
    return inst
end
local function Blue(inst)
    if not inst.AnimState then return end
    inst.AnimState:SetMultColour(0.25,0.55,1,1)
    inst.AnimState:SetAddColour(0,0.08,0.4,0)
end
local function NewFX(bank,anim,loop)
    local inst=CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()
    inst.AnimState:SetBank(bank)
    inst.AnimState:SetBuild(bank)
    inst.AnimState:PlayAnimation(anim,loop~=false)
    Blue(inst)
    inst:AddTag("FX")
    inst:AddTag("NOCLICK")
    return inst
end
local function Treatment(inst)
    local x,y,z=inst.Transform:GetWorldPosition()
    for _,plant in ipairs(TheSim:FindEntities(x,0,z,TREAT_RADIUS,{"farm_plant"},{"INLIMBO"})) do
        local crop=plant.components.ege_crop
        if crop and crop:Cure() then
            local fx=SpawnPrefab("halloween_moonpuff")
            if fx then fx.Transform:SetPosition(plant.Transform:GetWorldPosition()); Blue(fx) end
        end
    end
end
local function Disperse(inst,data)
    if data.name~="disperse" then return end
    if inst.treattask then inst.treattask:Cancel(); inst.treattask=nil end
    inst.AnimState:PlayAnimation("sleepcloud_pst")
    if inst.groundfx and inst.groundfx:IsValid() then
        inst.groundfx.AnimState:PlayAnimation("sporecloud_base_pst")
    end
    inst.persists=false
    inst:DoTaskInTime(3,inst.Remove)
end
local function groundfn()
    local inst=NewFX("sporecloud_base","sporecloud_base_idle",true)
    inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
    inst.AnimState:SetLayer(LAYER_BACKGROUND)
    inst.AnimState:SetSortOrder(3)
    -- Inherits CLOUD_SCALE from its parent; scaling twice shrinks the base.
    inst.Transform:SetScale(1,1,1)
    inst.entity:SetPristine()
    inst.persists=false
    return inst
end
local function cloudfn()
    local inst=NewFX("sleepcloud","sleepcloud_pre",false)
    inst.Transform:SetScale(CLOUD_SCALE,CLOUD_SCALE,CLOUD_SCALE)
    inst.AnimState:PushAnimation("sleepcloud_loop",true)
    inst.entity:SetPristine()
    if not TheWorld.ismastersim then return inst end
    inst.groundfx=SpawnPrefab("ege_moonoil_ground")
    if inst.groundfx then inst.groundfx.entity:SetParent(inst.entity) end
    inst.Treat=Treatment
    inst.treattask=inst:DoPeriodicTask(3,Treatment,0)
    inst:AddComponent("timer")
    inst.components.timer:StartTimer("disperse",(TUNING.SLEEPBOMB_DURATION or 20)*4)
    inst:ListenForEvent("timerdone",Disperse)
    inst:ListenForEvent("onremove",function(entity)
        if entity.groundfx and entity.groundfx:IsValid() then entity.groundfx:Remove() end
    end)
    inst.OnLoad=function(entity)
        entity.AnimState:PlayAnimation("sleepcloud_loop",true)
        if entity.groundfx then entity.groundfx.AnimState:PlayAnimation("sporecloud_base_idle",true) end
    end
    return inst
end
local function Hit(inst,attacker,target)
    if inst.exploded then return end
    inst.exploded=true
    local x,y,z=inst.Transform:GetWorldPosition()
    local cloud=SpawnPrefab("ege_moonoil_cloud")
    if cloud then cloud.Transform:SetPosition(x,0,z) end
    local fx=SpawnPrefab("messagebottle_break_fx")
    if fx then fx.Transform:SetPosition(x,0,z); Blue(fx) end
    inst:Remove()
end
local function Thrown(inst)
    inst:AddTag("NOCLICK")
    inst.persists=false
    inst.AnimState:PlayAnimation("spin_gelblob_loop",true)
    inst.Physics:SetMass(1)
    inst.Physics:SetFriction(0)
    inst.Physics:SetDamping(0)
    inst.Physics:SetCollisionGroup(COLLISION.CHARACTERS)
    inst.Physics:SetCollisionMask(COLLISION.WORLD,COLLISION.OBSTACLES,COLLISION.ITEMS)
    inst.Physics:SetCapsule(0.2,0.2)
end
local function Equip(inst,owner)
    owner.AnimState:OverrideSymbol("swap_object","swap_gelblobbottle","swap_bottle")
    owner.AnimState:SetSymbolMultColour("swap_object",0.25,0.55,1,1)
    owner.AnimState:SetSymbolAddColour("swap_object",0,0.08,0.4,0)
    owner.AnimState:Show("ARM_carry")
    owner.AnimState:Hide("ARM_normal")
end
local function Unequip(inst,owner)
    owner.AnimState:SetSymbolMultColour("swap_object",1,1,1,1)
    owner.AnimState:SetSymbolAddColour("swap_object",0,0,0,0)
    owner.AnimState:Hide("ARM_carry")
    owner.AnimState:Show("ARM_normal")
end
local function Target()
    if not ThePlayer then return Vector3() end
    local pos=Vector3()
    for r=6.5,3.5,-0.25 do
        pos.x,pos.y,pos.z=ThePlayer.entity:LocalToWorldSpace(r,0,0)
        if TheWorld.Map:IsPassableAtPoint(pos:Get()) and not TheWorld.Map:IsGroundTargetBlocked(pos) then return pos end
    end
    return pos
end
local function bottlefn()
    local inst=CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()
    inst.Transform:SetTwoFaced()
    MakeInventoryPhysics(inst)
    inst:AddTag("projectile")
    inst:AddTag("weapon")
    inst.AnimState:SetBank("bottle")
    inst.AnimState:SetBuild("bottle")
    inst.AnimState:PlayAnimation("idle_gelblob")
    Blue(inst)
    inst:AddComponent("reticule")
    inst.components.reticule.targetfn=Target
    inst.components.reticule.reticuleprefab="ege_moonoil_reticule"
    inst.components.reticule.mouseenabled=true
    inst.components.reticule.ease=true
    inst.components.reticule.twinstickcheckscheme=true
    MakeInventoryFloatable(inst,"small",0.05,1)
    inst.entity:SetPristine()
    if not TheWorld.ismastersim then return inst end
    inst:AddComponent("locomotor")
    inst:AddComponent("complexprojectile")
    inst.components.complexprojectile:SetHorizontalSpeed(15)
    inst.components.complexprojectile:SetGravity(-35)
    inst.components.complexprojectile:SetLaunchOffset(Vector3(0.25,1,0))
    inst.components.complexprojectile:SetOnLaunch(Thrown)
    inst.components.complexprojectile:SetOnHit(Hit)
    inst:AddComponent("weapon")
    inst.components.weapon:SetDamage(0)
    inst.components.weapon:SetRange(8,10)
    inst:AddComponent("inspectable")
    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem.atlasname="images/ege_moonoil.xml"
    inst.components.inventoryitem:ChangeImageName("ege_moonoil")
    inst:AddComponent("stackable")
    inst.components.stackable.maxsize=TUNING.STACK_SIZE_SMALLITEM
    inst:AddComponent("equippable")
    inst.components.equippable:SetOnEquip(Equip)
    inst.components.equippable:SetOnUnequip(Unequip)
    inst.components.equippable.equipstack=true
    MakeHauntableLaunch(inst)
    return inst
end
return Prefab("ege_moonoil",bottlefn,assets,prefabs),
    Prefab("ege_moonoil_cloud",cloudfn,assets,{"ege_moonoil_ground","halloween_moonpuff"}),
    Prefab("ege_moonoil_ground",groundfn,assets),
    Prefab("ege_moonoil_reticule",ReticuleFn,assets)
