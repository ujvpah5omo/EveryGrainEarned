"""Behavior checks with Lua 5.1 and the installed game's original disease component."""
from pathlib import Path
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT.parent / "EveryGrainEarned-devtools"))
from lupa.lua51 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
for path in ROOT.rglob("*.lua"):
    lua.execute("assert(loadstring(...))", path.read_text(encoding="utf-8"))
print("PASS: all Lua sources parse under Lua 5.1")
lua.globals().ROOT = ROOT.as_posix()
hydro=LuaRuntime(unpack_returned_tuples=True)
hydro.globals().ROOT=ROOT.as_posix()
hydro.execute(r'''
package.path=ROOT.."/scripts/?.lua;"..package.path
TUNING={SOIL_MAX_MOISTURE_VALUE=100,SOIL_MIN_DRYING_TEMP=0,SOIL_MAX_DRYING_TEMP=70,
SOIL_MIN_TEMP_DRY_RATE=0,SOIL_MAX_TEMP_DRY_RATE=-.05,SOIL_RAIN_MOD=1.5,EGE={flooding=true}}
local moisture=90
local _moisturegrid={GetDataAtPoint=function() return moisture end,GetIndex=function() return 1 end}
local _drinkersgrid={GetDataAtIndex=function() return {} end}
TheSim={FindEntities=function() return {} end}
function GetTemperatureAtXZ() return 70 end
local tile={tx=0,tz=0,water=0,fresh_supply=0}
local fields={tiles={tile},AddWater=function(_,x,z,n,source,soilfirst) assert(soilfirst) end,
AtPoint=function() return tile end}
TheWorld={state={wetness=0,israining=false},components={ege_fields=fields},Map={
GetTileCoordsAtPoint=function() return 0,0 end,GetTileCenterPoint=function() return 0,0,0 end}}
local manager={}
function manager:AddSoilMoistureAtPoint(x,y,z,n)
    local unused=_moisturegrid
    moisture=math.max(0,math.min(100,moisture+n));return 42
end
function manager:_RefreshSoilMoisture(dt)
    local unused=_drinkersgrid
    local unused2=_moisturegrid
    moisture=math.max(0,math.min(100,moisture+(TheWorld.state.israining and 1.5 or -.05)*dt))
end
local Hydrology=require("ege_hydrology")
local savedgrid=_moisturegrid
_moisturegrid=nil
assert(Hydrology.Install(manager)==false,"component construction must tolerate not-yet-created native grids")
_moisturegrid=savedgrid
assert(Hydrology.Install(manager)==true)
assert(Hydrology.Install(manager)==true,"installation must be idempotent")
assert(manager:AddSoilMoistureAtPoint(0,0,0,25,"ege_sea")==42)
assert(moisture==100 and tile.water==15,"25 water must split 10 soil + 15 surface")
fields.internal_water=true
manager:AddSoilMoistureAtPoint(0,0,0,-20)
manager:AddSoilMoistureAtPoint(0,0,0,15)
tile.water=tile.water-15
fields.internal_water=false
assert(moisture==95 and tile.water==0,"surface transfer must not duplicate water")
manager:_RefreshSoilMoisture(10)
assert(moisture==94.5 and tile.water==0)
moisture=99;TheWorld.state.israining=true;TheWorld.state.precipitationrate=1
manager:_RefreshSoilMoisture(2)
assert(moisture==100 and tile.water==2 and tile.fresh_supply==3,"rain overflow counted once")
''')
print("PASS: native soil capacity, conserved overflow/transfer, evaporation and rainfall")
lua.execute(r'''
package.path=ROOT.."/scripts/?.lua;"..ROOT.."/scripts/?/init.lua;"..package.path
function Class(ctor, base, props)
    local c={}
    return setmetatable(c,{__call=function(_, ...)
        local values={}
        local o=setmetatable({}, {
            __index=function(t,k) if c[k]~=nil then return c[k] end return values[k] end,
            __newindex=function(t,k,v) if props and props[k] then values[k]=v; props[k](t,v) else rawset(t,k,v) end end
        })
        ctor(o,...); return o
    end})
end
TUNING={TOTAL_DAY_TIME=480,FARM_PLANT_DRINK_LOW=-0.0075,FARM_PLANT_DRINK_HIGH=-0.035,DAYLIGHT_SEARCH_RANGE=30,
    DISEASE_DELAY_TIME=0,DISEASE_DELAY_TIME_VARIANCE=0,DISEASE_WARNING_TIME=30,DISEASE_WARNING_TIME_VARIANCE=0,
    DISEASE_SPREAD_TIME=60,DISEASE_SPREAD_TIME_VARIANCE=0,DISEASE_SPREAD_RADIUS=4}
TUNING.EGE={flooding=true,drought=true,disease=true,temperature=true,season_gate=true,severity=1,
    sprinkler_range=6,sandbag_range=4}
FARM_PLANT_STRESS={NONE=0,LOW=1,HIGH=3}
WORLD_TILES={FARMING_SOIL=1,DIRT=2}
FRAMES=1/30
DEGREES=math.pi/180
local now=0
function GetTime() return now end
function GetTaskRemaining(task) return task.delay end
function GetRandomWithVariance(n,v) return n end
ENTITIES={}
local function hasall(e,tags) for _,tag in ipairs(tags or {}) do if not e:HasTag(tag) then return false end end return true end
TheSim={FindEntities=function(_,x,y,z,r,must,cant,one)
    local out={}
    for _,e in ipairs(ENTITIES) do
        local bad=false
        for _,tag in ipairs(cant or {}) do if e:HasTag(tag) then bad=true end end
        if e.valid and not bad and hasall(e,must) and (e.x-x)^2+(e.z-z)^2<=r*r then out[#out+1]=e end
    end
    return out
end}
function FindEntity(inst,r,predicate,tags)
    for _,e in ipairs(TheSim:FindEntities(inst.x,0,inst.z,r,tags)) do
        if e~=inst and (not predicate or predicate(e)) then return e end
    end
end
function Entity(x,z,tags)
    local e={x=x or 0,z=z or 0,tags={},components={},valid=true,AnimState={SetMultColour=function() end,SetAddColour=function() end,SetPercent=function() end,SetScale=function() end},
        entity={SetParent=function() end,AddFollower=function() return {FollowSymbol=function() end} end}}
    e.GUID=#ENTITIES+1
    for _,tag in ipairs(tags or {}) do e.tags[tag]=true end
    e.Transform={GetWorldPosition=function() return e.x,0,e.z end,SetPosition=function(_,x,y,z) e.x,e.z=x,z end}
    function e.Transform:SetRotation() end
    function e:AddTag(tag) self.tags[tag]=true end
    function e:RemoveTag(tag) self.tags[tag]=nil end
    function e:HasTag(tag) return self.tags[tag]==true end
    function e:IsValid() return self.valid end
    function e:IsAsleep() return false end
    function e:DoTaskInTime(delay,fn,...) return {delay=delay,fn=fn,args={...},Cancel=function(t) t.cancelled=true end} end
    function e:DoPeriodicTask(...) return self:DoTaskInTime(...) end
    function e:ListenForEvent(event,fn)
        if event=="onremove" then self.test_onremove=fn end
    end
    function e:PushEvent(event) if event=="collapsesoil" then self.collapsed=true end end
    function e:GetDistanceSqToInst(other) return (self.x-other.x)^2+(self.z-other.z)^2 end
    function e:GetPosition() return Vector3(self.x,0,self.z) end
    function e:WatchWorldState(name,fn) self.watch=self.watch or {}; self.watch[name]=fn end
    function e:AddComponent(name) self.components[name]=require("components/"..name)(self) end
    function e:RemoveComponent(name)
        local c=self.components[name]
        if c and c.OnRemoveFromEntity then c:OnRemoveFromEntity() end
        self.components[name]=nil
    end
    function e:Remove() self.valid=false end
    ENTITIES[#ENTITIES+1]=e
    return e
end
TheWorld=Entity()
TheWorld.state={season="autumn",issummer=false,israining=false,precipitationrate=0,isnight=false}
TheWorld.Map={tiles={}}
local map=TheWorld.Map
function map:GetTile(tx,tz) return self.tiles[tx..":"..tz] or WORLD_TILES.DIRT end
function map:SetTile(tx,tz,tile) self.tiles[tx..":"..tz]=tile end
function map:GetSize() return 10,10 end
function map:GetTileCoordsAtPoint(x,y,z) return math.floor(x/4),math.floor(z/4) end
function map:GetTileCenterPoint(tx,tz) return tx*4+2,0,tz*4+2 end
function map:GetTileAtPoint(x,y,z) return self:GetTile(self:GetTileCoordsAtPoint(x,y,z)) end
function map:IsOceanTileAtPoint(x,y,z) return SEA_START_X~=nil and x>=SEA_START_X end
function map:IsVisualGroundAtPoint(x,y,z) return not self:IsOceanTileAtPoint(x,y,z) end
function map:GetEntitiesOnTileAtPoint(x,y,z)
    local tx,tz=self:GetTileCoordsAtPoint(x,y,z)
    local out={}
    for _,e in ipairs(ENTITIES) do local a,b=self:GetTileCoordsAtPoint(e.x,0,e.z)
        if e.valid and a==tx and b==tz then out[#out+1]=e end
    end
    return out
end
local manager={wet=true,nutrients={50,50,50},watercalls=0}
function manager:AddTileNutrients(tx,tz,a,b,c)
    for i,v in ipairs({a,b,c}) do self.nutrients[i]=math.max(0,self.nutrients[i]+v) end
end
function manager:GetTileNutrients() return unpack(self.nutrients) end
function manager:IsSoilMoistAtPoint() return self.wet end
function manager:AddSoilMoistureAtPoint(x,y,z,amount,source) self.watercalls=self.watercalls+1; self.lastsource=source end
TheWorld.components.farming_manager=manager
TEMPERATURE=20
function GetTemperatureAtXZ() return TEMPERATURE end
function DoDeltaMoistureToEntity(e,amount) e.wetdelta=(e.wetdelta or 0)+amount end
function Vector3(x,y,z) return {x=x,y=y,z=z} end
function SpawnPrefab(name)
    if name=="ege_ruined_field" then return Entity(0,0,{"ege_ruined_field"}) end
    local e=Entity()
    e.prefab=name
    function e:SetLoops() end
    function e:SetLevel(level) self.level=level end
    e.Transform.SetScale=function() end
    if name=="pitchfork" then
        e.components.terraformer={Terraform=function(_,p)
            local a,b=map:GetTileCoordsAtPoint(p.x,0,p.z)
            map.tiles[a..":"..b]=WORLD_TILES.DIRT
        end}
    end
    return e
end
function Crop(x,z,seasons)
    local e=Entity(x,z,{"farm_plant"})
    e.plant_def={good_seasons=seasons or {autumn=true,winter=true},moisture={drink_rate=-0.0075}}
    local g={stage=2,pausedremaining=123,stages={{name="seed"},{name="sprout"},{name="full"},{name="rotten"}}}
    function g:Pause() self.paused=true end
    function g:Resume() self.paused=false end
    function g:StopGrowing() self.paused=true end
    function g:StartGrowing() self.paused=false end
    function g:SetStage(n) self.stage=n end
    function g:GetCurrentStageData() return self.stages[self.stage] end
    e.components.growable=g
    local stress={final_stress_state=0}
    stress.categories={}; stress.stressors={}
    function stress:AddStressCategory(name,fn) self.categories[name]=fn end
    function stress:SetStressed(name,value) self.stressors[name]=value end
    function stress:MakeCheckpoint() end
    function stress:CalcFinalStressState() self.final_stress_state=0; return 0 end
    e.components.farmplantstress=stress
    e.components.inspectable={}
    e.components.lootdropper={lootsetupfn=function(component) component:SetLoot({"carrot","carrot_seeds"}) end}
    function e.components.lootdropper:SetLoot(loot) self.loot=loot end
    e.components.ege_crop=require("components/ege_crop")(e)
    return e
end
''')
GAME = Path("E:/Games/SteamLibrary/steamapps/common/Don't Starve Together/data/databundles/scripts.zip")
with zipfile.ZipFile(GAME) as z:
    disease_source = z.read("scripts/components/diseaseable.lua").decode("utf-8")
    lua.globals().REPAIRABLE_SOURCE = z.read("scripts/components/repairable.lua").decode("utf-8")
    lua.globals().REPAIRER_SOURCE = z.read("scripts/components/repairer.lua").decode("utf-8")
