local R = require("ege_rules")
local Shade=require("ege_shade")
local STEP = 5
local EgeFields = Class(function(self, inst)
    self.inst = inst
    self.tiles = {}
    self.fx = {}
    self.saltfx={}
    self.damagefx={}
    self.internal_water = false
    inst:ListenForEvent("onterraform", function(_, data)
        if data then self:Register(data.x, data.y) end
    end)
    inst:DoTaskInTime(0, function()
        local w, h = inst.Map:GetSize()
        for x = 0, w - 1 do for z = 0, h - 1 do
            if inst.Map:GetTile(x,z) == WORLD_TILES.FARMING_SOIL then self:Register(x,z) end
        end end
    end)
    inst:DoPeriodicTask(STEP, function() self:Tick(STEP) end)
end)
function EgeFields:Key(tx,tz) return tx .. ":" .. tz end
function EgeFields:IsRuined(tx,tz)
    local map=self.inst.Map
    local x,_,z=map:GetTileCenterPoint(tx,tz)
    for _,ruin in ipairs(TheSim:FindEntities(x,0,z,3,{"ege_ruined_field"})) do
        local rx,_,rz=ruin.Transform:GetWorldPosition()
        local a,b=map:GetTileCoordsAtPoint(rx,0,rz)
        if a==tx and b==tz then return true end
    end
    return false
end
function EgeFields:Register(tx,tz)
    local key = self:Key(tx,tz)
    if self.inst.Map:GetTile(tx,tz) ~= WORLD_TILES.FARMING_SOIL or self:IsRuined(tx,tz) then
        self.tiles[key] = nil
        for _,kind in ipairs({"cracks"}) do
            local k=key..kind
            if self.damagefx[k] then self.damagefx[k]:Remove(); self.damagefx[k]=nil end
        end
        if self.fx[key] then self.fx[key]:Remove(); self.fx[key] = nil end
        if self.saltfx[key] then self.saltfx[key]:Remove(); self.saltfx[key]=nil end
        return
    end
    if not self.tiles[key] then self.tiles[key] = {tx=tx,tz=tz,water=0,flood=0,dry=0,sea_supply=0,fresh_supply=0,salt=0,salt_time=0,fresh_pending=0} end
    return self.tiles[key]
end
function EgeFields:AtPoint(x,z)
    local tx,tz = self.inst.Map:GetTileCoordsAtPoint(x,0,z)
    return self:Register(tx,tz)
end
function EgeFields:AddWater(x,z,amount,source,soil_first)
    local tile = self:AtPoint(x,z)
    if tile and TUNING.EGE.flooding and not soil_first then tile.water = R.Clamp(tile.water + amount,0,300) end
    if tile and amount>0 then
        local key=source=="sea" and "sea_supply" or "fresh_supply"
        tile[key]=(tile[key] or 0)+amount
        if TUNING.EGE.salinity~=false then
            if source=="sea" then tile.salt=R.Salt(tile.salt or 0,amount,0,0)
            else tile.fresh_pending=(tile.fresh_pending or 0)+amount end
        end
    end
end
function EgeFields:GetSaltLevel(x,z)
    local tile=self:AtPoint(x,z)
    return TUNING.EGE.salinity~=false and tile and R.SaltLevel(tile.salt or 0) or 0
end
function EgeFields:UpdateSaltVisual(tile)
    local key=self:Key(tile.tx,tile.tz)
    local x,y,z=self.inst.Map:GetTileCenterPoint(tile.tx,tile.tz)
    local level=TUNING.EGE.salinity~=false and R.SaltLevel(tile.salt or 0) or 0
    local fx=self.saltfx[key]
    if level>0 then
        if not fx or not fx:IsValid() then
            fx=SpawnPrefab("ege_salt_fx")
            self.saltfx[key]=fx
            if fx then fx.Transform:SetPosition(x,0,z); fx.Transform:SetScale(0.65,1,0.65) end
        end
        if fx then
            if fx.saltfade then fx.saltfade:Cancel(); fx.saltfade=nil end
            fx:SetLevel(level)
        end
    elseif fx and fx:IsValid() and not fx.saltfade then
        fx:SetLevel(0)
        fx.saltfade=fx:DoTaskInTime(1,function()
            if fx:IsValid() then fx:Remove() end
            if self.saltfx[key]==fx then self.saltfx[key]=nil end
        end)
    end
