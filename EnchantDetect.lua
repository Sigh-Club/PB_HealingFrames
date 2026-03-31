local _, ns = ...
local EnchantDetect = ns:RegisterModule("EnchantDetect", {})
ns.EnchantDetect = EnchantDetect

EnchantDetect.overrides = {}
EnchantDetect.activeEnchants = {}
EnchantDetect.prevSpellNames = {}
EnchantDetect.enchantAuras = {}

local PAREN_PATTERN = "^(.+)%s*%((.+)%)$"

local function lower(s) return s and string.lower(s) or "" end

function EnchantDetect:ClassifyEntry(entry)
    if not entry or not entry.name then return end
    local baseName, enchantTag = string.match(entry.name, PAREN_PATTERN)
    if baseName and enchantTag then
        entry.isEnchantOverride = true
        entry.baseName = baseName
        entry.enchantTag = enchantTag
        local lbase = lower(baseName)
        self.overrides[lbase] = {
            overrideId = entry.spellId,
            overrideName = entry.name,
            enchantTag = enchantTag,
        }
    end
end

function EnchantDetect:GetResolvedSpellName(rawName)
    if not rawName then return rawName end
    local lraw = lower(rawName)
    local ov = self.overrides[lraw]
    if ov and ov.overrideName then
        return ov.overrideName
    end
    return rawName
end

function EnchantDetect:GetActiveOverrides()
    return self.overrides
end

function EnchantDetect:IsEnchantActive(enchantId)
    return self.activeEnchants[enchantId] and true or false
end

function EnchantDetect:GetActiveEnchants()
    return self.activeEnchants
end

function EnchantDetect:ScanPlayerAuras()
    wipe(self.enchantAuras)
    local intel = ns.HealingIntel or {}
    local markers = intel.enchantMarkers or {}

    for i = 1, 40 do
        local name, _, _, _, _, _, _, _, _, _, spellId = UnitAura("player", i, "HELPFUL")
        if not name then break end
        self.enchantAuras[lower(name)] = true
        if spellId then
            self.enchantAuras[spellId] = true
        end
    end

    wipe(self.activeEnchants)
    for enchantId, marker in pairs(markers) do
        local found = false
        if marker.auras then
            for _, auraName in ipairs(marker.auras) do
                if self.enchantAuras[lower(auraName)] then
                    found = true
                    break
                end
            end
        end
        if marker.replaces then
            local rep = marker.replaces
            local baseName = rep.base
            if baseName then
                local lbase = lower(baseName)
                if self.overrides[lbase] then
                    found = true
                end
            end
        end
        if found then
            self.activeEnchants[enchantId] = true
        end
    end
end

function EnchantDetect:DiffSpellbook()
    if not ns.SpellBook or not ns.SpellBook.GetBindable then return end
    local bindable = ns.SpellBook:GetBindable()
    local currentNames = {}
    for _, entry in ipairs(bindable) do
        if entry.name then
            currentNames[lower(entry.name)] = true
        end
    end

    local added = {}
    local removed = {}
    for name in pairs(currentNames) do
        if not self.prevSpellNames[name] then
            added[#added + 1] = name
        end
    end
    for name in pairs(self.prevSpellNames) do
        if not currentNames[name] then
            removed[#removed + 1] = name
        end
    end

    self.prevSpellNames = currentNames
    return added, removed
end

function EnchantDetect:FullScan()
    wipe(self.overrides)
    if ns.SpellBook and ns.SpellBook.GetBindable then
        local bindable = ns.SpellBook:GetBindable()
        for _, entry in ipairs(bindable) do
            self:ClassifyEntry(entry)
        end
        local raw = ns.SpellBook.raw
        if raw then
            for _, entry in ipairs(raw) do
                self:ClassifyEntry(entry)
            end
        end
    end
    self:ScanPlayerAuras()
    self:DiffSpellbook()
    if ns.Debug then
        local oc = 0
        for _ in pairs(self.overrides) do oc = oc + 1 end
        local ec = 0
        for _ in pairs(self.activeEnchants) do ec = ec + 1 end
        ns:Debug(string.format("EnchantDetect: %d overrides, %d active enchants", oc, ec))
    end
end

function EnchantDetect:OnInitialize()
    self:FullScan()
end

function EnchantDetect:OnEnable()
    self:FullScan()
end

function EnchantDetect:OnEvent(event)
    if event == "UNIT_AURA" then
        self:ScanPlayerAuras()
    elseif event == "SPELLS_CHANGED" or event == "LEARNED_SPELL_IN_TAB" then
        self:FullScan()
        if ns.BuildState then
            ns.BuildState:Classify()
        end
    end
end