lua.globals().DISEASE_SOURCE = disease_source
lua.execute('package.preload["components/diseaseable"]=assert(loadstring(DISEASE_SOURCE))')
lua.execute('package.preload["components/repairable"]=assert(loadstring(REPAIRABLE_SOURCE)); package.preload["components/repairer"]=assert(loadstring(REPAIRER_SOURCE))')
lua.execute(r'''
local R=require("ege_rules")
local Terrain=require("ege_terrain_visual")
local stage_symbol=nil
local decal={ege_build="ege_terrain_dry",AnimState={OverrideSymbol=function(_,symbol,build,frame) stage_symbol=frame end},Transform={SetScale=function(_,x,y,z) assert(x==1.2 and x==y and y==z) end}}
local cracks={_level={value=function() return 1 end}}
Terrain.Fit(cracks,decal,1.2)
assert(stage_symbol==nil,"terrain must not inherit directional crack animation symbols")
local ruined_source=assert(io.open(ROOT.."/scripts/prefabs/ege_ruined_field.lua")):read("*a")
assert(ruined_source:find('cause=="dry" and 3',1,true),"dry terrain must have a nonzero replicated cause")
assert(R.DrainCovers(6.5,6.5,6.5) and not R.DrainCovers(6.51,0,6.5))
assert(not R.DrainCovers(4,4,4) and R.DrainCovers(4,0,4))
local Fix=require("ege_lavaeslime_fix")
local previous_remaining=GetTaskRemaining
local clock=0
GetTaskRemaining=function(task) return math.max(0,task.deadline-clock) end
local residue={prefab="lavaeslime",components={}}
local burn={burning=true,burntime=4,task={deadline=4}}
residue.components.burnable=burn
function burn:Extinguish()
    self.burning=false;self.task=nil
    -- Model UM's onextinguish immediately calling Ignite/ExtendBurning.
    self.burning=true;self.task={deadline=clock+self.burntime}
end
Fix.Apply(residue);Fix.Apply(residue)
for i=1,19 do
    clock=i*.2;burn:Extinguish()
    assert(math.abs(burn.task.deadline-4)<1e-8 and burn.burntime==4,
        "continuous extinguishing must preserve the original expiry and base duration")
end
GetTaskRemaining=previous_remaining
print("PASS: UM lavae residue repeated extinguishing preserves its original burn deadline")
local Growth=require("ege_growth")
local shared={seed={10,20},sprout={20,30},small={30,40},med={40,50},full=100,oversized=150,regrow={60,80}}
local defs={a={grow_time=shared},b={grow_time=shared},external={grow_time={seed={30,60},pro2hm=true}}}
Growth.Apply(defs);Growth.Apply(defs)
assert(shared.seed[1]==20 and shared.sprout[2]==60 and shared.med[2]==100)
assert(shared.full==100 and shared.oversized==150 and shared.regrow[1]==60)
assert(defs.external.grow_time.seed[1]==30 and shared.pro2hm)
print("PASS: doubled active growth only, shared definitions and repeated installation protected, external multiplier respected")
assert(math.abs(R.SummerEvaporation(0,.05)-.4)<1e-9)
assert(math.abs(R.SummerEvaporation(.315,.05)+.315-.4)<1e-9)
assert(R.SummerEvaporation(.5,.05)==.05)
local Shade=require("ege_shade")
local giant=Entity(0,0,{"shadecanopysmall"})
giant._hascanopy={value=function() return true end}
assert(Shade.IsSheltered(21,0) and not Shade.IsSheltered(23,0))
giant._hascanopy.value=function() return false end
assert(not Shade.IsSheltered(0,0))
giant:Remove()
print("PASS: giant canopy range, lost canopy and outside shade detection")
assert(R.Water(299,2,0,0,10)==300)
assert(R.Water(5,0,0,2,10)==0)
local cold=R.Profile({good_seasons={winter=true},moisture={drink_rate=-0.0075}})
assert(R.TemperatureDose(0,-10,cold,10)==0)
assert(R.TemperatureDose(0,60,cold,10)==0)
local hot=R.Profile({good_seasons={summer=true},moisture={drink_rate=-0.035}})
assert(hot.flood_tolerance>cold.flood_tolerance)
assert(R.TemperatureDose(0,70,hot,10)==0)
assert(R.TemperatureDose(0,-1,hot,10)==10)
print("PASS: cold damage without heat damage and bounded water balance")

TheWorld.Map.tiles["0:0"]=WORLD_TILES.FARMING_SOIL
local fields=require("components/ege_fields")(TheWorld)
TheWorld.components.ege_fields=fields
fields:AddWater(2,2,180)
fields:Tick(10)
assert(fields:IsFlooded(2,2))
assert(TheWorld.components.farming_manager.nutrients[1]<50)
local a=Crop(1,1)
a.components.ege_crop:Tick(400)
assert(a.components.diseaseable:IsDiseased())
assert(a:HasTag("diseased") and not a:HasTag("diseaseable"))
assert(a.components.growable.paused)
local drop=a.components.lootdropper
drop.lootsetupfn(drop)
assert(#drop.loot==1 and drop.loot[1]=="spoiled_food")
assert(not a.components.ege_crop:Cure())
local b=Crop(2,1)
a.components.diseaseable:Spread()
assert(b.components.diseaseable:IsDiseased())
print("PASS: original disease infection/transmission; wet treatment rejected")

local bag=Entity(2,2,{"ege_drain"})
function bag:AbsorbWater(n) return n end
fields:Tick(100)
assert(not fields:IsFlooded(1,1))
local stage,remaining=a.components.growable.stage,a.components.growable.pausedremaining
TheWorld.state.isnight=true
assert(a.components.ege_crop:Cure())
assert(a.components.growable.stage==stage and a.components.growable.pausedremaining==remaining)
assert(a.components.growable.paused)
assert(not a:HasTag("diseased") and a:HasTag("diseaseable"))
drop.lootsetupfn(drop)
assert(drop.loot[1]=="carrot" and drop.loot[2]=="carrot_seeds")
TheWorld.state.isnight=false
a.components.ege_crop:Tick(10)
assert(not a.components.growable.paused)
print("PASS: sandbag drains; cure preserves growth and respects darkness")

local saved=fields:OnSave()
local restored=require("components/ege_fields")(TheWorld)
restored:OnLoad(saved)
assert(restored.tiles["0:0"].water==fields.tiles["0:0"].water)
local savedcrop=b.components.ege_crop:OnSave()
local c=Crop(3,1)
c.components.ege_crop:OnLoad(savedcrop)
assert(c.components.ege_crop.sicktime==savedcrop.sicktime)
local savedDisease=b.components.diseaseable:OnSave()
c.components.diseaseable:OnLoad(savedDisease)
assert(c.components.diseaseable:IsDiseased())
print("PASS: field/crop state and original disease save/load")

TheWorld.state.season="summer"
assert(a.components.farmplantstress:CalcFinalStressState()==FARM_PLANT_STRESS.LOW)
TUNING.EGE.season_gate=false
assert(a.components.farmplantstress:CalcFinalStressState()==FARM_PLANT_STRESS.NONE)
print("PASS: seasonal giant gate and disabled setting")
local offseason=Crop(4002,4002,{spring=true})
local offgrow=offseason.components.growable
offseason.components.ege_crop.disease_checks_ready=true
TUNING.EGE.season_gate=true
offgrow:SetStage(3)
assert(offgrow.stage==4 and offgrow.paused and not offgrow.loopstages)
assert(offseason.components.ege_crop.reason=="rot_season")
offgrow:StartGrowing()
assert(offgrow.paused,"withered crops must not restart")
local unrestricted=Crop(4006,4002,{spring=true})
unrestricted.components.ege_crop.disease_checks_ready=true
TUNING.EGE.season_gate=false
unrestricted.components.growable:SetStage(3)
assert(unrestricted.components.growable.stage==3,"disabled seasonal harvest must permit fruit")
offseason:Remove()
unrestricted:Remove()
print("PASS: out-of-season maturity skips fruit and withered crops do not restart")


TEMPERATURE=-30
a.components.ege_crop:Tick(480)
assert(a.components.ege_crop.ruined and a.components.growable.stage==4)
assert(not a.components.ege_crop:Cure())
print("PASS: sustained cold damage rots crop; rot cannot be cured")

bag:Remove()
TheWorld.components.farming_manager.nutrients={100,100,100}
TheWorld.components.farming_manager.wet=false
TheWorld.state.issummer=true
fields.tiles["0:0"].water=0
fields:Tick(480)
assert(TheWorld.Map:GetTile(0,0)==WORLD_TILES.FARMING_SOIL and fields.tiles["0:0"].dry==0)
fields:Tick(480)
assert(TheWorld.Map:GetTile(0,0)==WORLD_TILES.FARMING_SOIL)
assert(fields.tiles["0:0"]==nil)
assert(b.components.ege_crop.ruined)
print("PASS: fertile dry summer soil is destroyed without requiring depleted nutrients")

TheWorld.Map.tiles["1:0"]=WORLD_TILES.FARMING_SOIL
fields:AddWater(6,2,300)
fields.tiles["1:0"].flood=1440
TheWorld.state.issummer=false
TheWorld.components.farming_manager.wet=true
fields:Tick(5)
assert(TheWorld.Map:GetTile(1,0)==WORLD_TILES.FARMING_SOIL)
print("PASS: persistent flooding destroys farmland independently of drought")
for _,ruin in ipairs(TheSim:FindEntities(4,0,2,6,{"ege_ruined_field"})) do ruin:Remove() end
''')
lua.execute(r'''
package.preload.prefabutil=function() return {} end
local Water=require("ege_water")
assert(not Water.CanBuild(Vector3(0,0,0)))
SEA_START_X=20
assert(Water.FindSource(Vector3(1,0,0))=="sea")
assert(not Water.CanBuild(Vector3(-1,0,0)))
SEA_START_X=nil
local pond=Entity(20,0,{"pond","watersource"})
pond.components.watersource={available=true}
SEA_START_X=4
assert(Water.FindSource(Vector3(0,0,0))=="pond","distant freshwater must beat nearby sea")
SEA_START_X=nil
assert(Water.FindSource(Vector3(0,0,0))=="pond")
pond.z=20
assert(Water.FindSource(Vector3(0,0,0))=="pond")
pond.z=0
assert(not Water.CanBuild(Vector3(-0.1,0,0)))
pond.frozen=true
assert(not Water.CanBuild(Vector3(0,0,0)))
pond.frozen=false
pond.components.watersource.available=false
assert(not Water.CanBuild(Vector3(0,0,0)))
pond:Remove()
for _,name in ipairs({"grotto_pool_big","grotto_pool_small","pond_cave"}) do
    local pool=Entity(16,0,name=="pond_cave" and {"watersource","pond"} or {"watersource"})
    pool.prefab=name;pool.components.watersource={available=true}
    SEA_START_X=4
    assert(Water.FindSource(Vector3(0,0,0))=="pond",name.." must be freshwater and beat a nearby ocean")
    pool.components.watersource.available=false
    assert(Water.FindSource(Vector3(0,0,0))=="sea",name.." unavailable source must not be used")
    pool:Remove();SEA_START_X=nil
end
print("PASS: lunar grotto big/small pools and toad-area cave ponds are prioritized freshwater")
local oasis=Entity(2,0,{"watersource"})
oasis.prefab="oasislake"
oasis.components.watersource={available=true}
TheWorld.state.issummer=false
assert(not Water.CanBuild(Vector3(0,0,0)))
TheWorld.state.issummer=true
assert(Water.FindSource(Vector3(0,0,0))=="oasis")
oasis.components.watersource.available=false
assert(not Water.CanBuild(Vector3(0,0,0)))
oasis:Remove()
SEA_START_X=16
print("PASS: square water-source area including corners, pond freezing and seasonal oasis")
function Asset(kind,path) return {kind=kind,path=path} end
function Prefab(name,fn,assets) return {name=name,fn=fn,assets=assets} end
function MakePlacer(name,bank,build,anim) return {name=name} end
function MakeObstaclePhysics() end
function MakeInventoryPhysics() end
function MakeInventoryFloatable() end
function MakeHauntableLaunch() end
function MakeHauntableWork() end
function net_bool()
    return {set=function(self,v) self.v=v end,set_local=function(self,v) self.v=v end,value=function(self) return self.v end}
end
ACTIONS={HAMMER={}}
FUELTYPE={BURNABLE=1}
DEPLOYMODE={ANYWHERE=1,CUSTOM=2}
TUNING.STACK_SIZE_MEDITEM=40
COLLISION={CHARACTERS=1,WORLD=2,OBSTACLES=4,ITEMS=8}
ANIM_ORIENTATION={OnGround=1}
LAYER_BACKGROUND=1
TUNING.STACK_SIZE_SMALLITEM=20
function CreateEntity()
    local e=Entity()
    e.entity={AddTransform=function() end,AddAnimState=function() end,AddSoundEmitter=function() end,
        AddNetwork=function() end,SetPristine=function() end,SetParent=function() end,
        AddFollower=function() return {FollowSymbol=function() end} end}
    e.AnimState={SetPercent=function() end,SetScale=function() end,SetBank=function(_,v) e.bank=v end,SetBuild=function(_,v) e.build=v end,
        PlayAnimation=function(_,v) e.anim=v end,OverrideSymbol=function(_,symbol,build,image) e.meter=image end,
        Hide=function() end,Show=function() end,SetMultColour=function(_,r,g,b,a) e.colour={r,g,b,a} end,SetAddColour=function() end,
        PushAnimation=function() end,SetTime=function() end,Hide=function() end,Show=function() end,SetOrientation=function() end,SetLayer=function() end,SetSortOrder=function() end}
    function e.AnimState:SetLightOverride(n) e.light=n end
    function e.AnimState:SetFinalOffset() end
    e.Physics=setmetatable({},{__index=function() return function() end end})
    e.SoundEmitter={PlaySound=function() end,KillSound=function() end}
    function e.Transform:SetScale(x,y,z) e.scale={x,y,z} end
    function e.Transform:SetTwoFaced() end
    function e.Transform:SetEightFaced() end
    function e:Hide() self.hidden=true end
    function e:Show() self.hidden=false end
    function e:SetDeployExtraSpacing(n) self.deploy_extra_spacing=n end
    function e:SetStateGraph(name)
        self.sg={GoToState=function(_,state) self.pipestate=state end}
    end
    function e:AddComponent(name)
        local c={}
        self.components[name]=c
        if name=="workable" then
            function c:SetWorkAction() end
            function c:SetWorkLeft() end
            function c:SetOnFinishCallback(fn) self.finish=fn end
            function c:SetOnWorkCallback(fn) self.onwork=fn end
        elseif name=="lootdropper" then
            function c:SetLoot() end
            function c:DropLoot() end
            function c:SpawnLootPrefab(name) self.drops=self.drops or {}; table.insert(self.drops,name) end
        elseif name=="health" then
            function c:SetMaxHealth(n) self.maxhealth=n; self.currenthealth=n end
            function c:GetPercent() return self.currenthealth/self.maxhealth end
            function c:IsDead() return self.currenthealth<=0 end
            function c:DoDelta(n)
                local old=self:GetPercent()
                self.currenthealth=math.max(0,math.min(self.maxhealth,self.currenthealth+n))
                if self.ondelta then self.ondelta(e,old,self:GetPercent()) end
            end
        elseif name=="repairable" or name=="repairer" then
            self.components[name]=require("components/"..name)(self)
        elseif name=="fueled" then
            function c:InitializeFuelLevel(n) self.fuel=n; self.maxfuel=n; if self.sectionfn then self.sectionfn(nil,nil,e) end end
            function c:SetSections(n) self.sections=n end
            function c:SetUpdateFn(fn) self.updatefn=fn end
            function c:SetSectionCallback(fn) self.sectionfn=fn end
            function c:GetPercent() return self.fuel/self.maxfuel end
            function c:GetCurrentSection() return self.fuel<=0 and 0 or math.min(math.floor(self:GetPercent()*self.sections)+1,self.sections) end
            function c:SetDepletedFn(fn) self.depleted=fn end
            function c:IsEmpty() return self.fuel<=0 end
            function c:StartConsuming() self.consuming=true end
            function c:StopConsuming() self.consuming=false end
        elseif name=="machine" then
            function c:IsOn() return self.ison==true end
            function c:TurnOn() self.turnonfn(e); self.ison=true end
            function c:TurnOff() self.turnofffn(e); self.ison=false end
        elseif name=="container" then
            function c:WidgetSetup() end
            function c:GetItemInSlot() return self.item end
            function c:RemoveItemBySlot() local item=self.item; self.item=nil; return item end
            function c:DropEverything() self.dropped=true; self.item=nil end
        elseif name=="ege_desalinator" then
            self.components[name]=require("components/ege_desalinator")(e)
        elseif name=="inventoryitem" then
            function c:ChangeImageName(n) self.image=n end
            function c:SetSinks() end
        elseif name=="stackable" then
            function c:Get() return e end
        elseif name=="deployable" then
            function c:SetDeployMode(mode) self.mode=mode end
        elseif name=="complexprojectile" then
            function c:SetHorizontalSpeed(n) self.speed=n end
            function c:SetGravity(n) self.gravity=n end
            function c:SetLaunchOffset(n) self.offset=n end
            function c:SetOnLaunch(fn) self.onlaunchfn=fn end
            function c:SetOnHit(fn) self.onhitfn=fn end
        elseif name=="weapon" then
            function c:SetDamage(n) self.damage=n end
            function c:SetRange(a,b) self.range=a end
        elseif name=="equippable" then
            function c:SetOnEquip(fn) self.onequipfn=fn end
            function c:SetOnUnequip(fn) self.onunequipfn=fn end
        elseif name=="timer" then
            function c:StartTimer(name,time) self.name=name; self.time=time end
        end
    end
    return e
end
TheWorld.ismastersim=true
local sprinkler,pipe,spray,magic,core,shardcore=dofile(ROOT.."/scripts/prefabs/ege_equipment.lua")
local bag,bagitem=dofile(ROOT.."/scripts/prefabs/ege_sandbag.lua")
local oil,cloud,ground=dofile(ROOT.."/scripts/prefabs/ege_moonoil.lua")
local oldspawn=SpawnPrefab
SpawnPrefab=function(name)
    if name=="ege_water_pipe" then return pipe.fn() end
    if name=="ege_sprinkler_core" then return core.fn() end
    if name=="ege_sprinkler_shard_core" then return shardcore.fn() end
    if name=="ege_water_spray" then return spray.fn() end
    if name=="ege_moonoil_cloud" then return cloud.fn() end
    if name=="ege_moonoil_ground" then return ground.fn() end
    return oldspawn(name)
end
local s=sprinkler.fn()
assert(not s.ege_magic and not s.components.container and not s.components.ege_desalinator)
assert(s.meter=="10")
s.components.fueled.fuel=s.components.fueled.maxfuel/2
s.components.fueled.sectionfn(nil,nil,s)
assert(s.meter=="6")
s.components.fueled.fuel=s.components.fueled.maxfuel
assert(s.components.machine and not s.components.machine:IsOn())
s.components.machine:TurnOn()
assert(s.spraytask and s.components.fueled.consuming)
TheWorld.Map.tiles["0:0"]=WORLD_TILES.FARMING_SOIL
TheWorld.Map.tiles["1:0"]=WORLD_TILES.FARMING_SOIL
TheWorld.components.farming_manager.watercalls=0
local wet=Entity(1,0)
wet.components.moisture={AddRateBonus=function(self,source,rate) self.source=source; self.rate=rate end,
    RemoveRateBonus=function(self,source) if self.source==source then self.source=nil; self.rate=nil end end}
wet.components.burnable={Extinguish=function(self) self.extinguished=true end}
wet.components.witherable={Protect=function(self,time) self.protected=true end}
local item=Entity(1,1)
item.components.inventoryitemmoisture={DoDelta=function(self,n) self.total=(self.total or 0)+n end}
local oldcrop=Entity(2,1)
oldcrop.components.crop={task=true,DoGrow=function(self,n) self.grown=(self.grown or 0)+n end}
for i=1,11 do s.spraytask.fn(s) end
assert(TheWorld.components.farming_manager.watercalls>2)
assert(TheWorld.components.farming_manager.lastsource=="ege_sea")
assert(wet.components.moisture.rate>0 and wet.components.burnable.extinguished and wet.components.witherable.protected)
assert(item.components.inventoryitemmoisture.total>0 and oldcrop.components.crop.grown>0)
s.components.machine:TurnOff()
assert(s.spraytask==nil and not s.components.fueled.consuming)
assert(wet.components.moisture.source==nil and not s.components.watersource.available)
assert(s.water_spray==nil)
s.components.fueled.fuel=0
s.components.machine:TurnOn()
assert(not s.components.machine:IsOn() and not s.spraytask)
s.components.fueled.fuel=100
SEA_START_X=nil
s.components.machine:TurnOn()
assert(not s.components.machine:IsOn() and not s.components.fueled.consuming)
local lake=Entity(2,0,{"watersource"})
lake.prefab="oasislake"
lake.components.watersource={available=true}
TheWorld.state.issummer=true
s.components.machine:TurnOn()
assert(s.components.machine:IsOn() and s.ege_water_source=="oasis")
s.watch.issummer(s,false)
assert(not s.components.machine:IsOn() and not s.components.fueled.consuming)
lake:Remove()
local bagent=bag.fn()
assert(bagent:HasTag("ege_drain") and bagent.components.workable)
assert(bagent.components.health.maxhealth==200)
assert(bagent.scale[2]==0.45)
bagent.components.health:DoDelta(-100)
assert(bagent.components.health:GetPercent()==0.5)
local repairbag=bagitem.fn()
assert(repairbag:HasTag("health_ege_sandbag") and not repairbag:HasTag("ege_drain"))
assert(bagent.components.repairable:Repair(nil,repairbag))
assert(not repairbag:IsValid() and bagent.components.health:GetPercent()==1)
assert(bagent.anim=="full" and bagent:HasTag("ege_drain"))
assert(bagent:AbsorbWater(149)==149 and bagent.scale[2]==0.45)
assert(bagent:AbsorbWater(1)==1 and bagent.scale[2]==1 and bagent:HasTag("ege_drain"))
assert(bagent:AbsorbWater(140)==140 and bagent.scale[2]==1)
assert(bagent:AbsorbWater(50)==10 and bagent:HasTag("ege_saturated") and not bagent:HasTag("ege_drain"))
assert(bagent.scale[2]==1)
assert(bagent:AbsorbWater(10)==0)
local savedbag={}
bagent:OnSave(savedbag)
local loadedbag=bag.fn()
loadedbag:OnLoad(savedbag)
assert(loadedbag.ege_absorbed==300 and not loadedbag:HasTag("ege_drain"))
assert(loadedbag.scale[2]==1)
loadedbag.components.health:DoDelta(-100)
assert(loadedbag.components.repairable:Repair(nil,bagitem.fn()))
assert(loadedbag.ege_absorbed==300 and not loadedbag:HasTag("ege_drain"),"repair must not reset saturation")
local soakfields=TheWorld.components.ege_fields
loadedbag.Transform:SetPosition(2,0,2)
soakfields:AtPoint(2,2).water=200
loadedbag:UpdateSoak(120)
assert(loadedbag.components.health.currenthealth==150)
soakfields:AtPoint(2,2).water=0
loadedbag:UpdateSoak(120)
assert(loadedbag.components.health.currenthealth==150,"dry ground must stop water damage")
soakfields:AtPoint(2,2).water=200
loadedbag:UpdateSoak(360)
assert(loadedbag.components.health:IsDead() and loadedbag.ege_destroy_task)
assert(not loadedbag.components.repairable:Repair(nil,bagitem.fn()))
loadedbag.ege_destroy_task.fn(loadedbag)
assert(not loadedbag:IsValid())
Prefabs={sand=true}
bagent.components.workable.finish(bagent)
assert(not bagent:IsValid() and #bagent.components.lootdropper.drops==1)
for _,loot in ipairs(bagent.components.lootdropper.drops) do assert(loot=="rocks") end
local damagedbag=bag.fn()
damagedbag.components.health:DoDelta(-50)
damagedbag.components.workable.finish(damagedbag)
assert(#damagedbag.components.lootdropper.drops==1)
Prefabs=nil
local standalonebag=bag.fn()
standalonebag.components.workable.finish(standalonebag)
assert(#standalonebag.components.lootdropper.drops==1)
print("PASS: IA sandbag rubble stops drainage; repair restores health; saturated soaking damage; revised hammer refunds")
print("PASS: finite absorption, saved saturation, repair preserves capacity, and fill-dependent bag height")
local bottle=oil.fn()
assert(bottle.bank=="bottle" and bottle.components.inventoryitem.image=="ege_moonoil")
assert(bottle.components.equippable.equipstack and bottle.components.weapon.damage==0)
assert(bottle.components.complexprojectile.speed==15 and bottle.components.deployable==nil)
assert(bottle.colour[3]>bottle.colour[1])
local target=Crop(2,2)
target.components.diseaseable:Disease()
local fields=TheWorld.components.ege_fields
fields:AtPoint(2,2).water=180
local mist=cloud.fn()
mist.Transform:SetPosition(2,0,2)
mist:Treat()
assert(target.components.diseaseable:IsDiseased())
fields:AtPoint(2,2).water=0
mist:Treat()
assert(not target.components.diseaseable:IsDiseased())
local corner=Crop(6,6)
corner.components.diseaseable:Disease()
mist:Treat()
assert(not corner.components.diseaseable:IsDiseased(),"medicine must cover a 2x2 field corner")
local distant=Crop(8,2)
distant.components.diseaseable:Disease()
mist:Treat()
assert(distant.components.diseaseable:IsDiseased(),"medicine must not cure outside the 2x2 field radius")
assert(mist.components.timer.name=="disperse" and mist.components.timer.time>0)
bottle.components.complexprojectile.onlaunchfn(bottle)
assert(bottle:HasTag("NOCLICK") and bottle.anim=="spin_gelblob_loop")
bottle.components.complexprojectile.onhitfn(bottle,nil,nil)
assert(not bottle:IsValid())
SEA_START_X=16
local m=magic.fn()
assert(m.ege_magic and m:HasTag("ege_magic_sprinkler") and m.components.container and m.components.ege_desalinator)
assert(m.components.machine.enabled~=false and m.magic_core.anim=="bluegem_idle")
assert(m.build=="ege_magic_sprinkler")
assert(m.components.machine:TurnOn())
local gem=Entity(); gem.prefab="bluegem"
m.components.container.item=gem
for i=1,11 do m:UpdateSpray() end
assert(not gem:IsValid() and m.components.ege_desalinator.remaining==238)
assert(TheWorld.components.farming_manager.lastsource=="ege_fresh" and m.magic_core.light==0.7)
local shard=Entity(); shard.prefab="alterguardianhatshard"
m.components.container.item=shard
m.components.ege_desalinator:RefreshVisual()
assert(m.magic_core.shard and m.magic_core.hidden and not m.magic_shard_core.hidden and m.magic_shard_core.build=="alterguardianhatshard")
for i=1,10 do m:UpdateSpray() end
assert(shard:IsValid() and m.components.ege_desalinator.remaining==238)
m.components.machine:TurnOff()
assert(m.magic_core.light==0.1)
print("PASS: ordinary raw seawater without slot; magic prepaid desalination, separate tint, visible gem/shard core and stopped glow")
TheWorld.ismastersim=false
local original_world_master=TheWorld.ismastersim
TheWorld.ismastersim=true
for _,definition in ipairs({sprinkler,magic}) do
    local destroyed=definition.fn()
    local first,middle,last=Entity(),Entity(),Entity()
    middle:Remove() -- Broken pipe links must not prevent the others disappearing.
    first.sg={GoToState=function() end}
    last.sg={GoToState=function(_,state) last.pipestate=state end}
    destroyed.pipes={first,middle,last}
    destroyed.test_onremove(destroyed)
    assert(last.pipestate=="retract" and last._prev==first and #destroyed.pipes==0)
    first.ege_cleanup.fn(first);last.ege_cleanup.fn(last)
    assert(not first:IsValid() and not last:IsValid())
end
TheWorld.ismastersim=original_world_master
print("PASS: both sprinklers initiate reverse retraction and retain cleanup fallback")
assert(next(sprinkler.fn().components)==nil)
assert(next(bag.fn().components)==nil)
assert(next(magic.fn().components)==nil)
assert(oil.fn().components.complexprojectile==nil and oil.fn().components.reticule~=nil)
print("PASS: server/client prefabs, full sprinkler effects, blue thrown bottle and drained-crop mist treatment")
''')
lua.execute(r'''
local fields=TheWorld.components.ege_fields
TheWorld.ismastersim=true
TheNet={IsDedicated=function() return true end}
net_tinybyte=net_bool
local salt=dofile(ROOT.."/scripts/prefabs/ege_salt_fx.lua")
local oldspawn=SpawnPrefab
SpawnPrefab=function(name)
    if name=="ege_salt_fx" then return salt.fn() end
    return oldspawn(name)
end
TheWorld.Map.tiles["10:10"]=WORLD_TILES.FARMING_SOIL
TheWorld.state.season="autumn"
TUNING.EGE.salinity=true
local crop=Crop(42,42)
local c=crop.components.ege_crop
c:SampleWater()
fields:AddWater(42,42,10,"sea")
fields:AddWater(42,42,10,"fresh")
assert(not c:IsSalty() and c.sea_supply==10 and c.fresh_supply==10)
crop.components.farmplantstress:MakeCheckpoint()
assert(not crop.components.farmplantstress.stressors.ege_salt)
assert(crop.components.farmplantstress:CalcFinalStressState()==FARM_PLANT_STRESS.NONE)
fields:AddWater(42,42,100,"fresh")
assert(not c:IsSalty() and c.fresh_supply==10,"mature crop supply must be frozen")
local later=Crop(42,42)
local l=later.components.ege_crop
l:SampleWater()
assert(l.sea_supply==0 and l.fresh_supply==0,"new crop must not inherit old water")
fields:AddWater(42,42,6,"sea")
fields:AddWater(42,42,4,"fresh")
assert(not l:IsSalty())
fields:AddWater(42,42,3) -- Watering can/default source is fresh.
assert(not l:IsSalty())
later.components.farmplantstress:MakeCheckpoint()
assert(not later.components.farmplantstress.stressors.ege_salt)
local saved=l:OnSave()
local worlddata=fields:OnSave()
local loadedfields=require("components/ege_fields")(TheWorld)
loadedfields:OnLoad(worlddata)
TheWorld.components.ege_fields=loadedfields
local loaded=Crop(42,42)
loaded.components.ege_crop:OnLoad(saved)
loaded.components.ege_crop:SampleWater()
assert(loaded.components.ege_crop.sea_supply==6 and loaded.components.ege_crop.fresh_supply==7)
local before=loadedfields:AtPoint(42,42).fresh_supply
TheWorld.state.israining=true; TheWorld.state.precipitationrate=1
local flooding=TUNING.EGE.flooding
TUNING.EGE.flooding=false
loadedfields:Tick(5)
assert(loadedfields:AtPoint(42,42).fresh_supply==before)
loaded.components.ege_crop:SampleWater()
assert(loaded.components.ege_crop.fresh_supply==7)
TUNING.EGE.flooding=flooding
TheWorld.state.israining=false
fields=loadedfields
fields:AddWater(42,42,100,"sea")
assert(not loaded.components.ege_crop:IsSalty(),"sea share alone must not cause salt stress")
loadedfields:AtPoint(42,42).salt=120
assert(loaded.components.ege_crop:IsSalty(),"soil salt must cause stage stress")
TUNING.EGE.salinity=false
assert(not loaded.components.ege_crop:IsSalty())
assert(loaded.components.farmplantstress:CalcFinalStressState()==FARM_PLANT_STRESS.NONE)
print("PASS: sea/fresh supply, soil-only salt pressure without sea-share cutoff, rain, fresh dilution, per-crop reset, mature freeze, save/load and disabled option")
''')
lua.execute(r'''
local inst=CreateEntity()
inst:AddComponent("container")
inst:AddComponent("machine")
inst.components.machine.ison=true
inst:AddComponent("fueled")
inst.components.fueled:InitializeFuelLevel(100)
inst:AddComponent("ege_desalinator")
inst.spraytask={}
inst.ege_water_source="sea"
local d=inst.components.ege_desalinator
assert(d.duration==240)
local function gems(count)
    local item=Entity()
    item.prefab="bluegem"; item.count=count
    item.components.stackable={Get=function()
        item.count=item.count-1
        if item.count==0 then item:Remove() end
        return Entity()
    end}
    inst.components.container.item=item
    return item
end
local gem=gems(2)
assert(d:Process(2)==1 and gem.count==1 and d.remaining==238)
inst.components.container.item=nil
assert(d:Process(1)==1 and d.remaining==237,"removing gems must not reset purchased time")
local saved=d:OnSave()
d:OnLoad(saved)
assert(d.remaining==237)
assert(math.abs(d:Process(238)-237/238)<0.000001 and d.remaining==0)
assert(d:Process(2)==0)
gem=gems(1)
assert(d:Process(0.5)==1 and gem.count==0 and d.remaining==239.5)
local shard=Entity(); shard.prefab="alterguardianhatshard"
inst.components.container.item=shard
assert(d:Process(100)==1 and shard:IsValid() and d.remaining==239.5)
inst.components.container.item=nil
inst.components.machine.ison=false
assert(d:Process(100)==0 and d.remaining==239.5)
inst.components.machine.ison=true
inst.components.fueled.fuel=0
assert(d:Process(100)==0 and d.remaining==239.5)
inst.components.fueled.fuel=100
inst.ege_water_source="pond"
assert(d:Process(100)==0 and d.remaining==239.5)
inst.ege_water_source="sea"
d.remaining=1; gem=gems(2)
assert(d:Process(2)==1 and gem.count==1 and d.remaining==239)
d.remaining=0; gem=gems(2)
assert(math.abs(d:Process(481)-480/481)<0.000001 and gem.count==0 and d.remaining==0)
print("PASS: prepaid blue gems, fractional expiry, shard pauses credit, saves, fuel/off/fresh pauses, and live fuel meter")
''')
lua.execute(r'''
local R=require("ege_rules")
assert(R.Salt(100,0,0,100,200)==50,"actual sandbag drainage must remove salt")
assert(R.Salt(100,0,20,0)==100 and R.Salt(100,0,20,20,200)==90)
assert(R.Salt(299,50,0,0)==300)
assert(math.abs(R.Salt(50,0,0,1,1)-49)<1e-8,"tiny puddles cannot remove all concentrated salt")
assert(R.Salt(300,0,0,300,300)==0,"one full sandbag can carry 300 salt")
assert(R.Salt(20,0,0,200,200)==0,"draining all sufficiently dilute surface water must remove all salt")
assert(R.Salt(30,0,0,300,300)==0,"draining at exactly the concentration limit must clear salt")
assert(math.abs(R.Salt(1,0,0,10,100)-.9)<1e-8,"dilute salt removal must use actual concentration")
assert(math.abs(R.Salt(0,0.4*480,0,0)-96)<1e-9,"one day of seawater must accumulate 96 salt")
local seasonal_salt=0
for cycle=1,3 do
 seasonal_salt=R.Salt(seasonal_salt,0.4*480,0,0)
 assert(math.abs(seasonal_salt-96)<1e-9)
 seasonal_salt=R.Salt(seasonal_salt,0,0,1000,1000)
 assert(seasonal_salt==0)
end
TUNING.EGE.salinity=true; TUNING.EGE.flooding=true
TheWorld.state.israining=false; TheWorld.state.issummer=false; TEMPERATURE=20
TheWorld.Map.tiles["20:20"]=WORLD_TILES.FARMING_SOIL
local f=require("components/ege_fields")(TheWorld)
TheWorld.components.ege_fields=f
local manager=TheWorld.components.farming_manager
local oldcrop=Crop(82,82)
oldcrop.components.ege_crop:SampleWater()
f:AddWater(82,82,100,"sea")
local tile=f:AtPoint(82,82)
assert(tile.salt==50 and f:GetSaltLevel(82,82)==1)
f:UpdateSaltVisual(tile)
local fx=f.saltfx["20:20"]
assert(fx and fx._level:value()==1)
tile.salt=0; f:UpdateSaltVisual(tile)
local fade=fx.saltfade
assert(fx._level:value()==0 and fade)
tile.salt=120; f:UpdateSaltVisual(tile)
assert(fade.cancelled and f.saltfx["20:20"]==fx and fx._level:value()==2)
oldcrop:Remove()
local crop=Crop(82,82)
crop.components.ege_crop:SampleWater()
assert(crop.components.ege_crop.sea_supply==0 and tile.salt==120)
crop.components.farmplantstress:MakeCheckpoint()
assert(crop.components.farmplantstress.stressors.ege_salt,"new crops inherit soil pressure, not old water ratio")
f:AddWater(82,82,20,"fresh")
f:Tick(5)
assert(tile.salt==120 and crop.components.ege_crop:IsSalty())
tile.salt=200; tile.water=0; tile.fresh_pending=0; tile.salt_time=0
manager.nutrients={100,100,100}
f:Tick(5)
local salt_only=manager.nutrients[1]
assert(math.abs(salt_only-99.875)<0.000001 and tile.salt_time==5)
tile.water=200
manager.nutrients={100,100,100}
f:Tick(5)
assert(math.abs(manager.nutrients[1]-salt_only)<0.000001,"flood and salt fertility loss must not stack")
local drain=Entity(82,82,{"ege_drain"})
function drain:AbsorbWater(n) self.absorbed=(self.absorbed or 0)+n; return n end
local before=tile.salt
f:Tick(5)
assert(math.abs(tile.salt-(before-math.min(before*6/(tile.water+6),6)))<1e-8,"drained salt must follow concentration and carrying capacity")
local before_second=tile.salt
f:AddWater(82,82,20,"fresh")
f:Tick(5)
assert(math.abs(tile.salt-(before_second-math.min(before_second*6/(tile.water+6),6)))<1e-8,"additional water dilutes but drainage has limited salt capacity")
assert(tile.salt_time<15,"heavy-salt countdown should retreat after treatment")
drain:Remove()
local data=f:OnSave()
local restored=require("components/ege_fields")(TheWorld)
restored:OnLoad(data)
assert(restored:AtPoint(82,82).salt==tile.salt and restored:AtPoint(82,82).salt_time==tile.salt_time)
local legacy=require("components/ege_fields")(TheWorld)
legacy:OnLoad({version=2,tiles={old={tx=20,tz=20,water=20,flood=0,dry=0}}})
assert(legacy:AtPoint(82,82).salt==0)
TheWorld.state.israining=true; TheWorld.state.precipitationrate=1
local prior=tile.salt
f:Tick(5)
assert(tile.salt==prior,"rain alone must not wash salt")
TheWorld.state.israining=false
tile.salt=250; tile.salt_time=2000
TUNING.EGE.salinity=false
f:Tick(5)
assert(tile.salt_time==1990 and f:GetSaltLevel(82,82)==0 and f.tiles["20:20"]==tile)
TUNING.EGE.salinity=true
tile.salt=200; tile.water=0; tile.flood=0; tile.salt_time=1435; tile.fresh_pending=0
f:Tick(5)
assert(TheWorld.Map:GetTile(20,20)==WORLD_TILES.FARMING_SOIL and f.tiles["20:20"]==nil)
assert(crop.components.ege_crop.ruined and not fx:IsValid())
print("PASS: persistent soil salt, inherited soil pressure, sandbag-only salt removal, crystal levels, no stacked erosion, countdown recovery, legacy saves, and 3-day salt destruction")
''')
print("All behavior checks passed. In-game visual/network verification is still required.", flush=True)




