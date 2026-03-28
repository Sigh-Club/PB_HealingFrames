local _, ns = ...
local Auras = ns:RegisterModule("Auras", {})
ns.Auras = Auras

local positionMap = {}

local function collectActiveAuras(unit)
    local active = {}
    if not unit then return active end
    
    -- Track both Helpful (Buffs) and Harmful (Debuffs)
    -- Helpful
    for i = 1, 40 do
        local name, _, icon, count, _, duration, expirationTime, caster = UnitAura(unit, i, "HELPFUL")
        if not name then break end
        
        local lname = string.lower(name)
        local pos = positionMap[lname]
        
        -- Special case: Beacon of Light should be tracked even if not cast by us? 
        -- Usually healers want to see THEIR beacon.
        if pos and not active[pos] then
            if caster == "player" or caster == "pet" or lname == "beacon of light" then
                active[pos] = { icon = icon, count = count, duration = duration, expires = expirationTime }
            end
        end
    end
    
    -- Harmful (Debuffs for center icon)
    for i = 1, 40 do
        local name, _, icon, count, _, duration, expirationTime = UnitAura(unit, i, "HARMFUL")
        if not name then break end
        
        local lname = string.lower(name)
        -- If we have specifically tracked debuffs for the center
        if positionMap[lname] == "center" and not active.center then
            active.center = { icon = icon, count = count, duration = duration, expires = expirationTime }
        end
    end
    
    return active
end

function Auras:OnInitialize()
    local intel = ns.HealingIntel or {}
    for pos, list in pairs(intel.trackedAuras or {}) do
        for _, name in ipairs(list) do positionMap[string.lower(name)] = pos end
    end
end

function Auras:UpdateButtonAuras(btn, cached)
    if not btn or not btn.auraIndicators then return end
    
    local active = cached
    if btn.fakeData then
        active = {}
        local t = GetTime()
        local offset = (btn.index or 0) * 1.5
        local group = btn.fakeData.group or 1
        local pos = (group - 1) % 4 + 1
        if pos == 1 then
            local dur = 15
            local expires = t + (dur - ((t + offset) % dur))
            active.topleft = { icon = "Interface\\Icons\\Spell_Nature_Rejuvenation", count = 0, duration = dur, expires = expires }
        elseif pos == 2 then
            local dur = 12
            local expires = t + (dur - ((t + offset) % dur))
            active.topright = { icon = "Interface\\Icons\\Spell_Nature_Riptide", count = 0, duration = dur, expires = expires }
        elseif pos == 3 then
            local dur = 10
            local expires = t + (dur - ((t + offset) % dur))
            active.bottomleft = { icon = "Interface\\Icons\\Spell_Holy_FlashHeal", count = 0, duration = dur, expires = expires }
        elseif pos == 4 then
            local dur = 8
            local expires = t + (dur - ((t + offset) % dur))
            active.bottomright = { icon = "Interface\\Icons\\Spell_Nature_HealingWave", count = 0, duration = dur, expires = expires }
        end
        
        -- Add a fake center debuff for demonstration in test mode
        if (group == 5) then
            active.center = { icon = "Interface\\Icons\\Spell_Shadow_ShadowWordPain", count = 0, duration = 30, expires = t + 15 }
        end
    elseif btn.unit then
        active = active or collectActiveAuras(btn.unit)
        
        -- If no center aura is set by collectActiveAuras, check if we have a curable debuff to show there
        if not active.center and btn.curableDebuff then
            local d = btn.curableDebuff
            active.center = { icon = d.texture, count = d.count or 0, duration = d.duration or 0, expires = d.expires or 0 }
        end
    end

    for pos, ind in pairs(btn.auraIndicators) do
        local data = active and active[pos]
        if data then
            ind.icon:SetTexture(data.icon)
            ind.countText:SetText((data.count and data.count > 1) and data.count or "")
            
            if data.duration and data.duration > 0 and data.expires then
                ind.cd:SetCooldown(data.expires - data.duration, data.duration)
                ind.cd:Show()
                
                ind:SetScript("OnUpdate", function(selfIndicator, _)
                    if not ns.DB.frame.showAuraTimers then
                        selfIndicator.timerText:SetText("")
                        return
                    end
                    local remain = data.expires - GetTime()
                    if remain <= 0 then
                        selfIndicator.timerText:SetText("")
                        selfIndicator:SetScript("OnUpdate", nil)
                    else
                        if remain < 2.5 then
                            selfIndicator.timerText:SetTextColor(1, 0.1, 0.1)
                        elseif remain < 5 then
                            selfIndicator.timerText:SetTextColor(1, 0.8, 0)
                        else
                            selfIndicator.timerText:SetTextColor(1, 1, 1)
                        end
                        
                        if remain > 10 then
                            selfIndicator.timerText:SetText(math.floor(remain))
                        else
                            selfIndicator.timerText:SetText(string.format("%.1f", remain))
                        end
                    end
                end)
            else
                ind.cd:Hide()
                ind.timerText:SetText("")
                ind:SetScript("OnUpdate", nil)
            end
            ind:Show()
        else
            ind:Hide()
            ind:SetScript("OnUpdate", nil)
        end
    end
end

function Auras:OnEvent(event, unit)
    if event == "UNIT_AURA" then
        for _, b in ipairs(ns.Frames.buttons) do
            if b.unit == unit then self:UpdateButtonAuras(b) end
        end
    end
end
