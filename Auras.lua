local _, ns = ...
local Auras = ns:RegisterModule("Auras", {})
ns.Auras = Auras

local hotPriorityNames = {}
local hotPriorityIds = {}
local centerNames = {}
local centerIds = {}
local auraCache = {}
local collectActiveAuras
local samplingEnabled = false
local fallbackTrackedAuras = {
    topleft = {
        774, 26982, 139, 61295, 61299, 53601, 33763,
        "Renew", "Rejuvenation", "Lifebloom", "Wild Growth", "Prayer of Mending",
        "Renewing Mist", "Enveloping Mist", "Soothing Mist", "Chi Wave", "Chi Burst",
        "Healing Rain", "Healing Stream Totem", "Cloudburst Totem", "Flourishing Tranquility",
        "Renewing Light", "Rejuvenating Swiftness", "Cauterizing Flames", "Cauterizing Fire",
        "Glimmer of Light", "Beacon of Virtue", "Blessed Recovery"
    },
    bottomleft = { 17, 48066, 47753, 552, 8936, "Shields of Dominance", "Dominant Word: Shield" },
    topright = { 33076, 53563, 48438, "Sheath of Light", "Improved Power Word: Shield", "Borrowed Time" },
    bottomright = { 2893, 6346, 33206, 47788 },
    center = { 53563, 974, "Beacon of Light", "Beacon of Virtue", "Earth Shield", "Sacred Shield" },
}

local function getSampleBucket()
    PB_HF_Global = PB_HF_Global or {}
    PB_HF_Global.auraSamples = PB_HF_Global.auraSamples or {}
    return PB_HF_Global.auraSamples
end

local function logAuraSample(unit, name, spellId, caster)
    if not name then return end
    local bucket = getSampleBucket()
    local key = spellId or string.lower(name)
    local entry = bucket[key]
    if not entry then
        entry = { name = name, spellId = spellId, count = 0, units = {}, casters = {} }
        bucket[key] = entry
    end
    entry.count = entry.count + 1
    entry.units[unit or "?"] = true
    if caster then
        local casterName = UnitName(caster) or caster
        entry.casters[casterName or "?"] = true
    end
    entry.lastSeen = time()
end

local function recordSamples(unit)
    if not samplingEnabled or not unit then return end
    for i = 1, 40 do
        local name, _, _, _, _, _, _, caster, _, _, spellId = UnitAura(unit, i, "HELPFUL")
        if not name then break end
        logAuraSample(unit, name, spellId, caster)
    end
end

local function addHotEntry(entry, priority)
    local kind = type(entry)
    if kind == "table" then
        if entry.spellId then addHotEntry(entry.spellId, priority) end
        if entry.id then addHotEntry(entry.id, priority) end
        if entry.name then addHotEntry(entry.name, priority) end
        if entry.names then for _, name in ipairs(entry.names) do addHotEntry(name, priority) end end
        if entry.spells then for _, id in ipairs(entry.spells) do addHotEntry(id, priority) end end
        for _, value in ipairs(entry) do addHotEntry(value, priority) end
        return
    elseif kind == "number" then
        hotPriorityIds[entry] = hotPriorityIds[entry] or priority
        local name = GetSpellInfo(entry)
        if name and name ~= "" then
            hotPriorityNames[string.lower(name)] = hotPriorityNames[string.lower(name)] or priority
        end
    elseif kind == "string" and entry ~= "" then
        local lname = string.lower(entry)
        hotPriorityNames[lname] = hotPriorityNames[lname] or priority
        local _, _, _, _, _, _, sid = GetSpellInfo(entry)
        if sid then
            hotPriorityIds[sid] = hotPriorityIds[sid] or priority
        end
    end
end

local function addCenterEntry(entry)
    local kind = type(entry)
    if kind == "table" then
        if entry.spellId then addCenterEntry(entry.spellId) end
        if entry.id then addCenterEntry(entry.id) end
        if entry.name then addCenterEntry(entry.name) end
        if entry.names then for _, name in ipairs(entry.names) do addCenterEntry(name) end end
        if entry.spells then for _, id in ipairs(entry.spells) do addCenterEntry(id) end end
        for _, value in ipairs(entry) do addCenterEntry(value) end
        return
    elseif kind == "number" then
        centerIds[entry] = true
        local name = GetSpellInfo(entry)
        if name and name ~= "" then
            centerNames[string.lower(name)] = true
        end
    elseif kind == "string" and entry ~= "" then
        local lname = string.lower(entry)
        centerNames[lname] = true
        local _, _, _, _, _, _, sid = GetSpellInfo(entry)
        if sid then
            centerIds[sid] = true
        end
    end