lua.execute(r'''
TUNING.EGE.flooding=true;TUNING.EGE.salinity=true
TheWorld.state.iswinter=true;TheWorld.state.issummer=false;TheWorld.state.israining=false
TheWorld.Map.tiles["30:30"]=WORLD_TILES.FARMING_SOIL
local fields=require("components/ege_fields")(TheWorld)
TheWorld.components.ege_fields=fields
local crop=Crop(122,122,{winter=true})
local tile=fields:AtPoint(122,122);tile.water=150;tile.flood=1439
local manager=TheWorld.components.farming_manager
local old_nutrients=manager.nutrients[1]
fields:Tick(5)
assert(tile.frozen and tile.water==150 and crop.components.ege_crop.ruined,"winter flood must freeze and rot even winter crops")
assert(tile.flood==1439 and TheWorld.Map.tiles["30:30"]==WORLD_TILES.FARMING_SOIL,"frozen flood must pause damage and prevent flood destruction")
assert(manager.nutrients[1]==old_nutrients,"frozen freshwater must not erode nutrients")
tile.flood=0
TheWorld.state.iswinter=false
fields:Tick(5)
assert(not tile.frozen and tile.water<150 and crop.components.ege_crop.ruined,"thaw must resume evaporation without reviving crops")
print("PASS: winter flooded soil freezes, immediately ruins winter crops, and thaws without resurrection")
''')

