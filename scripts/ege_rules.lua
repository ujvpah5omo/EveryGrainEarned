-- Pure rules, in seconds and abstract surface-water units (not soil moisture).
local R = {}
function R.Clamp(x, lo, hi) return math.max(lo, math.min(hi, x)) end
function R.Profile(def)
    local seasons = def.good_seasons or {}
    local cold = seasons.winter == true
    -- Game drink rates are negative deltas. Compare magnitudes, not signs.
    local drink = math.abs(def.moisture and def.moisture.drink_rate or 0)
    local thirst = drink >= math.abs(TUNING.FARM_PLANT_DRINK_HIGH) and 1.4
        or drink <= math.abs(TUNING.FARM_PLANT_DRINK_LOW) and 0.8 or 1
    return { min = cold and -20 or 0, max = math.huge,
        flood_tolerance = 120 * thirst, soak_limit = TUNING.TOTAL_DAY_TIME * thirst }
end
function R.DrainCovers(dx,dz,range)
    if range==6.5 then return math.abs(dx)<=range and math.abs(dz)<=range end
    return dx*dx+dz*dz<=range*range
end
function R.Water(current, input, evaporation, drainage, dt)
    return R.Clamp(current + (input - evaporation - drainage) * dt, 0, 300)
end
-- Full tile receives 16 samples * 0.05 every 2 seconds.
function R.SummerEvaporation(crop_rate,natural_rate)
    return math.max(natural_rate,0.4-crop_rate)
end
-- Full-tile seawater irrigation adds about 96 salt in five default game days.
R.SEA_SALT_RATE=0.1
R.MAX_DRAIN_SALT_PER_WATER=0.5
R.SALT_MAX=300
R.SALT_LIGHT=50
R.SALT_STRESS=120
R.SALT_SEVERE=200
function R.Salt(current,sea,fresh,drained,total_water)
    -- Well-mixed salt: remove only the fraction carried out by actual drainage.
    local salt=R.Clamp(current+sea*R.SEA_SALT_RATE,0,R.SALT_MAX)
    local fraction=(total_water or 0)>0 and R.Clamp(drained/total_water,0,1) or 0
    local removed=math.min(salt*fraction,math.max(0,drained)*R.MAX_DRAIN_SALT_PER_WATER)
    return math.max(0,salt-removed)
end
function R.SaltLevel(salt)
    return salt>=R.SALT_SEVERE and 3 or salt>=R.SALT_STRESS and 2 or salt>=R.SALT_LIGHT and 1 or 0
end
function R.TemperatureDose(current, temperature, profile, dt)
    return math.max(0, current + ((temperature < profile.min or temperature > profile.max) and dt or -dt * 2))
end
-- Saved scale makes the old-save recovery migration run only once.
function R.RuinRecovery(data,default_times)
    local ratio=0.5/(tonumber(data.recovery_scale) or 1)
    local times={}
    for i=1,3 do
        times[i]=data.repairtimes and math.max(0,data.repairtimes[i]*ratio) or default_times[i]
    end
    local total=times[1]+times[2]+times[3]
    local remaining=data.remaining and math.max(0,math.min(total,data.remaining*ratio)) or total
    return times,remaining
end
return R
