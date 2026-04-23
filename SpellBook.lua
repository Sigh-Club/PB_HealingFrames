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
    
    local ok = false
    if link then
        ok = pcall(function() tooltip:SetHyperlink(link) end)
    end
    if not ok then
        pcall(function() tooltip:SetSpellBookItem(slot, "spell") end)
    end
    
    local name = GetSpellBookItemName(slot, "spell")
    if not name then return nil end
    
    local lname = lower(name)
    local intel = ns.HealingIntel or {}
    if intel.knownSpellRolesByName and intel.knownSpellRolesByName[lname] then
        return intel.knownSpellRolesByName[lname]
    end
    
    local text = ""
    local numLines = tooltip:NumLines()
    if numLines and numLines > 0 then
        for i = 1, numLines do
            local line = _G["GameTooltipTextLeft"..i]
            local ltext = line and line:GetText()
            if ltext then text = text .. " " .. lower(ltext) end
        end
    end

    -- Role Identification based on Description
    if text:find("heals") or text:find("restores.*health") or text:find("points of health") or text:find("healing") then
        if text:find("over %d+ sec") or text:find("periodic") or text:find("each second") or text:find("every %d+ sec") then 
            return "hot"
        end
        return "heal"
    end
    if text:find("absorb") or text:find("shield") or text:find("damage protection") then return "shield_absorb" end
    if text:find("cleanse") or text:find("purify") or text:find("dispel") or text:find("cure") or text:find("abolish") or text:find("purify") then return "cleanse" end
    if text:find("resurrect") or text:find("bring.*to life") or text:find("revive") or text:find("rebirth") then return "resurrection" end
    if text:find("friendly target") or text:find("party member") or text:find("raid member") or text:find("armor increased") or text:find("resistance increased") or text:find("increase.*stats") or text:find("blesses") or text:find("blessing") then 
        if text:find("minutes") or text:find("hour") then return "buff" end
        return "support" 
    end
    return nil
end

local lastScan = 0
local lastSpellCount = 0

function SpellBook:Scan(force, silent)
    if InCombatLockdown() then return end
    local now = GetTime()
    if not force and now - lastScan < 5 then return end
    
    local tabCount = ns.Compat:GetNumSpellTabs()
    if not tabCount or tabCount == 0 then
        if force then C_Timer.After(2, function() self:Scan(true, silent) end) end
        return 
    end

    local currentCount = 0
    for tab = 1, tabCount do
        local _, _, _, numSpells = ns.Compat:GetSpellTabInfo(tab)
        currentCount = currentCount + (numSpells or 0)
    end

    if not force and currentCount == lastSpellCount and lastSpellCount > 0 then return end
    
    lastScan = now
    lastSpellCount = currentCount
    
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
                    spellId = link and ns.Compat:GetSpellIdFromLink(link) or nil,
                    texture = ns.Compat:GetSpellTexture(slot),
                    isPassive = isPassive, isTrade = isTrade, isGeneral = isGeneral,
                }
                if ns.EnchantDetect then
                    ns.EnchantDetect:ClassifyEntry(entry)
                end
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

    wipe(self.dispelCapabilities)
    local intel = ns.HealingIntel or {}
    for dtype, ids in pairs(intel.dispelAbilities or {}) do
        for _, id in ipairs(ids) do
            local sname = GetSpellInfo(id)
            if sname and self.byName[lower(sname)] then self.dispelCapabilities[dtype] = true break end
        end
    end

    self.rangeSpellName = nil
    for _, role in ipairs({"heal", "hot", "shield_absorb", "cleanse", "support"}) do
        for _, e in ipairs(self.bindable) do
            if e.role == role and ns.Compat:IsHelpfulRangeSpell(e.name) then self.rangeSpellName = e.name break end
        end
        if self.rangeSpellName then break end
    end

    table.sort(self.bindable, function(a, b) return a.name < b.name end)
    self.stats.bindable = #self.bindable
    self.stats.healing = 0
    for _, e in ipairs(self.bindable) do if e.role == "heal" or e.role == "hot" or e.role == "shield_absorb" then self.stats.healing = self.stats.healing + 1 end end
    
    if ns.EnchantDetect then ns.EnchantDetect:FullScan(silent) end
    if ns.BuildState then ns.BuildState:Classify(silent) end
end

function SpellBook:OnInitialize() end
function SpellBook:OnEnable()
    C_Timer.After(5, function() self:Scan(true, true) end)
    C_Timer.After(15, function() self:Scan(true, true) end)
end
function SpellBook:OnEvent(event)
    if event == "LEARNED_SPELL_IN_TAB" or event == "SPELLS_CHANGED" or event == "PLAYER_TALENT_UPDATE" or event == "CHARACTER_POINTS_CHANGED" then
        self:Scan(false, true)
    end
end