# Validate actual animation material references, not just Lua interfaces.
import zipfile, struct
for kind in ("flood", "dry", "salt", "ice"):
    with zipfile.ZipFile(Path(ROOT) / "anim" / ("ege_terrain_" + kind + ".zip")) as archive:
        build = archive.read("build.bin")
        offset = 20 + struct.unpack_from("<I", build, 16)[0]
        count = struct.unpack_from("<I", build, offset)[0]
        offset += 4
        for _ in range(count):
            length = struct.unpack_from("<I", build, offset)[0]
            offset += 4
            texture = build[offset:offset+length].decode()
            offset += length
            assert texture in archive.namelist(), (kind, texture, "missing animation material")
            assert archive.read(texture).startswith(b"KTEX")
print("PASS: all four terrain builds reference existing KTEX materials")

lua.execute(r"""
local Clear=require("ege_farmland").Clear
local current=WORLD_TILES.FARMING_SOIL
local original=WORLD_TILES.DIRT or 6
local map={GetTileCoordsAtPoint=function() return 1,2 end,GetTile=function() return current end,SetTile=function(_,tx,tz,tile) current=tile end}
local under={GetTileUnderneath=function() return original end}
assert(Clear(map,under,0,0) and current==original,"ruins must reveal the undertile")
current=original
assert(not Clear(map,under,0,0) and current==original,"must preserve existing non-farming ground")
current=WORLD_TILES.FARMING_SOIL
under.GetTileUnderneath=function() return WORLD_TILES.FARMING_SOIL end
local old_dirt=WORLD_TILES.DIRT; WORLD_TILES.DIRT=6
assert(Clear(map,under,0,0) and current==6,"invalid farming-soil undertile must fall back to native dirt")
WORLD_TILES.DIRT=old_dirt
print("PASS: destroyed farmland clears to undertile; invalid undertile repaired; unrelated terrain preserved")
""")

