local R = require("ege_rules")
local EgeCrop = Class(function(self, inst)
    self.inst = inst
    self.soak, self.temperature_dose, self.sicktime = 0,0,0
    self.blocked, self.ruined = false,false
    self.sea_supply,self.fresh_supply=0,0
    self.water_finalized=false
    inst:DoTaskInTime(0,function() self:SampleWater() end)
    self.profile = R.Profile(inst.plant_def)
    if TUNING.EGE.disease then self:AttachDisease() end
    local lootdropper = inst.components.lootdropper
    if lootdropper then
        local setup = lootdropper.lootsetupfn
        lootdropper.lootsetupfn = function(component, ...)
            local disease = inst.components.diseaseable
            if disease and disease:IsDiseased() then
                component:SetLoot({"spoiled_food"})
                return
            end
            if setup then return setup(component, ...) end
        end
    end
    local grow = inst.components.growable
    if grow then
        local resume, start = grow.Resume, grow.StartGrowing
        grow.Resume = function(component, ...)
            if not self.blocked and not self.ruined then return resume(component, ...) end
        end
        grow.StartGrowing = function(component, ...)
            local result = start(component, ...)
            if self.blocked or self.ruined then component:Pause() end
            return result
        end
    end
    local stress = inst.components.farmplantstress
    if stress then
        stress:AddStressCategory("ege_flood", function() return self:IsFlooded() end)
        stress:AddStressCategory("ege_temperature", function() return self.temperature_dose > 0 end)
        stress:AddStressCategory("ege_salt",function() return self:IsSalty() end)
        local checkpoint, final = stress.MakeCheckpoint, stress.CalcFinalStressState
        stress.MakeCheckpoint = function(component, ...)
            component:SetStressed("ege_flood",self:IsFlooded())
            component:SetStressed("ege_temperature",self.temperature_dose>0)
            component:SetStressed("ege_salt",self:IsSalty())
            return checkpoint(component, ...)
        end
        stress.CalcFinalStressState = function(component, ...)
            self:SampleWater()
            self.water_finalized=true
            local state = final(component, ...)
            if state == FARM_PLANT_STRESS.NONE and
                (TUNING.EGE.season_gate and not self:IsInSeason()) then
                component.final_stress_state = FARM_PLANT_STRESS.LOW
                return component.final_stress_state
            end
            return state
        end
    end
    local inspect = inst.components.inspectable
    if inspect then
        local old = inspect.descriptionfn
        inspect.descriptionfn = function(entity, viewer)
            local status = self:Description()
            local total=self.sea_supply+self.fresh_supply
            if total>0 then
                local water=string.format("本轮海水供水占比：%.1f%%",100*self.sea_supply/total)
                status=status and status.."\n"..water or water
            end
            local fields=TheWorld.components.ege_fields
            local x,y,z=entity.Transform:GetWorldPosition()
            local tile=fields and fields:AtPoint(x,z)
            if tile and TUNING.EGE.salinity~=false and (tile.salt or 0)>0 then
                local level=R.SaltLevel(tile.salt)
                local soil=string.format("土壤盐分：%.0f/300（%s）",tile.salt,({[0]="正常",[1]="轻度",[2]="中度",[3]="重度"})[level])
                if level==3 then soil=soil..string.format("，重度累积 %.1f/3 天",(tile.salt_time or 0)/TUNING.TOTAL_DAY_TIME) end
                status=status and status.."\n"..soil or soil
            end
            local base = old and old(entity,viewer) or nil
            return status and ((base and base.."\n" or "")..status) or base
        end
    end
    inst:DoPeriodicTask(10, function() self:Tick(10) end,1)
end)
function EgeCrop:SampleWater()
    if self.water_finalized or self.ruined then return end
    local fields=TheWorld.components.ege_fields
    local x,y,z=self.inst.Transform:GetWorldPosition()
    local tile=fields and fields:AtPoint(x,z)
    if not tile then self.water_key=nil; return end
    local key=fields:Key(tile.tx,tile.tz)
    local sea,fresh=tile.sea_supply or 0,tile.fresh_supply or 0
    if self.water_key==key then
        self.sea_supply=self.sea_supply+math.max(0,sea-(self.sea_seen or sea))
        self.fresh_supply=self.fresh_supply+math.max(0,fresh-(self.fresh_seen or fresh))
    end
    self.water_key,self.sea_seen,self.fresh_seen=key,sea,fresh