end
-- Visual damage follows the actual destruction clocks, not water quantity alone.
function EgeFields:UpdateDamageVisual(tile)
    local key=self:Key(tile.tx,tile.tz)
    local x,y,z=self.inst.Map:GetTileCenterPoint(tile.tx,tile.tz)
    local day=TUNING.TOTAL_DAY_TIME
    local flood,dry,salt=tile.flood/(day*3),tile.dry/day,
        TUNING.EGE.salinity~=false and (tile.salt_time or 0)/(day*3) or 0
    local cause=salt>=flood and salt>=dry and "salt" or flood>=dry and "flood" or "dry"
    local progress={cracks=math.max(flood,dry,salt)}
    for kind,ratio in pairs(progress) do
        local level=ratio>=0.4 and 2 or ratio>=0.1 and 1 or 0
        local k=key..kind
        local fx=self.damagefx[k]
        if level>0 and (not fx or not fx:IsValid()) then
            fx=SpawnPrefab("ege_damage_"..kind)
            self.damagefx[k]=fx
            if fx then fx.Transform:SetPosition(x,0,z); fx.Transform:SetScale(0.65,1,0.65) end
        end
        if fx then
            fx:SetLevel(level)
            if fx.SetCause then fx:SetCause(cause) end
            if fx.SetFrozen then fx:SetFrozen(tile.frozen) end
            if level==0 and not fx.ege_cleanup then
                fx.ege_cleanup=fx:DoTaskInTime(1,function()
                    if fx:IsValid() then fx:Remove() end
                    if self.damagefx[k]==fx then self.damagefx[k]=nil end
                end)
            elseif level>0 and fx.ege_cleanup then
                fx.ege_cleanup:Cancel(); fx.ege_cleanup=nil
            end
        end
    end
end
function EgeFields:IsFlooded(x,z)
    local tile = self:AtPoint(x,z)
    return TUNING.EGE.flooding and tile ~= nil and tile.water >= 100
end
function EgeFields:DestroyTile(tile)
    local map = self.inst.Map
    if map:GetTile(tile.tx,tile.tz) ~= WORLD_TILES.FARMING_SOIL then return end
    local x,y,z = map:GetTileCenterPoint(tile.tx,tile.tz)
    for _,ent in ipairs(map:GetEntitiesOnTileAtPoint(x,0,z)) do
        if ent:IsValid() then
            if ent:HasTag("farm_plant") and ent.components.ege_crop then
                ent.components.ege_crop:Rot("rot_field")
            elseif ent:HasTag("soil") then ent:PushEvent("collapsesoil") end
        end
    end
    local cause=(tile.salt_time or 0)>=TUNING.TOTAL_DAY_TIME*3 and "salt"
        or tile.flood>=TUNING.TOTAL_DAY_TIME*3 and "flood" or "dry"
    local ruined=SpawnPrefab("ege_ruined_field")
    if ruined then
        ruined.Transform:SetPosition(x,0,z)
        if ruined.SetCause then ruined:SetCause(cause) end
        if ruined.StartCollapse then ruined:StartCollapse() end
    end
