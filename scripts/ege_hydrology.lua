local M={}
local function Upvalue(fn,name,seen,depth)
    if type(fn)~="function" or not debug or not debug.getupvalue or depth>5 or seen[fn] then return end
    seen[fn]=true
    local functions={}
    for i=1,100 do
        local key,value=debug.getupvalue(fn,i)
        if not key then break end
        if key==name then return value end
        if type(value)=="function" then functions[#functions+1]=value end
    end
    for _,value in ipairs(functions) do
        local result=Upvalue(value,name,seen,depth+1)
        if result then return result end
    end
end
function M.Install(manager)
    local old=manager.AddSoilMoistureAtPoint
    local grid=Upvalue(old,"_moisturegrid",{},0)
    if manager.ege_hydrology_installed then return true end
    -- Native grids are nil until worldmapsetsize, including during ComponentPostInit.
    if not grid then return false end
    local maxmoisture=TUNING.SOIL_MAX_MOISTURE_VALUE or 100
    manager.EGEGetSoilMoisture=function(_,x,z)
        return grid:GetDataAtPoint(TheWorld.Map:GetTileCoordsAtPoint(x,0,z)) or TheWorld.state.wetness or 0
    end
    manager.AddSoilMoistureAtPoint=function(self,x,y,z,amount,source,...)
        local before=self:EGEGetSoilMoisture(x,z)
        local result=old(self,x,y,z,amount,source,...)
        local fields=TheWorld.components.ege_fields
        if fields and amount and amount>0 and not fields.internal_water then
            fields:AddWater(x,z,amount,source=="ege_sea" and "sea" or "fresh",true)
            local tile=fields:AtPoint(x,z)
            if tile and TUNING.EGE.flooding then
                tile.water=math.min(300,tile.water+math.max(0,before+amount-maxmoisture))
            end
        end
        return result
    end
    local refresh=manager._RefreshSoilMoisture
    local drinkers=Upvalue(refresh,"_drinkersgrid",{},0)
    if not drinkers then error("EveryGrainEarned: cannot access native soil drinkers grid") end
    manager.EGEGetCropWaterRate=function(_,tx,tz)
        local plants=drinkers:GetDataAtIndex(grid:GetIndex(tx,tz))
        local rate=0
        for plant in pairs(plants or {}) do
            local component=plant.components.farmsoildrinker
            if component then rate=rate+component:GetMoistureRate() end
        end
        return math.max(0,-rate)
    end
    local Shade=require("ege_shade")
    manager._RefreshSoilMoisture=function(self,dt,...)
        local fields=TheWorld.components.ege_fields
        local records={}
        if fields then
            for _,tile in pairs(fields.tiles) do
                local x,y,z=TheWorld.Map:GetTileCenterPoint(tile.tx,tile.tz)
                local before=self:EGEGetSoilMoisture(x,z)
                local rain=TheWorld.state.israining and (TheWorld.state.precipitationrate or 0)*(TUNING.SOIL_RAIN_MOD or 1.5) or 0
                local rate=0
                if rain>0 then rate=rain
                else
                    local temp=GetTemperatureAtXZ(x,z)
                    local lo,hi=TUNING.SOIL_MIN_DRYING_TEMP,TUNING.SOIL_MAX_DRYING_TEMP
                    local f=math.max(0,math.min(1,(temp-lo)/(hi-lo)))
                    rate=TUNING.SOIL_MIN_TEMP_DRY_RATE+f*(TUNING.SOIL_MAX_TEMP_DRY_RATE-TUNING.SOIL_MIN_TEMP_DRY_RATE)
                    if Shade.IsSheltered(x,z) then rate=rate*0.5 end
                    if tile.water>0 then rate=0 end
                end
                local index=grid:GetIndex(tile.tx,tile.tz)
                local plants=drinkers and drinkers:GetDataAtIndex(index)
                for plant in pairs(plants or {}) do rate=rate+plant.components.farmsoildrinker:GetMoistureRate() end
                local wet=TheWorld.state.wetness or 0
                local expected=before<wet and wet or before+rate*dt
                records[#records+1]={tile=tile,x=x,z=z,target=math.max(wet,math.min(maxmoisture,expected)),overflow=math.max(0,expected-maxmoisture),rain=rain*dt}
            end
        end
        local result=refresh(self,dt,...)
        for _,r in ipairs(records) do
            old(self,r.x,0,r.z,r.target-self:EGEGetSoilMoisture(r.x,r.z))
            if TUNING.EGE.flooding then r.tile.water=math.min(300,r.tile.water+r.overflow) end
            r.tile.fresh_supply=(r.tile.fresh_supply or 0)+r.rain
        end
        return result
    end
    manager.ege_hydrology_installed=true
    return true
end
return M
