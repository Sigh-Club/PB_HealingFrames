local _, ns = ...
local BuildState = ns:RegisterModule("BuildState", {})
ns.BuildState = BuildState

BuildState.engineMode = "unknown"
BuildState.kitSignature = {}
BuildState.maintenanceAuraList = {}
BuildState.thresholdRules = {}

local function lower(s) return s and string.lower(s) or "" end

local function countByRole(bindable)
    local counts = {
        direct_heal = 0,
        hot = 0,
        shield_absorb = 0,
        damage_to_heal = 0,
        cleanse = 0,
        support = 0,
        buff = 0,
        damage = 0,
        total = 0,
    }
    for _, entry in ipairs(bindable or {}) do
        local role = entry.role
        if role then
            counts.total = counts.total + 1
            if role == "heal" then
                counts.direct_heal = counts.direct_heal + 1
            elseif role == "hot" then
                counts.hot = counts.hot + 1
            elseif role == "shield_absorb" then
                counts.shield_absorb = counts.shield_absorb + 1
            elseif role == "damage_to_heal" then
                counts.damage_to_heal = counts.damage_to_heal + 1
            elseif role == "cleanse" then
                counts.cleanse = counts.cleanse + 1
            elseif role == "support" then
                counts.support = counts.support + 1
            elseif role == "buff" then
                counts.buff = counts.buff + 1
            end
        end
    end

    local intel = ns.HealingIntel or {}
    local d2hNames = intel.roleSpellNames and intel.roleSpellNames.damage_to_heal or {}
    for _, entry in ipairs(bindable or {}) do
        if entry.name and not entry.role then
            for _, d2hName in ipairs(d2hNames) do
                if lower(entry.name) == lower(d2hName) then
                    counts.damage_to_heal = counts.damage_to_heal + 1
                    break
                end
            end
        end
    end

    return counts
end

local function detectEngineMode(counts)
    local ed = ns.EnchantDetect
    local hasProc = ns.CombatLog and ns.CombatLog.HasDamageToHealProc
    local hasD2HProc = hasProc and ns.CombatLog:HasDamageToHealProc()

    if counts.damage_to_heal >= 2 and (hasD2HProc or (ed and (ed:IsEnchantActive("atonement") or ed:IsEnchantActive("dominantWordShield")))) then
        return "damage_to_heal"
    end

    if counts.hot >= 3 and counts.hot > counts.direct_heal then
        if ed and ed:IsEnchantActive("lowTide") then
            return "hot_maintenance"
        end
        if counts.hot > counts.shield_absorb then
            return "hot_maintenance"
        end
    end

    if counts.shield_absorb >= 2 then
        if ed and ed:IsEnchantActive("dominantWordShield") then
            return "absorb_shield"
        end
        if counts.shield_absorb >= counts.direct_heal then
            return "absorb_shield"
        end
    end

    if counts.direct_heal >= 3 then
        return "direct_heal"
    end

    if counts.direct_heal + counts.hot + counts.shield_absorb + counts.damage_to_heal >= 2 then
        return "hybrid"
    end

    return "unknown"
end

local function computeKitSignature(counts)
    local total = math.max(counts.total, 1)
    return {
        heal = (counts.direct_heal * 1.0 + counts.hot * 0.8 + counts.damage_to_heal * 1.2) / total,
        hot = counts.hot / total,
        shield = counts.shield_absorb / total,
        d2h = counts.damage_to_heal / total,
        support = (counts.cleanse * 0.8 + counts.support * 0.6 + counts.buff * 0.4) / total,
        damage = math.max(0, (total - counts.direct_heal - counts.hot - counts.shield_absorb - counts.damage_to_heal - counts.cleanse - counts.support - counts.buff)) / total,
    }
end

local function deriveMaintenanceAuras(mode)
    local intel = ns.HealingIntel or {}
    local byEngine = intel.maintenanceAurasByEngine or {}
    local base = byEngine[mode] or {}

    local auras = {}
    for _, name in ipairs(base) do
        auras[lower(name)] = name
    end

    if ns.SpellBook and ns.SpellBook.GetBindable then
        local bindable = ns.SpellBook:GetBindable()
        for _, entry in ipairs(bindable) do
            if entry.role == "hot" and entry.name then
                local ln = lower(entry.name)
                if not auras[ln] then
                    auras[ln] = entry.name
                end
            end
        end
    end

    return auras
end

local function deriveThresholdRules()
    local rules = {}
    local ed = ns.EnchantDetect
    if not ed then return rules end

    local intel = ns.HealingIntel or {}
    local markers = intel.enchantMarkers or {}

    for enchantId, marker in pairs(markers) do
        if marker.threshold and ed:IsEnchantActive(enchantId) then
            rules[#rules + 1] = {
                enchantId = enchantId,
                spell = marker.threshold.spell,
                hpPct = marker.threshold.hpPct,
            }
        end
    end

    return rules
end

function BuildState:Classify(silent)
    if not ns.SpellBook then return end
    local bindable = ns.SpellBook:GetBindable()
    local counts = countByRole(bindable)
    local newMode = detectEngineMode(counts)

    self.kitSignature = computeKitSignature(counts)

    local changed = newMode ~= self.engineMode
    self.engineMode = newMode

    self.maintenanceAuraList = deriveMaintenanceAuras(newMode)
    self.thresholdRules = deriveThresholdRules()

    if changed and newMode ~= "unknown" then
        if ns.Bindings and ns.Bindings.SmartBind then
            ns.Bindings:SmartBind(silent)
        end
    end

    if ns.Auras and ns.Auras.RebuildTrackedNames then
        ns.Auras:RebuildTrackedNames()
    end

    if ns.RoleInference and ns.RoleInference.Update then
        ns.RoleInference:Update()
    end

    if ns.Debug and not silent then
        ns:Debug(string.format("BuildState: mode=%s heal=%.2f hot=%.2f shield=%.2f d2h=%.2f",
            newMode,
            self.kitSignature.heal or 0,
            self.kitSignature.hot or 0,
            self.kitSignature.shield or 0,
            self.kitSignature.d2h or 0))
    end
end

function BuildState:GetEngineMode()
    return self.engineMode
end

function BuildState:GetMaintenanceAuras()
    return self.maintenanceAuraList
end

function BuildState:GetSmartBindOverrides()
    local intel = ns.HealingIntel or {}
    local overrides = intel.engineSmartBindOverrides or {}
    return overrides[self.engineMode]
end

function BuildState:GetKitSignature()
    return self.kitSignature
end

function BuildState:GetThresholdRules()
    return self.thresholdRules
end

function BuildState:OnInitialize()
    self:Classify(true)
end

function BuildState:OnEnable()
    self:Classify(true)
end

function BuildState:OnEvent(event)
    if event == "PLAYER_TALENT_UPDATE" or event == "CHARACTER_POINTS_CHANGED" then
        self:Classify(true)
    end
end
