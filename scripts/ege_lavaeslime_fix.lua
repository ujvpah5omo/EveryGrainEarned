local M={}
function M.Apply(inst)
    if inst.prefab~="lavaeslime" or not inst.components.burnable then return end
    local burnable=inst.components.burnable
    if burnable.ege_preserve_burn_time then return end
    burnable.ege_preserve_burn_time=true
    local old=burnable.Extinguish
    burnable.Extinguish=function(component,...)
        local remaining=component.burning and component.task and GetTaskRemaining(component.task)
        local duration=component.burntime
        -- UM immediately re-ignites in onextinguish; its new timer must use
        -- the old remaining duration rather than starting another full fuse.
        if remaining~=nil then component.burntime=math.max(0,remaining) end
        local result=old(component,...)
        component.burntime=duration
        return result
    end
end
return M
