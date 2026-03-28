local _, ns = ...
local Profiles = ns:RegisterModule("Profiles", {})
ns.Profiles = Profiles

local function defaults()
    return {
        enabled = true,
        locked = false,
        frame = {
            layoutStyle = "bars",
            x = nil,
            y = nil,
            outOfRangeAlpha = 0.35,
            highlightCurableDebuffs = true,
            healthyColor = {0.15, 0.78, 0.22},
            injuredColor = {0.95, 0.82, 0.20},
            criticalColor = {0.95, 0.15, 0.15},
            criticalThreshold = 35,
            injuredThreshold = 70,
            showManaBar = true,
            manaBarHeight = 3,
            showStatusText = true,
            showHealComm = true,
            classColorNames = true,
            showHealthText = true,
            dispelColors = {
                Magic = { 0.20, 0.60, 1.00 },
                Curse = { 0.60, 0.00, 1.00 },
                Disease = { 0.60, 0.40, 0.00 },
                Poison = { 0.00, 0.75, 0.20 },
            },
            hoverColor = { 1.00, 1.00, 1.00, 0.15 },
            barTexture = "Interface\\TargetingFrame\\UI-StatusBar",
            invertedColors = false,
            showAggroBorder = true,
            showTargetGlow = true,
            showDeficit = true,
            nameFontSize = 10,
            statusFontSize = 8,
            splitGroups = false,
            groupPositions = {},
            bars = { width = 160, height = 20, spacing = 3, scale = 1, groupsPerRow = 4, groupSpacing = 12, nameLength = 10, shortenNames = true },
            grid = { size = 40, columns = 5, spacing = 2, scale = 1, nameLength = 6, shortenNames = true },
        },
        scan = {
            excludeGeneral = true,
            excludePassive = true,
            excludeProfessions = true,
            excludeRacials = true,
            excludeUtility = true,
            dedupeByName = true,
        },
        bindings = {},
        spellRoles = {},
    }
end

local function deepCopy(src)
    if type(src) ~= "table" then return src end
    local out = {}
    for k, v in pairs(src) do out[k] = deepCopy(v) end
    return out
end

local function copyMissing(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            copyMissing(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

function Profiles:DeepCopy(src)
    return deepCopy(src)
end

function Profiles:GetDefaults()
    return defaults()
end

function Profiles:GetCharKey()
    return ns.state.charKey
end

function Profiles:GetProfileName()
    return ns.state.profileName or "Default"
end

function Profiles:GetProfiles()
    local list = {}
    for name in pairs(PB_HF_DB.profiles) do
        table.insert(list, name)
    end
    table.sort(list)
    return list
end

function Profiles:SetProfile(name)
    if not PB_HF_DB.profiles[name] then return end
    PB_HF_DB.profileKeys[self:GetCharKey()] = name
    ns.state.profileName = name
    ns.DB = PB_HF_DB.profiles[name]
    copyMissing(ns.DB, defaults())
    
    -- Refresh everything
    if ns.Frames then ns.Frames:ApplyLayout() end
    if ns.ClickCast then ns.ClickCast:RefreshAll() end
    if ns.Roster then ns.Roster:Refresh() end
end

function Profiles:CreateProfile(name, copyFrom)
    if not name or name == "" or PB_HF_DB.profiles[name] then return end
    if copyFrom and PB_HF_DB.profiles[copyFrom] then
        PB_HF_DB.profiles[name] = deepCopy(PB_HF_DB.profiles[copyFrom])
    else
        PB_HF_DB.profiles[name] = deepCopy(defaults())
    end
    self:SetProfile(name)
end

function Profiles:DeleteProfile(name)
    if name == "Default" or name == self:GetProfileName() then return end
    PB_HF_DB.profiles[name] = nil
    -- Clean up profile keys
    for key, pName in pairs(PB_HF_DB.profileKeys) do
        if pName == name then
            PB_HF_DB.profileKeys[key] = "Default"
        end
    end
end

function Profiles:ResetCurrentProfile()
    local name = self:GetProfileName()
    PB_HF_DB.profiles[name] = deepCopy(defaults())
    ns.DB = PB_HF_DB.profiles[name]
    
    if ns.Frames then ns.Frames:ApplyLayout() end
    if ns.ClickCast then ns.ClickCast:RefreshAll() end
    if ns.Roster then ns.Roster:Refresh() end
end

function Profiles:OnInitialize()
    copyMissing(ns.DB, defaults())
end
