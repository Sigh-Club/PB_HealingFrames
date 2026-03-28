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

-- Shared scan tooltip
local scanTooltip
local function getScanTooltip()
    if not scanTooltip then
        scanTooltip = CreateFrame("GameTooltip", "PB_ScanTooltip", nil, "GameTooltipTemplate")
        scanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
    end
    return scanTooltip
end

local function guessRole(slot, bookType)
    local tooltip = getScanTooltip()
    tooltip:ClearLines()
    -- FIXED: Use SetSpellBookItem for 3.3.5a compatibility
    tooltip:SetSpellBookItem(slot, bookType)
    
    local name = GetSpellBookItemName(slot, bookType)
    if not name then return nil, "none" end
    local lname = lower(name)
    
    local intel = ns.HealingIntel or {}
    local exact = intel.knownSpellRolesByName and intel.knownSpellRolesByName[lname]
    if exact then return exact, "name" end
    
    local text = ""
    for i = 1, tooltip:NumLines() do
        local line = _G["PB_ScanTooltipTextLeft"..i]
        if line then 
            local ltext = line:GetText()
            if ltext then text = text .. " " .. lower(ltext) end
        end
    end

    if text:find("heals") or text:find("restores.*health") or text:find("points of health") or text:find("healing") then
        if text:find("over %d+ sec") or text:find("periodic") or text:find("each second") or text:find("every %d+ sec") then 
            return "hot", "heuristic" 
        end
        return "heal", "heuristic"
    end
    if text:find("absorb") or text:find("shield") or text:find("damage protection") then return "shield_absorb", "heuristic" end
    if text:find("cleanse") or text:find("remove.*curse") or text:find("dispel") or text:find("cure") or text:find("abolish") or text:find("purify") then return "cleanse", "heuristic" end
    if text:find("resurrect") or text:find("bring.*to life") or text:find("revive") or text:find("rebirth") then return "resurrection", "heuristic" end
    if text:find("friendly target") or text:find("party member") or text:find("raid member") or text:find("armor increased") or text:find("resistance increased") or text:find("increase.*stats") or text:find("blesses") or text:find("blessing") then 
        if text:find("minutes") or text:find("hour") then return "buff", "heuristic" end
        return "support", "heuristic" 
    end

    return nil, "none"
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

    local currentCount = 0
    for tab = 1, tabCount do
        local _, _, _, numSpells = ns.Compat:GetSpellTabInfo(tab)
        currentCount = currentCount + (numSpells or 0)
    end

    if not force and currentCount == lastSpellCount and lastSpellCount > 0 then return end
    
    lastScan = now
    lastSpellCount = currentCount
    
    wipe(self.raw)
    wipe(self.bindable)
    wipe(self.byName)
    
    local opts = ns.DB.scan or { excludeGeneral = true, excludePassive = true, excludeProfessions = true, dedupeByName = true }
    local seen = {}
    local BOOKTYPE = "spell"

    for tab = 1, tabCount do
        local tabName, _, offset, numSpells = ns.Compat:GetSpellTabInfo(tab)
        local isGeneral = (tab == 1) or (tabName and lower(tabName) == "general")
        local isTrade = ns.Compat:IsTradeskill(tabName)

        for slot = offset + 1, offset + numSpells do
            local name, rank = ns.Compat:GetSpellName(slot)
            if name then
                local isPassive = ns.Compat:IsPassive(slot)
                local guessedRole, _ = guessRole(slot, BOOKTYPE)
                guessedRole = normalizeRole(guessedRole)

                local entry = {
                    name = name,
                    rank = rank or "",
                    slot = slot,
                    texture = ns.Compat:GetSpellTexture(slot),
                    isPassive = isPassive,
                    isTrade = isTrade,
                    isGeneral = isGeneral,
                    role = guessedRole,
                }
                
                table.insert(self.raw, entry)

                local ok = true
                if opts.excludeGeneral and entry.isGeneral then ok = false end
                if ok and (opts.excludePassive ~= false) and entry.isPassive then ok = false end
                if ok and opts.excludeProfessions and entry.isTrade then ok = false end
                if ok and opts.dedupeByName then
                    local k = lower(name)
                    if seen[k] then ok = false else seen[k] = true end
                end

                if ok then
                    table.insert(self.bindable, entry)
                    self.byName[string.lower(name)] = entry
                end
            end
        end
    end

    wipe(self.dispelCapabilities)
    local intel = ns.HealingIntel or {}
    for dtype, ids in pairs(intel.dispelAbilities or {}) do
        for _, id in ipairs(ids) do
            local sname = GetSpellInfo(id)
            if sname and self.byName[string.lower(sname)] then
                self.dispelCapabilities[dtype] = true
                break
            end
        end
    end

    self.rangeSpellName = nil
    local roleOrder = {"heal", "hot", "shield_absorb", "cleanse", "support"}
    for _, role in ipairs(roleOrder) do
        for _, e in ipairs(self.bindable) do
            if e.role == role and ns.Compat:IsHelpfulRangeSpell(e.name) then
                self.rangeSpellName = e.name
                break
            end
        end
        if self.rangeSpellName then break end
    end

    table.sort(self.bindable, function(a, b) return a.name < b.name end)
    self.stats.bindable = #self.bindable
    self.stats.healing = 0
    for _, e in ipairs(self.bindable) do
        if e.role == "heal" or e.role == "hot" or e.role == "shield_absorb" then
            self.stats.healing = self.stats.healing + 1
        end
    end
    
    if force then
        ns:Print(string.format("Scan complete: %d bindable spells found (%d healing)", self.stats.bindable, self.stats.healing))
    end
end

function SpellBook:OnInitialize()
end

function SpellBook:OnEnable()
    -- Wait 5 seconds after login to ensure spellbook is fully ready
    C_Timer.After(5, function() self:Scan(true) end)
end

function SpellBook:OnEvent(event)
end