# Frozen ground must reuse the proven water footprint exactly.
with zipfile.ZipFile(Path(ROOT)/"anim/farm_soil_moisture_flood.zip") as water, zipfile.ZipFile(Path(ROOT)/"anim/farm_soil_moisture_ice.zip") as ice:
    assert water.namelist() == ice.namelist(), "freeze must preserve the same asset layout"
    if "anim.bin" in water.namelist():
        assert water.read("anim.bin") == ice.read("anim.bin"), "freeze must not change animation matrices or direction"
    def geometry(build):
        name_length=struct.unpack_from("<I",build,16)[0]
        return build[:16]+build[20+name_length:]
    assert geometry(water.read("build.bin")) == geometry(ice.read("build.bin")), "freeze must preserve all mesh, masks and atlas references"
source=(Path(ROOT)/"scripts/prefabs/ege_flood.lua").read_text(encoding="utf-8")
assert "penguin_ice" not in source
assert 'ice.entity:SetParent(inst.entity)' in source and 'ice.Transform:SetScale(1.2,1.2,1.2)' in source
print("PASS: spare water-mask ice resources retain geometry; active selected grey ice enlarged uniformly by 20%")

with zipfile.ZipFile(Path(ROOT)/"anim/farm_soil_moisture_flood.zip") as water, zipfile.ZipFile(Path(ROOT)/"anim/farm_soil_moisture_ice.zip") as ice:
    before=water.read("atlas-0.tex"); after=ice.read("atlas-0.tex")
    count=(struct.unpack_from("<I",before,4)[0]>>13)&31
    offset=8+10*count
    assert before[:offset]==after[:offset], "ice must retain the water atlas dimensions and mip layouts"
    for level in range(count):
        length=struct.unpack_from("<I",before,8+level*10+6)[0]
        for block in range(offset,offset+length,16):
            assert before[block:block+8]==after[block:block+8], "ice must not change the water alpha mask at any mip level"
        offset+=length