end
function EgeCrop:IsSalty()
    self:SampleWater()
    local fields=TheWorld.components.ege_fields
    local x,y,z=self.inst.Transform:GetWorldPosition()
    return TUNING.EGE.salinity~=false and fields~=nil and fields:GetSaltLevel(x,z)>=2
end
function EgeCrop:IsInSeason()
    return self.inst.plant_def.good_seasons[TheWorld.state.season] == true
end
function EgeCrop:IsFlooded()
    local fields = TheWorld.components.ege_fields
    local x,y,z = self.inst.Transform:GetWorldPosition()
    return fields ~= nil and fields:IsFlooded(x,z)
end
function EgeCrop:IsGrowingStage()
    local grow = self.inst.components.growable
    local stage = grow and grow:GetCurrentStageData()
    return stage and stage.name ~= "full" and stage.name ~= "rotten" and not self.ruined
end
function EgeCrop:CanGrowNow()
    local inst = self.inst
    if inst.components.burnable and inst.components.burnable:IsBurning() then return false end
    if not TheWorld.state.isnight then return true end
    local grow = inst.components.growable
    if grow and grow:GetCurrentStageData().night_grow then return true end
    local x,y,z = inst.Transform:GetWorldPosition()
    for _,light in ipairs(TheSim:FindEntities(x,0,z,TUNING.DAYLIGHT_SEARCH_RANGE,{"daylight","lightsource"})) do
        local radius = light.Light and light.Light:GetCalculatedRadius()*0.7 or 0
        if inst:GetDistanceSqToInst(light)<radius*radius then return true end
    end
    return false
end
function EgeCrop:AttachDisease()
    local inst = self.inst
    if not inst.components.diseaseable then inst:AddComponent("diseaseable") end
    local disease = inst.components.diseaseable
    -- Keep vanilla transmission and flies. Flood exposure, not age, seeds disease.
    if disease._delaytask then disease._delaytask:Cancel(); disease._delaytask=nil end
    local old = disease.onDiseasedFn
    disease:SetDiseasedFn(function(entity)
        if old then old(entity) end
        self.blocked = true
        if entity.components.growable then entity.components.growable:Pause() end
        entity.AnimState:SetMultColour(0.65,0.75,0.45,1)
    end)
end
function EgeCrop:Cure()
    if self.ruined or self:IsFlooded() then return false end
    local disease = self.inst.components.diseaseable
    if not disease or not (disease:IsDiseased() or disease:IsBecomingDiseased()) then return false end
    -- UM Moon Oil restores a plant. Reset only disease here, preserving the crop,
    -- cultivar, research data, accumulated stress, and remaining growth time.
    self.inst:RemoveComponent("diseaseable")
    self:AttachDisease()
    self.sicktime, self.soak = 0,0
    self.blocked = false
    self.inst.AnimState:SetMultColour(1,1,1,1)
    if self.inst.components.growable and self:CanGrowNow() then self.inst.components.growable:Resume() end
    return true
end
function EgeCrop:Rot(reason)
    if self.ruined then return end
    local inst, grow = self.inst, self.inst.components.growable
    self.ruined, self.blocked = true,true
    self.reason = reason
    if inst.components.diseaseable then inst:RemoveComponent("diseaseable") end
    inst.AnimState:SetMultColour(1,1,1,1)
    if grow then
        for index,stage in ipairs(grow.stages) do
            if stage.name == "rotten" then grow:SetStage(index); grow:StopGrowing(); return end
        end
        -- Random seeds have no rotten stage. Leave rot as visible, collectable debris.
        local rot = SpawnPrefab("spoiled_food")
        if rot then rot.Transform:SetPosition(inst.Transform:GetWorldPosition()) end
        inst:Remove()
    end