end

local function getTrackedSource()
    local intel = ns.HealingIntel or {}
    if intel.trackedAuras and next(intel.trackedAuras) then return intel.trackedAuras end
    if ns.HealingIntelDefaults and ns.HealingIntelDefaults.trackedAuras then
        return ns.HealingIntelDefaults.trackedAuras
    end
    return fallbackTrackedAuras
end

local function rebuildTrackedNames()
    wipe(hotPriorityNames)
    wipe(hotPriorityIds)
    wipe(centerNames)
    wipe(centerIds)
    wipe(auraCache)
    local source = getTrackedSource()
    if not source then return end
    local priorityIndex = 1
    for _, slot in ipairs({"topleft", "bottomleft", "topright", "bottomright"}) do
        local list = source[slot]
        if type(list) == "table" then
            for _, entry in ipairs(list) do addHotEntry(entry, priorityIndex) end
            priorityIndex = priorityIndex + 1
        end
    end
    local centerList = source.center or {}
    if type(centerList) == "table" then
        for _, entry in ipairs(centerList) do addCenterEntry(entry) end
    end
    if ns.BuildState and ns.BuildState.GetMaintenanceAuras then
        local maint = ns.BuildState:GetMaintenanceAuras()
        for lname, displayName in pairs(maint) do
            local isSpecial = (lname == "beacon of light" or lname == "earth shield" or lname == "sacred shield" or lname == "low tide")
            if isSpecial then
                addCenterEntry(displayName)
            elseif not hotPriorityNames[lname] then
                addHotEntry(displayName, 1)
            end
        end
    end
end

function Auras:RebuildTrackedNames()
    rebuildTrackedNames()
end

local function hasTrackedData()
    return next(hotPriorityNames) ~= nil or next(hotPriorityIds) ~= nil
end

local function scanAndStore(unit)
    if not unit then return nil end
    if not hasTrackedData() then rebuildTrackedNames() end
    auraCache[unit] = collectActiveAuras(unit)
    return auraCache[unit]
end

function Auras:WipeCache()
    wipe(auraCache)
end

function Auras:GetUnitAuras(unit)
    if not unit then return nil end
    if not hasTrackedData() then rebuildTrackedNames() end
    if not auraCache[unit] then
        auraCache[unit] = collectActiveAuras(unit)
    end
    return auraCache[unit]
end

collectActiveAuras = function(unit)
    local active = { hotList = {} }
    if not unit or not UnitExists(unit) then return active end
    if not hasTrackedData() then rebuildTrackedNames() end

    local hotBuckets = {}
    local foundAuras = {}
    for i = 1, 40 do
        local name, _, icon, count, _, duration, expirationTime, caster, _, _, spellId = UnitAura(unit, i, "HELPFUL")
        if not name then break end
        local lname = string.lower(name)
        foundAuras[lname] = true

        local isMine = false
        if caster then
            if UnitIsUnit(caster, "player") or UnitIsUnit(caster, "pet") or caster == "player" or caster == "pet" then
                isMine = true
            end
        end

        -- Special/Center Indicator (Beacon, Earth Shield, etc.)
        local isCenter = (spellId and centerIds[spellId]) or centerNames[lname]
        local isSpecialSpell = (lname == "beacon of light" or lname == "earth shield" or lname == "sacred shield" or lname == "low tide")
        if isCenter and (isMine or isSpecialSpell) then
            active.center = { 
                icon = icon, count = count, duration = duration, expires = expirationTime, 
                isMine = isMine 
            }
        end

        -- Corner Indicators (hotList)
        local priority = (spellId and hotPriorityIds[spellId]) or hotPriorityNames[lname]
        -- CRITICAL: Only track MY OWN hots in corners, and exclude special/topright spells (Beacon/Earth Shield)
        local isSpecial = isSpecialSpell
        if priority and priority <= 4 and isMine and not isSpecial then
            hotBuckets[priority] = hotBuckets[priority] or {}
            table.insert(hotBuckets[priority], { 
                icon = icon, count = count, duration = duration, expires = expirationTime, 
                isMine = true 
            })
        end
    end

    -- Populate hotList from buckets (strict 4-HoT limit, active only)
    for prio = 1, 4 do
        local bucket = hotBuckets[prio]
        if bucket then
            for _, entry in ipairs(bucket) do
                table.insert(active.hotList, entry)
                if #active.hotList >= 4 then break end
            end
        end
        if #active.hotList >= 4 then break end
    end

    if UnitIsUnit(unit, "player") and ns.Roster and ns.Roster.fakeIcons then
        local guid = UnitGUID(unit)
        if guid and ns.Roster.fakeIcons[guid] then
            active.raidIcon = ns.Roster.fakeIcons[guid]
        end
    end

    return active
