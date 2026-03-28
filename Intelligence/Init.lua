local addonName, ns = ...
ns = ns or _G.PB_HealingFrames or {}
_G.PB_HealingFrames = ns

ns.HealingIntel = ns.HealingIntel or {
    meta = {
        name = "PB: Healing Frames Intel",
        version = "1.0.0",
        realm = "Area 52 Free-Pick",
    }
}

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

local fallbackIntel = {
    design_principles = {
        "Do not assume class implies healer.",
        "Do not assume helpful-flagged spells are the only healing actions.",
        "Use player-tagged roles as source of truth; use heuristics only as suggestions.",
        "Support direct-heal, HoT, shield, damage-to-heal, cleanse, resurrection, proc-heal and cooldown patterns.",
    },
    roleSpellIds = {
        direct_heal = { 2050, 2054, 2060, 2061, 635, 19750, 331, 8004, 8005, 5185, 8936, 50464, 1064, 596, 34861, 48785 },
        hot = { 139, 774, 33763, 48438, 61295, 33076, 115151, 124682, 124081, 115098, 123586, 73920, 52042 },
        shield_absorb = { 17, 47515, 53563, 53601, 974 },
        cleanse = { 4987, 527, 528, 552, 475, 2782, 2893, 8946, 51886 },
        resurrection = { 2006, 7328, 50769, 20484, 20773 },
        support = { 33206, 47788, 29166, 10060, 16190, 6940, 1022, 1044, 53563 },
        damage_to_heal = { 20473, 635, 585, 20271 },
    },
    healingRoles = {
        heal = true, direct_heal = true, hot = true, shield_absorb = true, damage_to_heal = true,
    },
    supportRoles = {
        support = true, cleanse = true, resurrection = true, buff = true, form = true,
    },
    racialSpellNames = {
        "Shadowmeld", "Blood Fury", "Will of the Forsaken", "Cannibalize", "Hardiness", "Berserking",
        "Stoneform", "Escape Artist", "Perception", "The Human Spirit", "Diplomacy", "Mace Specialization",
        "Sword Specialization", "Find Treasure", "Gun Specialization", "Frost Resistance", "Nature Resistance",
        "Shadow Resistance", "Arcane Resistance", "Fire Resistance", "Expansive Mind", "Engineering Specialization",
        "Every Man for Himself", "Gift of the Naaru", "Heroic Presence", "Gemcutting",
        "War Stomp", "Cultivation", "Endurance", "Nature Resistance", "Axe Specialization", "Command",
        "Blood Frost", "Blood Scent", "Arcane Torrent", "Mana Tap", "Magic Resistance", "Arcane Affinity"
    },
    roleSpellNames = {
        direct_heal = {
            "Heal", "Lesser Heal", "Greater Heal", "Flash Heal", "Binding Heal", "Penance",
            "Holy Light", "Flash of Light", "Holy Shock", "Healing Wave", "Lesser Healing Wave",
            "Healing Touch", "Regrowth", "Nourish", "Chain Heal", "Prayer of Healing", "Circle of Life", "Swiftmend"
        },
        hot = {
            "Renew", "Rejuvenation", "Lifebloom", "Wild Growth", "Riptide", "Prayer of Mending",
            "Renewing Mist", "Enveloping Mist", "Soothing Mist", "Chi Wave", "Chi Burst",
            "Healing Rain", "Healing Stream Totem", "Cloudburst Totem", "Flourishing Tranquility",
            "Renewing Light", "Rejuvenating Swiftness", "Cauterizing Flames", "Cauterizing Fire",
            "Glimmer of Light", "Beacon of Virtue", "Blessed Recovery"
        },
        shield_absorb = {
            "Power Word: Shield", "Sacred Shield", "Earth Shield", "Divine Aegis", "Beacon of Light",
            "Shields of Dominance", "Dominant Word: Shield", "Sheath of Light", "Improved Power Word: Shield",
            "Borrowed Time"
        },
        cleanse = {
            "Cleanse", "Purify", "Cure Disease", "Abolish Disease", "Remove Curse",
            "Abolish Poison", "Cure Poison", "Cleanse Spirit", "Dispel Magic"
        },
        resurrection = {
            "Resurrection", "Redemption", "Revive", "Rebirth", "Ancestral Spirit"
        },
        support = {
            "Pain Suppression", "Guardian Spirit", "Innervate", "Power Infusion", "Mana Tide Totem",
            "Hand of Sacrifice", "Hand of Protection", "Hand of Freedom", "Beacon of Light"
        },
        buff = {
            "Mark of the Wild", "Gift of the Wild", "Thorns", "Power Word: Fortitude", "Prayer of Fortitude",
            "Divine Spirit", "Prayer of Spirit", "Shadow Protection", "Prayer of Shadow Protection",
            "Arcane Intellect", "Arcane Brilliance", "Blessing of Kings", "Greater Blessing of Kings",
            "Blessing of Might", "Greater Blessing of Might", "Blessing of Wisdom", "Greater Blessing of Wisdom",
            "Blessing of Sanctuary", "Greater Blessing of Sanctuary"
        },
        form = { "Tree of Life" },
        damage_to_heal = { "Holy Shock", "Judgement", "Smite", "Atonement" },
    },
    keywordRoles = {
        heal = { "heal", "holy light", "flash of light", "flash heal", "healing wave", "lesser healing wave", "chain heal", "nourish", "regrowth", "healing touch", "circle of life" },
        hot = { "renew", "rejuvenation", "lifebloom", "wild growth", "riptide", "prayer of mending" },
        shield_absorb = { "power word: shield", "sacred shield", "earth shield", "beacon of light", "divine aegis" },
        cleanse = { "cleanse", "purify", "abolish", "remove curse", "cure", "dispel", "cleanse spirit" },
        resurrection = { "resurrection", "redemption", "rebirth", "ancestral spirit", "revive" },
        support = { "pain suppression", "guardian spirit", "innervate", "divine hymn", "mana tide", "power infusion", "hand of sacrifice", "hand of protection", "hand of freedom" },
        buff = { "blessing of", "greater blessing", "mark of the wild", "gift of the wild", "fortitude", "divine spirit", "shadow protection", "arcane intellect", "arcane brilliance", "thorns" },
    },
    trackedAuras = {
        topleft = { "rejuvenation", "renew", "riptide", "sacred shield", "lifebloom" },
        topright = { "prayer of mending", "earth shield", "beacon of light", "wild growth" },
        bottomleft = { "power word: shield", "regrowth", "divine aegis", "abolish disease" },
        bottomright = { "abolish poison", "fear ward", "pain suppression", "guardian spirit" },
        center = { "beacon of light", "earth shield" }
    },
    dispelAbilities = {
        Magic = { 4987, 527, 528 },
        Curse = { 475, 2782, 51886 },
        Disease = { 4987, 528, 552 },
        Poison = { 4987, 2893, 8946 },
    },
    dispelColors = {
        Magic = { 0.20, 0.60, 1.00 },
        Curse = { 0.60, 0.00, 1.00 },
        Disease = { 0.60, 0.40, 0.00 },
        Poison = { 0.00, 0.75, 0.20 },
    },
    dispelPriority = { "Magic", "Curse", "Disease", "Poison" },
    knownSpellRolesById = {},
    knownSpellRolesByName = {},
    smartBindPriorities = {
        LeftButton = {
            { name = "Flash of Light", priority = 1 },
            { name = "Flash Heal", priority = 2 },
            { name = "Lesser Healing Wave", priority = 3 },
            { name = "Nourish", priority = 4 },
            { name = "Healing Touch", priority = 5 },
            { name = "Heal", priority = 6 },
        },
        RightButton = {
            { name = "Rejuvenation", priority = 1 },
            { name = "Renew", priority = 2 },
            { name = "Riptide", priority = 3 },
            { name = "Lifebloom", priority = 4 },
            { name = "Holy Light", priority = 5 },
            { name = "Greater Heal", priority = 6 },
            { name = "Healing Wave", priority = 7 },
        },
        MiddleButton = {
            { name = "Chain Heal", priority = 1 },
            { name = "Wild Growth", priority = 2 },
            { name = "Circle of Life", priority = 3 },
            { name = "Prayer of Mending", priority = 4 },
            { name = "Prayer of Healing", priority = 5 },
        },
        Button4 = {
            { name = "Power Word: Shield", priority = 1 },
            { name = "Earth Shield", priority = 2 },
            { name = "Sacred Shield", priority = 3 },
            { name = "Divine Aegis", priority = 4 },
        },
        Button5 = {
            { name = "Swiftmend", priority = 1 },
            { name = "Penance", priority = 2 },
            { name = "Holy Shock", priority = 3 },
            { name = "Regrowth", priority = 4 },
        }
    }
}