print("PASS: all ice transparency blocks exactly match water, at every mip level")

lua.execute(r"""
local R=require("ege_rules")
local original={remaining=9600,repairtimes={1920,2400,10080}}
local times,left=R.RuinRecovery(original,{1,1,1})
assert(left==4800 and times[1]==960 and times[2]==1200 and times[3]==5040,"legacy ruins must halve remaining time and all stages")
local again,same=R.RuinRecovery({remaining=left,repairtimes=times,recovery_scale=0.5},{1,1,1})
assert(same==left and again[3]==times[3],"loading again must not halve recovery repeatedly")
assert(original.remaining==9600 and original.repairtimes[1]==1920,"migration must not mutate saved data")
print("PASS: ruin recovery halves old remaining time and stages exactly once")
""")
with zipfile.ZipFile(Path(ROOT)/"anim/ege_terrain_ice.zip") as ice:
    ice_build=ice.read("build.bin")
    ice_tex=ice.read("atlas-0.tex")
    for kind in ("dry","flood","salt"):
        with zipfile.ZipFile(Path(ROOT)/"anim"/("ege_terrain_"+kind+".zip")) as terrain:
            assert terrain.read("anim.bin")==ice.read("anim.bin"), "damage material must use accepted ice animation"
            assert geometry(terrain.read("build.bin"))==geometry(ice_build), "damage material must preserve accepted ice geometry"
            material=terrain.read("atlas-0.tex")
            count=(struct.unpack_from("<I",ice_tex,4)[0]>>13)&31
            offset=8+10*count
            assert material[:offset]==ice_tex[:offset]
            for level in range(count):
                length=struct.unpack_from("<I",ice_tex,8+level*10+6)[0]
                for block in range(offset,offset+length,16):
                    assert material[block:block+8]==ice_tex[block:block+8], "damage and accepted ice must share every alpha block"
                offset+=length