end

local function formatNumber(num)
    if type(num) == "number" then
        return string.format("%.1f", num)
    end
    return "-"
end

function Auras:DumpUnitAuras(unit)
    if not unit or unit == "" then
        ns:Print("Usage: /pb debug auras <unitId>")
        return
    end

    if not hasTrackedData() then
        rebuildTrackedNames()
    end

    ns:Print(string.format("[PB:HF] Aura debug for '%s'", unit))
    ns:Debug("Aura debug invoked for unit: " .. tostring(unit), true)

    if ns.HealingIntel and ns.HealingIntel.meta and ns.HealingIntel.meta.source then
        ns:Print("Intel source: " .. tostring(ns.HealingIntel.meta.source))
    end

    if not UnitExists(unit) then
        ns:Print(string.format("Unit '%s' does not exist or is not visible.", unit))
        return
    end

    local tracked = {}
    for name, prio in pairs(hotPriorityNames) do
        table.insert(tracked, string.format("%s -> hot%d", name, prio))
    end
    for spellId, prio in pairs(hotPriorityIds) do
        local name = GetSpellInfo(spellId) or "?"
        table.insert(tracked, string.format("%s (%d) -> hot%d", string.lower(name), spellId, prio))
    end
    for name in pairs(centerNames) do
        table.insert(tracked, string.format("%s -> center", name))
    end
    for spellId in pairs(centerIds) do
        local name = GetSpellInfo(spellId) or "?"
        table.insert(tracked, string.format("%s (%d) -> center", string.lower(name), spellId))
    end
    table.sort(tracked)
    if #tracked == 0 then
        ns:Print("Tracked aura table is empty. Check Intelligence data initialization.")
    else
        ns:Print("Tracked aura entries (name -> indicator):")
        local preview = math.min(#tracked, 20)
        for i = 1, preview do
            ns:Print("  " .. tracked[i])
        end
        if #tracked > preview then
            ns:Print(string.format("  ... (%d more entries)", #tracked - preview))
        end
    end

    local function logAura(kind, index, name, icon, count, dtype, duration, expirationTime, caster, spellId)
        local lname = name and string.lower(name) or ""
        local trackedPos = "-"
        local prio = hotPriorityNames[lname] or (spellId and hotPriorityIds[spellId])
        if prio then
            trackedPos = "hot" .. prio
        elseif centerNames[lname] or (spellId and centerIds[spellId]) then
            trackedPos = "center"
        end
        local casterName = caster and (UnitName(caster) or caster) or "?"
        ns:Print(string.format(
            "[%s %02d] %s (id=%s, stacks=%s, dtype=%s, dur=%s, expires=%s, caster=%s, tracked=%s)",
            kind,
            index,
            name or "?",
            spellId or "-",
            count or 0,
            dtype or "-",
            formatNumber(duration),
            formatNumber(expirationTime),
            casterName,
            trackedPos
        ))
    end

    for i = 1, 40 do
        local name, _, icon, count, dtype, duration, expirationTime, caster, _, _, spellId = UnitAura(unit, i, "HELPFUL")
        if not name then break end
        logAura("HELPFUL", i, name, icon, count, dtype, duration, expirationTime, caster, spellId)
    end

    for i = 1, 40 do
        local name, _, icon, count, dtype, duration, expirationTime, caster, _, _, spellId = UnitAura(unit, i, "HARMFUL")
        if not name then break end
        logAura("HARMFUL", i, name, icon, count, dtype, duration, expirationTime, caster, spellId)
    end

    local active = collectActiveAuras(unit)
    if active and (#(active.hotList or {}) > 0 or active.center) then
        ns:Print("Computed active indicators:")
        for idx, data in ipairs(active.hotList or {}) do
            ns:Print(string.format(
                "  hot%d -> icon=%s, stacks=%s, dur=%s, expires=%s",
                idx,
                data.icon or "",
                data.count or 0,
                formatNumber(data.duration),
                formatNumber(data.expires)
            ))
        end
        if active.center then
            ns:Print(string.format(
                "  center -> icon=%s, stacks=%s, dur=%s, expires=%s",
                active.center.icon or "",
                active.center.count or 0,
                formatNumber(active.center.duration),
                formatNumber(active.center.expires)
            ))
        end
    else
        ns:Print("collectActiveAuras returned an empty set for this unit.")
    end
end

function Auras:OnInitialize()
    rebuildTrackedNames()
    samplingEnabled = PB_HF_Global and PB_HF_Global.auraSamplingEnabled or false
    if ns.RegisterIntelListener then
        ns:RegisterIntelListener(function(reason)
            rebuildTrackedNames()
        end)
    end
end

function Auras:UpdateButtonAuras(btn, cached)
    if not btn or not btn.auraIndicators then return end
    
    local active = cached
    if btn.fakeData then
        -- Test Mode: Fake data injection
        active = { hotList = {} }
        local t = GetTime()
        local offset = (btn.index or 0) * 1.5
        local icons = {
            "Interface\\Icons\\Spell_Nature_Rejuvenation",
            "Interface\\Icons\\Spell_Nature_Riptide",
            "Interface\\Icons\\Spell_Holy_FlashHeal",
            "Interface\\Icons\\Spell_Nature_HealingWave",
        }
        for i = 1, 4 do
            local dur = 6 + i * 3
            local expires = t + (dur - ((t + offset) % dur))
            active.hotList[i] = { icon = icons[i], count = 0, duration = dur, expires = expires }
        end
        if btn.fakeData.group == 5 then
            active.center = { icon = "Interface\\Icons\\Spell_Shadow_ShadowWordPain", count = 0, duration = 30, expires = t + 15 }
        end
    elseif btn.unit then
        -- Live Mode: Scan real units
        active = active or self:GetUnitAuras(btn.unit)
    end

    local function applyIndicator(ind, data)
        if not ind or ind._disabled then
            if ind then
                ind:Hide()
                ind:SetScript("OnUpdate", nil)
            end
            return
        end
        if data then
            ind.icon:SetTexture(data.icon)
            ind.countText:SetText((data.count and data.count > 1) and data.count or "")
            ind.icon:Show()

            local brightness = ns.DB and ns.DB.frame and ns.DB.frame.hotIndicatorBrightness or 0.65
            local alpha = 0.3 + (brightness * 0.7)

            if ind.fill then
                if data.duration and data.duration > 0 and data.expires and data.expires > 0 then
                    local remain = data.expires - GetTime()
                    local pct = math.max(0, math.min(1, remain / data.duration))
                    local r, g, b
                    if pct < 0.25 then
                        r, g, b = 1, 0.15, 0.15
                    elseif pct < 0.5 then
                        r, g, b = 1, 0.8, 0.25
                    else
                        r, g, b = 1, 1, 0.25
                    end
                    ind.fill:SetVertexColor(r * brightness, g * brightness, b * brightness, 0.8)
                    ind.fill:Show()
                else
                    ind.fill:SetVertexColor(0.2 * brightness, 0.85 * brightness, 0.25 * brightness, 0.7)
                    ind.fill:Show()
                end
            else
                ind.icon:SetVertexColor(1, 1, 1, alpha)
            end

            if not data.isMine then
                if ind.fill then
                    ind.fill:SetVertexColor(0.5, 0.5, 0.5, alpha * 0.7)
                else
                    ind.icon:SetVertexColor(0.6, 0.6, 0.6, alpha * 0.6)
                end
            end

            if ind.glow then
                if data.isMine and not data.ghost then ind.glow:Show() else ind.glow:Hide() end
            end

            if data.duration and data.duration > 0 and data.expires and data.expires > 0 then
                if ind.cd then
                    ind.cd:SetCooldown(data.expires - data.duration, data.duration)
                    ind.cd:Show()
                end
                if ind.timerText then
                    ind:SetScript("OnUpdate", function(selfIndicator, _)
                        if not ns.DB.frame.showAuraTimers then
                            selfIndicator.timerText:SetText("")
                            selfIndicator.timerText:Hide()
                            return
                        end
                        local remain = data.expires - GetTime()
                        if remain <= 0 then
                            selfIndicator.timerText:SetText("")
                            selfIndicator.timerText:Hide()
                            selfIndicator:SetScript("OnUpdate", nil)
                        else
                            selfIndicator.timerText:Show()
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
                end
            else
                if ind.cd then ind.cd:Hide() end
                if ind.timerText then ind.timerText:SetText("") end
                ind:SetScript("OnUpdate", nil)
            end
            ind:Show()
        else
            ind:Hide()
            ind:SetScript("OnUpdate", nil)
        end
    end

    local order = btn.hotIndicatorOrder or HOT_ORDER_BARS
    local limit = btn.hotIndicatorLimit or #order
    local hotList = (active and active.hotList) or {}
    for idx, slot in ipairs(order) do
        local ind = btn.auraIndicators and btn.auraIndicators[slot]
        local box = btn.hotIndicators and btn.hotIndicators[slot]
        local data = (idx <= limit) and hotList[idx] or nil
        applyIndicator(ind, data)
        applyIndicator(box, data)
    end

    local centerData = active and active.center
    if not centerData and btn.curableDebuff then
        local d = btn.curableDebuff
        centerData = { icon = d.texture, count = d.count or 0, duration = d.duration or 0, expires = d.expires or 0 }
    end
    applyIndicator(btn.auraIndicators and btn.auraIndicators.center, centerData)
end

function Auras:OnEvent(event, unit)
    if event == "UNIT_AURA" then
        if samplingEnabled and unit then
            recordSamples(unit)
        end
        if not unit then return end
        local cache = scanAndStore(unit)
        if ns.Frames and ns.Frames.GetButtonForUnit then
            local btn = ns.Frames:GetButtonForUnit(unit)
            if btn then
                self:UpdateButtonAuras(btn, cache)
                return
            end
        end

        if ns.Frames and ns.Frames.buttons then
            for _, b in ipairs(ns.Frames.buttons) do
                if b.unit and UnitIsUnit(b.unit, unit) then
                    self:UpdateButtonAuras(b, cache)
                end
            end
        end
    end
end

function Auras:IsSamplingEnabled()
    return samplingEnabled
end

function Auras:SetSamplingEnabled(flag)
    PB_HF_Global = PB_HF_Global or {}
    PB_HF_Global.auraSamplingEnabled = flag and true or false
    samplingEnabled = PB_HF_Global.auraSamplingEnabled
    if flag then
        ns:Print("Aura sampling enabled. Heal as normal, then use /pb sample export and DM @Talzanar on Discord.")
    else
        ns:Print("Aura sampling disabled.")
    end
end

function Auras:ClearSamples()
    local bucket = getSampleBucket()
    wipe(bucket)
    ns:Print("Aura sample log cleared.")
end

function Auras:ExportSamples()
    local bucket = getSampleBucket()
    local count = 0
    ns:Print("Aura Samples — copy the list below and DM Talzanar on Discord:")
    for _, entry in pairs(bucket) do
        count = count + 1
        local casterList = {}
        if entry.casters then
            for casterName in pairs(entry.casters) do table.insert(casterList, casterName) end
        end
        table.sort(casterList)
        ns:Print(string.format(" - %s (id=%s, seen=%d)%s",
            entry.name or "?",
            entry.spellId or "?",
            entry.count or 0,
            #casterList > 0 and (" casters:" .. table.concat(casterList, ",")) or ""))
    end
    if count == 0 then
        ns:Print("No aura samples recorded yet. Use /pb sample on and continue healing.")
    end
end

function Auras:HandleSampleCommand(args)
    args = args or ""
    if args == "" or args == "help" then
        ns:Print("Usage: /pb sample [on|off|export|clear]")
        return
    end
    if args == "on" then
        self:SetSamplingEnabled(true)
    elseif args == "off" then
        self:SetSamplingEnabled(false)
    elseif args == "export" then
        self:ExportSamples()
    elseif args == "clear" then
        self:ClearSamples()
    else
        ns:Print("Usage: /pb sample [on|off|export|clear]")
    end
end