end
function EgeFields:Tick(dt)
    local cfg, manager, map = TUNING.EGE, self.inst.components.farming_manager, self.inst.Map
    if not manager then return end
    local dead = {}
    for key,tile in pairs(self.tiles) do
        if map:GetTile(tile.tx,tile.tz) ~= WORLD_TILES.FARMING_SOIL or self:IsRuined(tile.tx,tile.tz) then
            self:Register(tile.tx,tile.tz)
        else
            local x,y,z = map:GetTileCenterPoint(tile.tx,tile.tz)
            local temp = GetTemperatureAtXZ(x,z)
            tile.frozen=self.inst.state.iswinter and tile.water>=100 or false
            if tile.frozen then
                for _,plant in ipairs(map:GetEntitiesOnTileAtPoint(x,0,z)) do
                    if plant:HasTag("farm_plant") and plant.components.ege_crop then
                        plant.components.ege_crop:Rot("rot_ice")
                    end
                end
            end
            local input = 0 -- Native rainfall is accounted for by ege_hydrology.
            -- Integrate nearby UM waterfalls without adding a second flood system.
            local falls = TheSim:FindEntities(x,0,z,12,{"um_waterfall"},{"INLIMBO"})
            if #falls > 0 then input = input + 1.2 end
            if input>0 then manager:AddSoilMoistureAtPoint(x,0,z,input*dt,"ege_fresh") end
            if not tile.frozen and manager.EGEGetSoilMoisture and tile.water>0 then
                local missing=math.max(0,(TUNING.SOIL_MAX_MOISTURE_VALUE or 100)-manager:EGEGetSoilMoisture(x,z))
                local transfer=math.min(tile.water,missing)
                self.internal_water=true
                manager:AddSoilMoistureAtPoint(x,0,z,transfer)
                self.internal_water=false
                tile.water=tile.water-transfer
            end
            -- With surface water present, evaporate here instead of again from soil.
            local lo=TUNING.SOIL_MIN_DRYING_TEMP or 0
            local hi=TUNING.SOIL_MAX_DRYING_TEMP or 70
            local fraction=R.Clamp((temp-lo)/(hi-lo),0,1)
            local rate=(TUNING.SOIL_MIN_TEMP_DRY_RATE or 0)+fraction*
                ((TUNING.SOIL_MAX_TEMP_DRY_RATE or -0.05)-(TUNING.SOIL_MIN_TEMP_DRY_RATE or 0))
            local evaporation=math.max(0,-rate)
            if self.inst.state.issummer and manager.EGEGetCropWaterRate then
                evaporation=R.SummerEvaporation(manager:EGEGetCropWaterRate(tile.tx,tile.tz),evaporation)
            end
            if Shade.IsSheltered(x,z) then evaporation=evaporation*0.5 end
            if tile.frozen then evaporation=0 end
            local water=cfg.flooding and math.max(0,tile.water-evaporation*dt) or 0
            local salt_water=water -- Only drainable surface water carries the dissolved salt.
            local drained=0
            local absorbers={}
            local range=cfg.sandbag_range or 4
            local searchrange=range==6.5 and range*math.sqrt(2) or range
            for _,bag in ipairs(TheSim:FindEntities(x,0,z,searchrange,{"ege_drain"},{"INLIMBO"})) do
                local bx,by,bz=bag.Transform:GetWorldPosition()
                local bagtx,bagtz=map:GetTileCoordsAtPoint(bx,0,bz)
                local own=self.tiles[self:Key(bagtx,bagtz)]
                -- A bag placed on wet farmland reserves capacity for its own tile.
                -- It can assist neighbours only after that tile has no surface water.
                local ownwet=own and own.water>0 and map:GetTile(bagtx,bagtz)==WORLD_TILES.FARMING_SOIL
                local canhelp=not ownwet or (bagtx==tile.tx and bagtz==tile.tz)
                if canhelp and R.DrainCovers(bx-x,bz-z,range) and not tile.frozen and water>0 and bag.AbsorbWater then
                    local absorbed=bag:AbsorbWater(math.min(water,1.2*dt))
                    water=water-absorbed
                    drained=drained+absorbed
                    absorbers[#absorbers+1]={bag=bag,water=absorbed}
                end
            end
            tile.water=R.Clamp(water,0,300)
            if cfg.salinity~=false then
                local before=tile.salt or 0
                tile.salt=R.Salt(before,0,(tile.fresh_pending or 0)+input*dt,drained,salt_water)
                if drained>0 then
                    local removed=before-tile.salt
                    for _,entry in ipairs(absorbers) do
                        if entry.bag.RecordSalt then entry.bag:RecordSalt(removed*entry.water/drained) end
                    end
                end
            end
            tile.fresh_pending=0
            local severe=cfg.salinity~=false and (tile.salt or 0)>=R.SALT_SEVERE
            tile.salt_time=severe and (tile.salt_time or 0)+dt*cfg.severity or math.max(0,(tile.salt_time or 0)-dt*2)
            self:UpdateSaltVisual(tile)
            if tile.water <= 0 then tile.flood = 0
            elseif tile.water >= 100 and not tile.frozen then tile.flood = tile.flood + dt * cfg.severity
            elseif tile.water < 100 then tile.flood = math.max(0,tile.flood-dt*2) end
            if tile.water > 0 then
                if not self.fx[key] then
                    self.fx[key] = SpawnPrefab("ege_flood")
                    if self.fx[key] then self.fx[key].Transform:SetPosition(x,0,z) end
                end
                if self.fx[key] and self.fx[key].SetFrozen then self.fx[key]:SetFrozen(tile.frozen) end
                if self.fx[key] and self.fx[key].SetWaterDepth then self.fx[key]:SetWaterDepth(tile.water) end
            else
                if self.fx[key] then self.fx[key]:Remove(); self.fx[key]=nil end
            end
            -- Salt and flood erosion share one rate; do not stack the penalties.
            if severe or (tile.water>=100 and not tile.frozen) then
                local loss=-dt*0.025*cfg.severity
                manager:AddTileNutrients(tile.tx,tile.tz,loss,loss,loss)
            end
            if tile.water>0 or manager:IsSoilMoistAtPoint(x,0,z) then
                tile.dry_grace=0
                tile.dry=0
            elseif cfg.drought and self.inst.state.issummer then
                local previous=tile.dry_grace or 0
                tile.dry_grace=previous+dt
                local grace=TUNING.TOTAL_DAY_TIME
                local exposed=math.max(0,tile.dry_grace-grace)-math.max(0,previous-grace)
                tile.dry = tile.dry + exposed*cfg.severity
            else
                tile.dry_grace=0
                tile.dry = math.max(0,tile.dry-dt*2)
            end
            self:UpdateDamageVisual(tile)
            if (not tile.frozen and tile.flood >= TUNING.TOTAL_DAY_TIME*3) or tile.dry >= TUNING.TOTAL_DAY_TIME
                or (cfg.salinity~=false and tile.salt_time>=TUNING.TOTAL_DAY_TIME*3) then
                dead[#dead+1] = tile
            end
        end
    end
    for _,tile in ipairs(dead) do self:DestroyTile(tile); self:Register(tile.tx,tile.tz) end
end
function EgeFields:OnSave() return {tiles=self.tiles,version=4} end
function EgeFields:OnLoad(data)
    if data and data.tiles then
        for key,tile in pairs(data.tiles) do
            if type(tile)=="table" and type(tile.tx)=="number" and type(tile.tz)=="number" then
                local current = self:Register(tile.tx,tile.tz)
                if current then
                    current.water = R.Clamp(tonumber(tile.water) or 0,0,300)
                    current.flood = math.max(0,tonumber(tile.flood) or 0)
                    current.dry = math.max(0,tonumber(tile.dry) or 0)
                    current.dry_grace=math.max(0,tonumber(tile.dry_grace) or 0)
                    current.sea_supply=math.max(0,tonumber(tile.sea_supply) or 0)
                    current.fresh_supply=math.max(0,tonumber(tile.fresh_supply) or 0)
                    current.salt=R.Clamp(tonumber(tile.salt) or 0,0,R.SALT_MAX)
                    current.salt_time=math.max(0,tonumber(tile.salt_time) or 0)
                    current.fresh_pending=math.max(0,tonumber(tile.fresh_pending) or 0)
                end
            end
        end
    end
end
return EgeFields
