-- Purchased processing time belongs to the machine, never to the removable gem.
local EgeDesalinator=Class(function(self,inst)
    self.inst=inst
    self.remaining=0
    self.duration=TUNING.TOTAL_DAY_TIME/2
end)
function EgeDesalinator:GetInsert()
    local container=self.inst.components.container
    local item=container and container:GetItemInSlot(1)
    return item and item:IsValid() and item or nil
end
function EgeDesalinator:HasShard()
    local item=self:GetInsert()
    return item~=nil and item.prefab=="alterguardianhatshard"
end
function EgeDesalinator:RefreshVisual()
    local inst=self.inst
    local working=inst.spraytask~=nil and inst.components.machine and inst.components.machine:IsOn()
    local active=inst.spraytask and inst.components.machine and inst.components.machine:IsOn()
        and inst.ege_water_source=="sea" and (self:HasShard() or self.remaining>0)
    if inst.AnimState.SetLightOverride then inst.AnimState:SetLightOverride(active and 0.3 or working and 0.1 or 0) end
    inst.AnimState:SetAddColour(0,0,0,0)
    if inst.AnimState.SetSymbolAddColour then
        inst.AnimState:SetSymbolAddColour("tank",working and 0.06 or 0,working and 0.06 or 0,working and 0.06 or 0,0)
    end
    if inst.magic_core and inst.magic_core:IsValid() then inst.magic_core:SetCore(self:HasShard(),active) end
    if inst.UpdateSprayColour then inst:UpdateSprayColour() end
end
function EgeDesalinator:Process(dt)
    local inst=self.inst
    if dt<=0 or inst.ege_water_source~="sea" or not inst.components.machine:IsOn()
        or inst.components.fueled:IsEmpty() then return 0 end
    if self:HasShard() then self:RefreshVisual(); return 1 end
    local fresh,left=0,dt
    while left>0 do
        if self.remaining<=0 then
            local item=self:GetInsert()
            if not item or item.prefab~="bluegem" then break end
            -- Pay before dispensing even the first drop.
            if item.components.stackable then item.components.stackable:Get():Remove()
            else inst.components.container:RemoveItemBySlot(1):Remove() end
            self.remaining=self.duration
            if inst.SoundEmitter then inst.SoundEmitter:PlaySound("dontstarve/common/gem_shatter") end
        end
        local used=math.min(left,self.remaining)
        self.remaining=math.max(0,self.remaining-used)
        left=left-used
        fresh=fresh+used
    end
    self:RefreshVisual()
    return fresh/dt
end
function EgeDesalinator:OnSave() return {remaining=self.remaining} end
function EgeDesalinator:OnLoad(data)
    self.remaining=math.max(0,tonumber(data and data.remaining) or 0)
    self:RefreshVisual()
end
return EgeDesalinator
