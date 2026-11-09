local L = require("ege_strings")
PrefabFiles = { "ege_equipment", "ege_flood", "ege_moonoil", "ege_sandbag", "ege_cloth", "ege_salt_fx", "ege_damage_fx", "ege_ruined_field" }
Assets = {
    Asset("ATLAS","images/ege_magic_sprinkler.xml"),Asset("IMAGE","images/ege_magic_sprinkler.tex"),
    Asset("ATLAS","images/ege_inventory.xml"), Asset("IMAGE","images/ege_inventory.tex"),
    Asset("ATLAS","images/ege_moonoil.xml"), Asset("IMAGE","images/ege_moonoil.tex"),
}
local G = GLOBAL
if not G.TheNet:IsDedicated() then
    -- IA's original sandbag event; equal-length FEV project rename ia -> eg
    -- keeps it separate from IA when both mods are enabled.
    table.insert(Assets,Asset("SOUNDPACKAGE","sound/ege_sandbag.fev"))
    table.insert(Assets,Asset("SOUND","sound/ia_sfx.fsb"))
    table.insert(Assets,Asset("SOUNDPACKAGE","sound/ege_sprinkler.fev"))
    table.insert(Assets,Asset("SOUND","sound/EGE003_sfx.fsb"))
end
require("ege_growth").Apply(G.require("prefabs/farm_plant_defs").PLANT_DEFS)
local Water = require("ege_water")
local containers=G.require("containers")
containers.params.ege_magic_sprinkler={
    widget={slotpos={G.Vector3(-2,18,0)},animbank="ui_wortox_souljar_1x1",animbuild="ui_wortox_souljar_1x1",
        pos=G.Vector3(0,180,0),side_align_tip=120,
    },
    type="chest",acceptsstacks=true,excludefromcrafting=true,
    itemtestfn=function(container,item) return item.prefab=="bluegem" or item.prefab=="alterguardianhatshard" end,
}
local cfg = {}
for _, name in ipairs({"flooding", "drought", "disease", "temperature", "season_gate", "salinity", "severity", "sandbag_range"}) do
    cfg[name] = GetModConfigData(name)
end
G.TUNING.EGE = cfg
local S = G.STRINGS
S.ACTIONS.DEPLOY.EGE_SANDBAG=L("deploy_bag")
local old_deploy_string=G.ACTIONS.DEPLOY.strfn
G.ACTIONS.DEPLOY.strfn=function(act)
    if act.invobject and act.invobject.prefab=="ege_sandbag_item" then return "EGE_SANDBAG" end
    return old_deploy_string(act)
end
S.CHARACTERS.GENERIC.DESCRIBE_PLANTSTRESSOREGE_FLOOD = L("stress_flood")
S.CHARACTERS.GENERIC.DESCRIBE_PLANTSTRESSOREGE_TEMPERATURE = L("stress_cold")
S.CHARACTERS.GENERIC.DESCRIBE_PLANTSTRESSOREGE_SALT = L("stress_salt")
local names = { EGE_SPRINKLER=L("sprinkler"), EGE_MAGIC_SPRINKLER=L("magic_sprinkler"), EGE_SANDBAG=L("sandbag"), EGE_MOONOIL=L("pesticide"), EGE_FLOOD=L("flood") }
local desc = { EGE_SPRINKLER=L("sprinkler_desc"), EGE_MAGIC_SPRINKLER=L("magic_desc"), EGE_SANDBAG=L("sandbag_desc"), EGE_MOONOIL=L("pesticide_desc") }
for key, value in pairs(names) do
    S.NAMES[key] = value
    S.CHARACTERS.GENERIC.DESCRIBE[key] = desc[key] or L("flood_desc")
    if desc[key] then S.RECIPE_DESC[key] = desc[key] end
end
S.NAMES.EGE_SANDBAG_ITEM=names.EGE_SANDBAG
S.CHARACTERS.GENERIC.DESCRIBE.EGE_SANDBAG_ITEM=L("bag_item_desc")
S.NAMES.EGE_CLOTH=L("cloth")
S.RECIPE_DESC.EGE_CLOTH=L("cloth_recipe")
S.CHARACTERS.GENERIC.DESCRIBE.EGE_CLOTH=L("cloth_desc")
AddRecipe2("ege_cloth", {G.Ingredient("silk",3)}, G.TECH.SCIENCE_ONE,
    {image="ege_cloth.tex",atlas="images/ege_inventory.xml"}, {"REFINE"})
AddRecipe2("ege_sprinkler", {G.Ingredient("gears",2),G.Ingredient("goldnugget",4),G.Ingredient("boards",2)}, G.TECH.SCIENCE_TWO,
    {placer="ege_sprinkler_placer",image="ege_sprinkler.tex",atlas="images/ege_inventory.xml",min_spacing=1,testfn=Water.CanBuild,
        canbuild=function(recipe,builder,pt) return Water.CanBuild(pt) end}, {"GARDENING","STRUCTURES"})
