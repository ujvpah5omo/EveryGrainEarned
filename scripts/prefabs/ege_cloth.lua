-- Cloud Country fabric appearance, independent prefab to avoid recipe conflicts.
local assets={Asset("ANIM","anim/fabric.zip"),
    Asset("ATLAS","images/ege_inventory.xml"),Asset("IMAGE","images/ege_inventory.tex")}
local function fn()
    local inst=CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()
    MakeInventoryPhysics(inst)
    inst.AnimState:SetBank("fabric")
    inst.AnimState:SetBuild("fabric")
    inst.AnimState:PlayAnimation("idle")
    inst.pickupsound="cloth"
    MakeInventoryFloatable(inst,"small",0.05,0.8)
    inst.entity:SetPristine()
    if not TheWorld.ismastersim then return inst end
    inst:AddComponent("inspectable")
    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem.atlasname="images/ege_inventory.xml"
    inst.components.inventoryitem:ChangeImageName("ege_cloth")
    inst:AddComponent("stackable")
    inst.components.stackable.maxsize=TUNING.STACK_SIZE_SMALLITEM
    inst:AddComponent("tradable")
    MakeSmallBurnable(inst,TUNING.SMALL_BURNTIME)
    MakeSmallPropagator(inst)
    MakeHauntableLaunch(inst)
    return inst
end
return Prefab("ege_cloth",fn,assets)