local function indexRoleTables()
    local HI = ns.HealingIntel
    local ids = HI.roleSpellIds or {}
    for role, list in pairs(ids) do
        for _, id in ipairs(list) do
            HI.knownSpellRolesById[id] = role
            local name = GetSpellInfo and GetSpellInfo(id)
            if name and name ~= "" then
                HI.knownSpellRolesByName[string.lower(name)] = role
            end
        end
    end
    for role, names in pairs(HI.roleSpellNames or {}) do
        for _, name in ipairs(names) do
            HI.knownSpellRolesByName[string.lower(name)] = role
        end
    end
end

copyMissing(ns.HealingIntel, fallbackIntel)
indexRoleTables()

ns.HealingIntelDefaults = deepCopy(fallbackIntel)
ns.HealingIntel.meta = ns.HealingIntel.meta or {}
ns.HealingIntel.meta.source = ns.HealingIntel.meta.source or "fallback"

ns.intelListeners = ns.intelListeners or {}
function ns:RegisterIntelListener(callback)
    if type(callback) ~= "function" then return end
    table.insert(self.intelListeners, callback)
end

function ns:NotifyIntelUpdated(reason)
    if not self.intelListeners then return end
    for _, cb in ipairs(self.intelListeners) do
        local ok, err = pcall(cb, reason)
        if not ok and self.Debug then
            self:Debug("Intel listener error: " .. tostring(err), true)
        end
    end
end

if addonName and not ns.addonName then
    ns.addonName = "PB: Healing Frames"
end