print("PASS: all three damage materials share accepted ice mesh, animation and exact irregular edges")

lua.execute(r"""
TheWorld.state.iswinter=false;TheWorld.state.issummer=false;TheWorld.state.israining=false
TEMPERATURE=0
local oldrange=TUNING.EGE.sandbag_range;TUNING.EGE.sandbag_range=4
local manager=TheWorld.components.farming_manager
local getsoil=manager.EGEGetSoilMoisture;manager.EGEGetSoilMoisture=function() return 100 end
local f=require("components/ege_fields")(TheWorld)
TheWorld.components.ege_fields=f
TheWorld.Map.tiles["100:100"]=WORLD_TILES.FARMING_SOIL
TheWorld.Map.tiles["101:100"]=WORLD_TILES.FARMING_SOIL
local a=f:Register(100,100);a.water=300
local b=f:Register(101,100);b.water=300
local abag=Entity(402,402,{"ege_drain"});abag.fill=0
local bbag=Entity(406,402,{"ege_drain"});bbag.fill=0
for _,bag in ipairs({abag,bbag}) do
 function bag:AbsorbWater(amount)
  local n=math.min(amount,300-self.fill);self.fill=self.fill+n;return n
 end
end
f:Tick(5)
assert(a.water==294 and b.water==294 and abag.fill==6 and bbag.fill==6,"overlapping bags must prioritize their own wet field")
for i=1,49 do f:Tick(5) end
assert(a.water==0 and b.water==0 and abag.fill==300 and bbag.fill==300,"one new bag per full field must drain all water without stranded capacity")
a.water=20;abag.fill=300;bbag.fill=280
f:Tick(5)
assert(bbag.fill==286 and a.water==14,"bag on dry farmland must still assist wet neighbours")
abag:Remove();bbag:Remove()
manager.EGEGetSoilMoisture=getsoil;TUNING.EGE.sandbag_range=oldrange
print("PASS: overlapping bags prioritize own field, drain full fields with one bag each, then assist neighbours")
""")
