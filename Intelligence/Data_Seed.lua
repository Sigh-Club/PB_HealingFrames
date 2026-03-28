
local _, ns = ...
ns = ns or _G.PB_HealingFrames or {}
_G.PB_HealingFrames = ns

local HI = ns.HealingIntel or {}
ns.HealingIntel = HI

HI.design_principles = {
    "Do not assume class implies healer.",
    "Do not assume helpful-flagged spells are the only healing actions.",
    "Use player-tagged roles as source of truth; use heuristics only as suggestions.",
    "Support direct-heal, HoT, shield, damage-to-heal, cleanse, resurrection, proc-heal and cooldown patterns.",
}

HI.roleSpellIds = {
    direct_heal = { 2050, 2054, 2060, 2061, 635, 19750, 331, 8004, 8005, 5185, 8936, 50464, 1064, 596, 34861, 48785 },
    hot = { 139, 774, 33763, 48438, 61295, 33076 },
    shield_absorb = { 17, 47515, 53563, 53601, 974 },
    cleanse = { 4987, 527, 528, 552, 475, 2782, 2893, 8946, 51886 },
    resurrection = { 2006, 7328, 50769, 20484, 20773 },
    support = { 33206, 47788, 29166, 10060, 16190, 6940, 1022, 1044, 53563 },
    damage_to_heal = { 20473, 635, 585, 20271 },
}

HI.healingRoles = {
    heal = true, direct_heal = true, hot = true, shield_absorb = true, damage_to_heal = true,
}

HI.supportRoles = {
    support = true, cleanse = true, resurrection = true, buff = true, form = true,
}

HI.racialSpellNames = {
    "Shadowmeld", "Blood Fury", "Will of the Forsaken", "Cannibalize", "Hardiness", "Berserking",
    "Stoneform", "Escape Artist", "Perception", "The Human Spirit", "Diplomacy", "Mace Specialization",
    "Sword Specialization", "Find Treasure", "Gun Specialization", "Frost Resistance", "Nature Resistance",
    "Shadow Resistance", "Arcane Resistance", "Fire Resistance", "Expansive Mind", "Engineering Specialization",
    "Every Man for Himself", "Gift of the Naaru", "Heroic Presence", "Gemcutting",
    "War Stomp", "Cultivation", "Endurance", "Nature Resistance", "Axe Specialization", "Command",
    "Blood Frost", "Blood Scent", "Arcane Torrent", "Mana Tap", "Magic Resistance", "Arcane Affinity"
}

HI.roleSpellNames = {
    direct_heal = {
        "Heal", "Lesser Heal", "Greater Heal", "Flash Heal", "Binding Heal", "Penance",
        "Holy Light", "Flash of Light", "Holy Shock", "Healing Wave", "Lesser Healing Wave",
        "Healing Touch", "Regrowth", "Nourish", "Chain Heal", "Prayer of Healing", "Circle of Life", "Swiftmend"
    },
    hot = {
        "Renew", "Rejuvenation", "Lifebloom", "Wild Growth", "Riptide", "Prayer of Mending"
    },
    shield_absorb = {
        "Power Word: Shield", "Sacred Shield", "Earth Shield", "Divine Aegis", "Beacon of Light"
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
}

HI.keywordRoles = {
    heal = { "heal", "holy light", "flash of light", "flash heal", "healing wave", "lesser healing wave", "chain heal", "nourish", "regrowth", "healing touch", "circle of life" },
    hot = { "renew", "rejuvenation", "lifebloom", "wild growth", "riptide", "prayer of mending" },
    shield_absorb = { "power word: shield", "sacred shield", "earth shield", "beacon of light", "divine aegis" },
    cleanse = { "cleanse", "purify", "abolish", "remove curse", "cure", "dispel", "cleanse spirit" },
    resurrection = { "resurrection", "redemption", "rebirth", "ancestral spirit", "revive" },
    support = { "pain suppression", "guardian spirit", "innervate", "divine hymn", "mana tide", "power infusion", "hand of sacrifice", "hand of protection", "hand of freedom" },
    buff = { "blessing of", "greater blessing", "mark of the wild", "gift of the wild", "fortitude", "divine spirit", "shadow protection", "arcane intellect", "arcane brilliance", "thorns" },
}

-- ONE SOURCE OF TRUTH FOR TRACKED AURAS
HI.trackedAuras = {
    topleft = {
        "rejuvenation", "renew", "riptide", "sacred shield", "lifebloom"
    },
    topright = {
        "prayer of mending", "earth shield", "beacon of light", "wild growth"
    },
    bottomleft = {
        "power word: shield", "regrowth", "divine aegis", "abolish disease"
    },
    bottomright = {
        "abolish poison", "fear ward", "pain suppression", "guardian spirit"
    },
    center = {
        "beacon of light", "earth shield" -- Also track these in center if needed
    }
}

HI.dispelAbilities = {
    Magic = { 4987, 527, 528 },
    Curse = { 475, 2782, 51886 },
    Disease = { 4987, 528, 552 },
    Poison = { 4987, 2893, 8946 },
}

HI.dispelColors = {
    Magic = { 0.20, 0.60, 1.00 },
    Curse = { 0.60, 0.00, 1.00 },
    Disease = { 0.60, 0.40, 0.00 },
    Poison = { 0.00, 0.75, 0.20 },
}

HI.dispelPriority = { "Magic", "Curse", "Disease", "Poison" }

HI.knownSpellRolesById = {}
HI.knownSpellRolesByName = {}

local function addRole(role, id)
    if id then
        HI.knownSpellRolesById[id] = role
        local name = GetSpellInfo and GetSpellInfo(id)
        if name and name ~= "" then
            HI.knownSpellRolesByName[string.lower(name)] = role
        end
    end
end

for role, ids in pairs(HI.roleSpellIds) do
    for _, id in ipairs(ids) do addRole(role, id) end
end
for role, names in pairs(HI.roleSpellNames) do
    for _, name in ipairs(names) do
        HI.knownSpellRolesByName[string.lower(name)] = role
    end
end

HI.smartBindPriorities = {
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
