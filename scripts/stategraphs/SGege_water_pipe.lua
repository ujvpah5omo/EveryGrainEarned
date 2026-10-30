local function FinishRetraction(inst)
    if inst.ege_retracted then return end
    inst.ege_retracted=true
    if inst._prev and inst._prev:IsValid() then inst._prev.sg:GoToState("retract") end
    inst:Remove()
end
-- Cloud Country/Hamlet-style sequential pipe placement and retraction.
local states={
    State{name="hidden",onenter=function(inst) inst:Hide() end},
    State{name="idle",onenter=function(inst)
        inst:Show()
        inst.AnimState:PlayAnimation("idle",true)
    end},
    State{name="extend",onenter=function(inst,intensity)
        inst:Show()
        inst.AnimState:PlayAnimation("place",false)
        inst.sg.statemem.intensity=intensity or 1
    end,events={EventHandler("animover",function(inst)
        if inst._next and inst._next:IsValid() then
            inst._next.sg:GoToState("extend",inst.sg.statemem.intensity+1)
        end
        inst.sg:GoToState("idle")
    end)}},
    State{name="retract",onenter=function(inst)
        inst:Show()
        inst.AnimState:PlayAnimation("retract",false)
        inst:DoTaskInTime(math.max(0.1,inst.AnimState:GetCurrentAnimationLength())+0.1,FinishRetraction)
    end,events={EventHandler("animover",function(inst)
        FinishRetraction(inst)
    end)}},
}
return StateGraph("ege_water_pipe",states,{},"hidden")