end
function EgeCrop:Tick(dt)
    if self.ruined then return end
    local inst, cfg = self.inst, TUNING.EGE
    local growing = self:IsGrowingStage()
    if growing then self:SampleWater() end
    local x,y,z = inst.Transform:GetWorldPosition()
    local fields = TheWorld.components.ege_fields
    local tile = fields and fields:AtPoint(x,z)
    local flooded = cfg.flooding and tile and tile.water >= self.profile.flood_tolerance
    if growing and flooded then self.soak = self.soak+dt*cfg.severity
    else self.soak = math.max(0,self.soak-dt) end
    if growing and cfg.temperature then
        self.temperature_dose = R.TemperatureDose(self.temperature_dose,GetTemperatureAtXZ(x,z),self.profile,dt*cfg.severity)
        if self.temperature_dose >= TUNING.TOTAL_DAY_TIME then self:Rot("低温超过了这种作物的承受范围。"); return end
    else self.temperature_dose=0 end
    local disease = inst.components.diseaseable
    if cfg.disease and disease and self.soak >= self.profile.soak_limit and not disease:IsDiseased() then
        disease:Disease()
        disease:RestartNearbySpread()
    end
    local sick = disease and disease:IsDiseased()
    if sick then self.sicktime=self.sicktime+dt*cfg.severity end
    if (sick and self.sicktime >= TUNING.TOTAL_DAY_TIME*2) or self.soak >= self.profile.soak_limit*3 then
        self:Rot("病害或长期浸泡让作物腐烂了。"); return
    end
    self.blocked = sick or (growing and flooded) or false
    local grow = inst.components.growable
    if grow then
        if self.blocked then grow:Pause()
        -- Vanilla owns night/light and burning checks; do not resume in darkness.
        elseif self:CanGrowNow() then grow:Resume() end
    end
end
function EgeCrop:Description()
    if self.ruined then return self.reason or "这株作物已经腐烂，无法治疗。" end
    local d = self.inst.components.diseaseable
    if d and d:IsDiseased() then
        return self:IsFlooded() and "病株：请先用沙袋排水，再使用农药。" or "病株：可以使用农药治疗。"
    end
    if self:IsFlooded() then return "农田积水，正在流失肥力。" end
    if self.temperature_dose > 0 then return "气温过低，持续下去会冻死。" end
    if TUNING.EGE.season_gate and not self:IsInSeason() then return "当前不应季，无法长成巨大作物。" end
    if self:IsSalty() then return "农田积盐过多，正在承受盐分压力。" end
end
function EgeCrop:OnSave()
    self:SampleWater()
    return {soak=self.soak,temperature_dose=self.temperature_dose,sicktime=self.sicktime,ruined=self.ruined,reason=self.reason,
        sea_supply=self.sea_supply,fresh_supply=self.fresh_supply,water_key=self.water_key,
        sea_seen=self.sea_seen,fresh_seen=self.fresh_seen,water_finalized=self.water_finalized}
end
function EgeCrop:OnLoad(data)
    if not data then return end
    self.sea_supply=math.max(0,tonumber(data.sea_supply) or 0)
    self.fresh_supply=math.max(0,tonumber(data.fresh_supply) or 0)
    self.water_key=data.water_key
    self.sea_seen,self.fresh_seen=tonumber(data.sea_seen),tonumber(data.fresh_seen)
    self.water_finalized=data.water_finalized==true
    self.soak=tonumber(data.soak) or 0
    self.temperature_dose=tonumber(data.temperature_dose) or 0
    self.sicktime=tonumber(data.sicktime) or 0
    self.ruined=data.ruined==true
    self.reason=data.reason
    self.inst:DoTaskInTime(0,function()
        if self.ruined and self.inst.components.growable then
            self.blocked=true
            self.inst.components.growable:StopGrowing()
        else self:Tick(0) end
    end)
end
return EgeCrop
