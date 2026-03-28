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

local function guessRole(name, spellId)
    local intel = ns.HealingIntel or {}
    local lname = lower(name)
    
    -- 1. Check Intel Lists First
    if spellId and intel.knownSpellRolesById and intel.knownSpellRolesById[spellId] then
        return intel.knownSpellRolesById[spellId], "id"
    end
    local exact = intel.knownSpellRolesByName and intel.knownSpellRolesByName[lname]
    if exact then return exact, "name" end
    
    -- 2. Heuristic Tooltip Check (The "Smart" way for Ascension)
    local tooltip = ns.state.scanTooltip or CreateFrame("GameTooltip", "PB_ScanTooltip", nil, "GameTooltipTemplate")
    ns.state.scanTooltip = tooltip
    tooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
    tooltip:ClearLines()
    if spellId then
        tooltip:SetSpellByID(spellId)
    else
        tooltip:SetSpellName(name)
    end
    
    local text = ""
    for i = 1, tooltip:NumLines() do
        local line = _G["PB_ScanTooltipTextLeft"..i]
        if line then text = text .. " " .. lower(line:GetText()) end
    end

    -- Role Identification based on Description
    if text:find("heals") or text:find("restores.*health") then
        if text:find("over %d+ sec") or text:find("periodic") then return "hot", "heuristic" end
        return "heal", "heuristic"
    end
    if text:find("absorb") or text:find("shield") then return "shield_absorb", "heuristic" end
    if text:find("cleanse") or text:find("remove.*curse") or text:find("dispel") or text:find("cure") or text:find("abolish") then return "cleanse", "heuristic" end
    if text:find("resurrect") or text:find("bring.*to life") then return "resurrection", "heuristic" end
    if text:find("friendly target") or text:find("party member") or text:find("raid member") or text:find("armor increased") or text:find("resistance increased") then 
        if text:find("minutes") or text:find("hour") then return "buff", "heuristic" end
        return "support", "heuristic" 
    end

    return nil, "none"
end

local function addRaw(entry)
    SpellBook.raw[#SpellBook.raw + 1] = entry
end

local function addBindable(entry)
    SpellBook.bindable[#SpellBook.bindable + 1] = entry
    SpellBook.byName[string.lower(entry.name)] = entry
end

local function computeDispelCaps()
    wipe(SpellBook.dispelCapabilities)
    local intel = ns.HealingIntel or {}
    local byName = SpellBook.byName
    local byId = {}
    for _, e in ipairs(SpellBook.raw) do
        if e.spellId then byId[e.spellId] = true end
        byName[string.lower(e.name)] = byName[string.lower(e.name)] or e
    end
    for dtype, ids in pairs(intel.dispelAbilities or {}) do
        for _, id in ipairs(ids) do
            local spellName = GetSpellInfo and GetSpellInfo(id)
            if byId[id] or (spellName and byName[string.lower(spellName)]) then
                SpellBook.dispelCapabilities[dtype] = true
                break
            end
        end
    end
end

local function chooseRangeSpell()
    SpellBook.rangeSpellName = nil
    local roleOrder = {"heal", "hot", "shield_absorb", "cleanse", "support"}
    for _, role in ipairs(roleOrder) do
        for _, e in ipairs(SpellBook.bindable) do
            if e.role == role and ns.Compat:IsHelpfulRangeSpell(e.name) then
                SpellBook.rangeSpellName = e.name
                return
            end
        end
    end
end

local lastScan = 0
function SpellBook:Scan()
    local now = GetTime()
    if now - lastScan < 2 then return end
    lastScan = now
    
    wipe(self.raw)
    wipe(self.bindable)
    wipe(self.byName)
    self.stats.raw = 0
    self.stats.bindable = 0
    self.stats.healing = 0
    
    local opts = ns.DB.scan
    if not opts then return end
    
    local tabCount = ns.Compat:GetNumSpellTabs()
    local seen = {}

    for tab = 1, tabCount do
        local tabName, _, offset, numSpells = ns.Compat:GetSpellTabInfo(tab)
        local isGeneral = (tab == 1) or (tabName and lower(tabName) == "general")
        local isTrade = ns.Compat:IsTradeskill(tabName)

        for slot = offset + 1, offset + numSpells do
            local name, rank = ns.Compat:GetSpellName(slot)
            if name then
                local link = ns.Compat:GetSpellLink(slot)
                local spellId = ns.Compat:GetSpellIdFromLink(link)
                local isPassive = ns.Compat:IsPassive(slot)
                
                -- Role detection
                local guessedRole, roleSource = guessRole(name, spellId)
                guessedRole = normalizeRole(guessedRole)

                local entry = {
                    name = name,
                    rank = rank or "",
                    slot = slot,
                    link = link,
                    spellId = spellId,
                    texture = ns.Compat:GetSpellTexture(slot),
                    isPassive = isPassive,
                    isTrade = isTrade,
                    isGeneral = isGeneral,
                    role = guessedRole,
                    roleSource = roleSource,
                }
                addRaw(entry)

                local ok = true
                if opts.excludeGeneral and entry.isGeneral then ok = false end
                if ok and opts.excludePassive and entry.isPassive then ok = false end
                if ok and opts.excludeProfessions and entry.isTrade then ok = false end
                if ok and opts.dedupeByName then
                    local k = lower(name)
                    if seen[k] then ok = false else seen[k] = true end
                end

                if ok then
                    addBindable(entry)
                    if entry.role == "heal" or entry.role == "hot" or entry.role == "shield_absorb" then
                        self.stats.healing = self.stats.healing + 1
                    end
                end
            end
        end
    end

    self.stats.raw = #self.raw
    self.stats.bindable = #self.bindable

    computeDispelCaps()
    chooseRangeSpell()
    table.sort(self.bindable, function(a, b) return a.name < b.name end)
    
    ns:Print(string.format("Scan complete: %d bindable spells found (%d healing)", self.stats.bindable, self.stats.healing))
end

function SpellBook:GetBindable()
    return self.bindable
end

function SpellBook:FindByName(name)
    if not name or name == "" then return nil end
    return self.byName[string.lower(name)]
end

function SpellBook:OnEnable()
    self:Scan()
end

function SpellBook:OnEvent(event)
    if event == "LEARNED_SPELL_IN_TAB" or event == "CHARACTER_POINTS_CHANGED" or 
       event == "PLAYER_TALENT_UPDATE" or event == "SKILL_LINES_CHANGED" or
       event == "SPELLS_CHANGED" then
        self:Scan()
    end
end
