local M={}
function M.Apply(definitions)
    for _,def in pairs(definitions) do
        local times=def.grow_time
        if times and not times.ege_growth_applied then
            if not times.pro2hm then
                for _,name in ipairs({"seed","sprout","small","med"}) do
                    local range=times[name]
                    if type(range)=="table" and type(range[1])=="number" and type(range[2])=="number" then
                        range[1]=range[1]*2
                        range[2]=range[2]*2
                    end
                end
                -- Shadow World uses this same marker to avoid touching a table twice.
                times.pro2hm=true
                times.ege_growth_applied=2
            else
                -- Respect a multiplier already applied by Shadow World.
                times.ege_growth_applied="external"
            end
        end
    end
end
return M