AddRecipe2("ege_magic_sprinkler", {G.Ingredient("gears",2),G.Ingredient("bluegem",4),G.Ingredient("livinglog",2)}, G.TECH.MAGIC_THREE,
    {placer="ege_magic_sprinkler_placer",image="ege_magic_sprinkler.tex",atlas="images/ege_magic_sprinkler.xml",min_spacing=1,testfn=Water.CanBuild,
        canbuild=function(recipe,builder,pt) return Water.CanBuild(pt) end}, {"GARDENING","MAGIC","STRUCTURES"})
AddRecipe2("ege_sandbag", {G.Ingredient("ege_cloth",2,"images/ege_inventory.xml"),G.Ingredient("rope",2),G.Ingredient("rocks",8)}, G.TECH.SCIENCE_ONE,
    {product="ege_sandbag_item",numtogive=4,image="ege_sandbag.tex",atlas="images/ege_inventory.xml"}, {"GARDENING","STRUCTURES"})
AddRecipe2("ege_moonoil", {G.Ingredient("nitre",3),G.Ingredient("glommerfuel",1),G.Ingredient("messagebottleempty",1)}, G.TECH.SCIENCE_TWO,
    {image="ege_moonoil.tex",atlas="images/ege_moonoil.xml"}, {"GARDENING","RESTORATION"})

AddPrefabPostInit("world", function(inst)
    if inst.ismastersim then inst:AddComponent("ege_fields") end
end)
-- Also covers crops registered by other mods, without modifying their definitions.
AddPrefabPostInitAny(function(inst)
    if G.TheWorld == nil or not G.TheWorld.ismastersim or not inst:HasTag("farm_plant") or inst.plant_def == nil then return end
    inst:AddComponent("ege_crop")
end)
AddComponentPostInit("farming_manager",function(self)
    local hydrology=require("ege_hydrology")
    if not hydrology.Install(self) then
        self.inst:ListenForEvent("worldmapsetsize",function()
            if not hydrology.Install(self) then
                self.inst:DoTaskInTime(0,function() hydrology.Install(self) end)
            end
        end,G.TheWorld)
    end
end)

-- Restore the custom build after UM removes a snow pile over the machine.
AddPrefabPostInit("snowpile",function(inst)
    if not G.TheWorld.ismastersim then return end
    inst:ListenForEvent("onremove",function(pile)
        local x,y,z=pile.Transform:GetWorldPosition()
        for _,entity in ipairs(G.TheSim:FindEntities(x,y,z,2,{"ege_magic_sprinkler"})) do
            entity:DoTaskInTime(0,function(machine)
                if not machine:IsValid() then return end
                machine.AnimState:SetBuild("ege_magic_sprinkler")
                for _,symbol in ipairs({"spinner_01","spinner_02","spinner_03","sidecrank","sidepipe","top","shdw"}) do
                    machine.AnimState:OverrideSymbol(symbol,"sprinkler",symbol)
                end
                machine.AnimState:OverrideSymbol("swap_meter","sprinkler_meter",tostring(machine.components.fueled:GetCurrentSection()))
                machine.components.ege_desalinator:RefreshVisual()
            end)
        end
    end)
end)

G.STRINGS.NAMES.EGE_RUINED_FIELD=L("ruined_field")
local function IsRuinedPoint(pt)
    local fields=G.TheWorld.components.ege_fields
    local tile=fields and fields:AtPoint(pt.x,pt.z)
    if G.TheWorld.state.iswinter and tile and tile.water>=100 and G.TUNING.EGE.flooding then return true end
    local map=G.TheWorld.Map
    local tx,tz=map:GetTileCoordsAtPoint(pt.x,0,pt.z)
    for _,entity in ipairs(G.TheSim:FindEntities(pt.x,0,pt.z,6,{"ege_ruined_field"})) do
        local x,y,z=entity.Transform:GetWorldPosition()
        local ex,ez=map:GetTileCoordsAtPoint(x,0,z)
        if tx==ex and tz==ez then return true end
    end
    return false
end
AddComponentPostInit("terraformer",function(self)
    local old=self.Terraform
    self.Terraform=function(component,pt,...)
        if IsRuinedPoint(pt) then return false end
        return old(component,pt,...)
    end
end)
AddComponentPostInit("farmtiller",function(self)
    local old=self.Till
    self.Till=function(component,pt,...)
        if IsRuinedPoint(pt) then return false end
        return old(component,pt,...)
    end
end)
AddPrefabPostInit("farm_plow_item",function(inst)
    if not G.TheWorld.ismastersim then return end
    local deploy=inst.components.deployable
    if deploy then
        local old=deploy.CanDeploy
        deploy.CanDeploy=function(component,pt,...)
            if IsRuinedPoint(pt) then return false end
            return old(component,pt,...)
        end
    end
end)

AddComponentPostInit("farmplantable",function(self)
    local old=self.Plant
    self.Plant=function(component,target,...)
        if target and IsRuinedPoint(target:GetPosition()) then return false end
        return old(component,target,...)
    end
end)

-- Compatibility for UM's self-reigniting lavae residue, including snowballs.
AddPrefabPostInit("lavaeslime",function(inst)
    if not G.TheWorld.ismastersim then return end
    inst:DoTaskInTime(0,function(entity) require("ege_lavaeslime_fix").Apply(entity) end)
end)
