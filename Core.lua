local addonName, ns = ...
_G.PB_HealingFrames = ns
ns.addonName = "PB: Healing Frames"
ns.modules = {}
ns.moduleOrder = {}
ns.state = {}
ns.L = ns.L or {}

function ns:RegisterModule(name, mod)
    mod = mod or {}
    mod.name = name
    if not self.modules[name] then
        table.insert(self.moduleOrder, mod)
    end
    self.modules[name] = mod
    return mod
end

function ns:IterModules(method, ...)
    for _, mod in ipairs(self.moduleOrder) do
        if mod and mod[method] then
            local ok, err = pcall(mod[method], mod, ...)
            if not ok then 
                local msg = "Module Error ["..(mod.name or "Unknown")..":"..method.."]: "..tostring(err)
                self:Print(msg)
            end
        end
    end
end

function ns:Print(msg)
    local f = DEFAULT_CHAT_FRAME or ChatFrame1
    if f then
        f:AddMessage("|cff7cc7ffPB:HF|r: "..tostring(msg))
    else
        print("PB:HF: "..tostring(msg))
    end
end

ns.secureQueue = {}
function ns:SafeSetAttribute(btn, name, value)
    if InCombatLockdown() then
        self.secureQueue[btn] = self.secureQueue[btn] or {}
        self.secureQueue[btn][name] = value
    else
        btn:SetAttribute(name, value)
    end
end

local function ProcessSecureQueue()
    if InCombatLockdown() then return end
    for btn, attrs in pairs(ns.secureQueue) do
        for name, value in pairs(attrs) do
            btn:SetAttribute(name, value)
        end
        ns.secureQueue[btn] = nil
    end
end

local function EnsureSaved()
    PB_HF_DB = PB_HF_DB or {}
    PB_HF_DB.profiles = PB_HF_DB.profiles or {}
    PB_HF_DB.profileKeys = PB_HF_DB.profileKeys or {}
    
    local name = UnitName("player")
    local realm = GetRealmName()
    local key = (name and realm) and (name.." - "..realm) or "Default"
    ns.state.charKey = key
    
    local profileName = PB_HF_DB.profileKeys[key] or "Default"
    ns.state.profileName = profileName
    
    if not PB_HF_DB.profiles[profileName] then
        if ns.Profiles and ns.Profiles.GetDefaults then
            PB_HF_DB.profiles[profileName] = ns.Profiles:GetDefaults()
        else
            PB_HF_DB.profiles[profileName] = {}
        end
    end
    ns.DB = PB_HF_DB.profiles[profileName]
    
    -- Structure Setup
    ns.DB.frame = ns.DB.frame or {}
    ns.DB.bindings = ns.DB.bindings or {}
    ns.DB.scan = ns.DB.scan or {}
    ns.DB.spellRoles = ns.DB.spellRoles or {}
    
    local f = ns.DB.frame
    f.layoutStyle = f.layoutStyle or "bars"
    f.dispelColors = f.dispelColors or {
        Magic = { 0.20, 0.60, 1.00 },
        Curse = { 0.60, 0.00, 1.00 },
        Disease = { 0.60, 0.40, 0.00 },
        Poison = { 0.00, 0.75, 0.20 },
    }
    f.hoverColor = f.hoverColor or { 1.00, 1.00, 1.00, 0.15 }
    if f.splitGroups == nil then f.splitGroups = false end
    f.groupPositions = f.groupPositions or {}
    f.anchorPositions = f.anchorPositions or {}
    if (f.x or f.y) and (not next(f.anchorPositions)) then
        f.anchorPositions.party = { x = f.x, y = f.y }
    end
    f.bars = f.bars or { width = 160, height = 20, spacing = 3, scale = 1, groupsPerRow = 4, groupSpacing = 12, nameLength = 10, shortenNames = true }
    f.grid = f.grid or { size = 40, columns = 5, spacing = 2, scale = 1, nameLength = 6, shortenNames = true }
    f.outOfRangeAlpha = f.outOfRangeAlpha or 0.35
    
    if f.highlightCurableDebuffs == nil then f.highlightCurableDebuffs = true end
    if f.showAuraTimers == nil then f.showAuraTimers = true end
    if f.showManaBar == nil then f.showManaBar = true end
    if f.showHealthText == nil then f.showHealthText = true end
    if f.showStatusText == nil then f.showStatusText = true end
    if ns.DB.enabled == nil then ns.DB.enabled = true end
    
    PB_HF_Global = PB_HF_Global or {}
    PB_HF_Global.auraSamples = PB_HF_Global.auraSamples or {}
    if PB_HF_Global.auraSamplingEnabled == nil then PB_HF_Global.auraSamplingEnabled = false end
    PB_HF_Global.roleVector = PB_HF_Global.roleVector or { healer = 0, support = 0, dps = 0 }
end

function ns:SetEnabled(v)
    ns.DB.enabled = v
    if ns.Frames then ns.Frames:ApplyLayout() end
    if v then
        if ns.Roster then ns.Roster:Refresh() end
    end
end

local isBootstrapped = false
local function Bootstrap()
    if isBootstrapped then return end
    if not UnitName("player") or UnitName("player") == "Unknown Entity" then return end
    isBootstrapped = true
    
    EnsureSaved()
    ns:IterModules("OnInitialize")
    ns:IterModules("OnEnable")
    local status = ns.DB.enabled and "" or " (|cffff4444Disabled|r)"
    ns:Print("V 1.3.5 beta loaded. Type /pb for config." .. status)
end

local frame = CreateFrame("Frame")
ns.frame = frame
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")

frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        Bootstrap()
    elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        Bootstrap()
    elseif event == "PLAYER_REGEN_ENABLED" then
        ProcessSecureQueue()
    end
    
    if isBootstrapped then
        ns:IterModules("OnEvent", event, arg1)
    end
end)

-- Register secondary events
local events = { 
    "PARTY_MEMBERS_CHANGED", "RAID_ROSTER_UPDATE", 
    "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_AURA", "UNIT_POWER", "UNIT_DISPLAYPOWER",
    "LEARNED_SPELL_IN_TAB", "PLAYER_TALENT_UPDATE", "SKILL_LINES_CHANGED", "CHARACTER_POINTS_CHANGED", "SPELLS_CHANGED",
    "PLAYER_REGEN_ENABLED", "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED", "RAID_TARGET_UPDATE",
    "COMBAT_LOG_EVENT_UNFILTERED", "PLAYER_REGEN_DISABLED"
 }
for _, ev in ipairs(events) do frame:RegisterEvent(ev) end

if IsLoggedIn() then Bootstrap() end
