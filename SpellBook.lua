local _, ns = ...
local SpellBook = ns:RegisterModule("SpellBook", {})
ns.SpellBook = SpellBook

SpellBook.raw = {}
SpellBook.bindable = {}
SpellBook.byName = {}
SpellBook.stats = { raw = 0, bindable = 0, healing = 0 }
SpellBook.dispelCapabilities = {}
SpellBook.rangeSpellName = nil

local function lower(s) return s and string.lower(s) or "" end

local function normalizeRole(role)
    if role == "direct_heal" then return "heal" end
    if role == "healing_over_time" then return "hot" end
    return role
end

function SpellBook:GetRangeSpellName() return self.rangeSpellName end
function SpellBook:PlayerCanDispel(dtype) return self.dispelCapabilities[dtype] and true or false end
function SpellBook:GetBindable() return self.bindable end
function SpellBook:FindByName(name) return name and self.byName[string.lower(name)] end

-- Robust Tooltip Scanner for 3.3.5a / Ascension
local function guessRole(slot, link)
    local tooltip = GameTooltip
    tooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
    tooltip:ClearLines()
    
    if link then
        tooltip:SetHyperlink(link)
    else
        tooltip:SetSpellBookItem(slot, "spell")
    end
    
    local name = GetSpellBookItemName(slot, "spell")
    if not name then return nil end
    
    local lname = lower(name)
    local intel = ns.HealingIntel or {}
    if intel.knownSpellRolesByName and intel.knownSpellRolesByName[lname] then
        return intel.knownSpellRolesByName[lname]
    end
    
    local text = ""
    for i = 1, tooltip:NumLines() do
        local line = _G["GameTooltipTextLeft"..i]
        local ltext = line and line:GetText()
        if ltext then text = text .. " " .. lower(ltext) end
    end

    if text:find("heals") or text:find("restores.*health") or text:find("points of health") or text:find("healing") then
        if text:find("over %d+ sec") or text:find("periodic") or text:find("each second") then return "hot" end
        return "heal"
    end
    if text:find("absorb") or text:find("shield") then return "shield_absorb" end
    if text:find("cleanse") or text:find("purify") or text:find("dispel") or text:find("cure") or text:find("abolish") then return "cleanse" end
    if text:find("resurrect") or text:find("revive") or text:find("rebirth") then return "resurrection" end
    if text:find("friendly target") or text:find("party member") or text:find("blessing") or text:find("blesses") then 
        if text:find("minutes") or text:find("hour") then return "buff" end
        return "support" 
    end
    return nil
end

local lastScan = 0
local lastSpellCount = 0

function SpellBook:Scan(force)
    if InCombatLockdown() then return end
    local now = GetTime()
    if not force and now - lastScan < 5 then return end
    
    local tabCount = ns.Compat:GetNumSpellTabs()
    if not tabCount or tabCount == 0 then
        if force then C_Timer.After(2, function() self:Scan(true) end) end
        return 
    end

    wipe(self.raw); wipe(self.bindable); wipe(self.byName)
    local seen = {}
    local opts = ns.DB.scan or { excludeGeneral = true, excludePassive = true, dedupeByName = true }

    for tab = 1, tabCount do
        local tabName, _, offset, numSpells = ns.Compat:GetSpellTabInfo(tab)
        local isGeneral = (tab == 1) or (tabName and lower(tabName) == "general")
        local isTrade = ns.Compat:IsTradeskill(tabName)

        for slot = offset + 1, offset + numSpells do
            local name, rank = ns.Compat:GetSpellName(slot)
            if name then
                local link = ns.Compat:GetSpellLink(slot)
                local isPassive = ns.Compat:IsPassive(slot)
                local guessedRole = guessRole(slot, link)
                guessedRole = normalizeRole(guessedRole)

                local entry = {
                    name = name, rank = rank or "", slot = slot, role = guessedRole, link = link,
                    texture = ns.Compat:GetSpellTexture(slot),
                    isPassive = isPassive, isTrade = isTrade, isGeneral = isGeneral,
                }
                table.insert(self.raw, entry)
                
                if not (opts.excludeGeneral and entry.isGeneral) and not (entry.isPassive) and not (opts.excludeProfessions and entry.isTrade) then
                    local k = lower(name)
                    if not seen[k] then
                        seen[k] = true
                        table.insert(self.bindable, entry)
                        self.byName[k] = entry
                    end
                end
            end
        end
    end

    -- Dispel Caps
    wipe(self.dispelCapabilities)
    local intel = ns.HealingIntel or {}
    for dtype, ids in pairs(intel.dispelAbilities or {}) do
        for _, id in ipairs(ids) do
            local sname = GetSpellInfo(id)
            if sname and self.byName[lower(sname)] then self.dispelCapabilities[dtype] = true break end
        end
    end

    -- Range Spell
    self.rangeSpellName = nil
    local roleOrder = {"heal", "hot", "shield_absorb", "cleanse", "support"}
    for _, role in ipairs(roleOrder) do
        for _, e in ipairs(self.bindable) do
            if e.role == role and ns.Compat:IsHelpfulRangeSpell(e.name) then self.rangeSpellName = e.name break end
        end
        if self.rangeSpellName then break end
    end

    table.sort(self.bindable, function(a, b) return a.name < b.name end)
    self.stats.bindable = #self.bindable
    self.stats.healing = 0
    for _, e in ipairs(self.bindable) do if e.role == "heal" or e.role == "hot" or e.role == "shield_absorb" then self.stats.healing = self.stats.healing + 1 end end
    
    if force then ns:Print(string.format("Scan complete: %d spells (%d healing)", self.stats.bindable, self.stats.healing)) end
end

function SpellBook:OnInitialize() end
function SpellBook:OnEnable() C_Timer.After(3, function() self:Scan(true) end) end
function SpellBook:OnEvent(event) end
