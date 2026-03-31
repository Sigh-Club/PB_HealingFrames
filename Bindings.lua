
local _, ns = ...
local Bindings = ns:RegisterModule("Bindings", {})
ns.Bindings = Bindings

local orderedSlots = {
    "LeftButton",
    "RightButton",
    "MiddleButton",
    "MouseWheelUp",
    "MouseWheelDown",
    "Button4",
    "Button5",
    "Shift-LeftButton",
    "Shift-RightButton",
    "Ctrl-LeftButton",
    "Ctrl-RightButton",
    "Alt-LeftButton",
    "Alt-RightButton",
}

local fallbackSmartBindPriorities = {
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
        { name = "Prayer of Healing", priority = 3 },
    },
    Button4 = {
        { name = "Power Word: Shield", priority = 1 },
        { name = "Earth Shield", priority = 2 },
        { name = "Sacred Shield", priority = 3 },
    },
    Button5 = {
        { name = "Swiftmend", priority = 1 },
        { name = "Penance", priority = 2 },
        { name = "Holy Shock", priority = 3 },
        { name = "Regrowth", priority = 4 },
    },
}

local buttonPriority = {
    LeftButton = 1,
    RightButton = 2,
    MiddleButton = 3,
    MouseWheelUp = 4,
    MouseWheelDown = 5,
    Button4 = 6,
    Button5 = 7,
}

function Bindings:GetOrderedSlots()
    local slots = {}
    for k in pairs(ns.DB.bindings) do
        table.insert(slots, k)
    end
    table.sort(slots, function(a, b)
        -- Extract modifiers and base button
        local aParts = { strsplit("-", a) }
        local bParts = { strsplit("-", b) }
        local aBase = aParts[#aParts]
        local bBase = bParts[#bParts]
        local aNumMods = #aParts - 1
        local bNumMods = #bParts - 1

        -- 1. Sort by number of modifiers (none first)
        if aNumMods ~= bNumMods then return aNumMods < bNumMods end
        
        -- 2. Sort by base button priority
        local ap = buttonPriority[aBase] or 99
        local bp = buttonPriority[bBase] or 99
        if ap ~= bp then return ap < bp end
        
        -- 3. Alphabetical fallback
        return a < b
    end)
    return slots
end

function Bindings:SetBinding(slot, btype, value)
    ns.DB.bindings[slot] = { type = btype, value = value }
    ns:Print((ns.L and ns.L.STATUS_BINDING_SET or "Binding updated") .. ": " .. slot .. " -> " .. (value ~= "" and value or btype))
    if ns.ClickCast then ns.ClickCast:RefreshAll() end
    if ns.UI_Main then ns.UI_Main:RefreshKeybinds() end
end

function Bindings:Get(slot)
    return ns.DB.bindings[slot] or { type = "spell", value = "" }
end

function Bindings:SetSpell(slot, spellName)
    self:SetBinding(slot, "spell", spellName)
end

function Bindings:SetTarget(slot)
    self:SetBinding(slot, "target", "")
end

function Bindings:SetMenu(slot)
    self:SetBinding(slot, "menu", "")
end

function Bindings:SetMacro(slot, macroText)
    self:SetBinding(slot, "macro", macroText)
end

function Bindings:Clear(slot)
    ns.DB.bindings[slot] = nil
    ns:Print((ns.L and ns.L.STATUS_BINDING_CLEARED or "Binding cleared") .. ": " .. slot)
    if ns.ClickCast then ns.ClickCast:RefreshAll() end
    if ns.UI_Main then ns.UI_Main:RefreshKeybinds() end
end

local function isEmpty(rec)
    return not rec or not rec.value or rec.value == ""
end

local function pickBestCleanseSpell(knownSpells, bindable)
    local intel = ns.HealingIntel or {}
    for _, name in ipairs((intel.roleSpellNames and intel.roleSpellNames.cleanse) or {}) do
        local exact = knownSpells[string.lower(name)]
        if exact then return exact end
    end
    for _, sp in ipairs(bindable) do
        if sp.role == "cleanse" then
            return sp.name
        end
    end
    return nil
end

function Bindings:SmartBind()
    ns:Debug("SmartBind: Starting...", true)
    if InCombatLockdown() then
        ns:Print("Cannot smart bind while in combat.")
        ns:Debug("SmartBind failed: Player in combat", true)
        return
    end

    local intel = ns.HealingIntel or {}
    local prioritiesMap = nil

    if ns.BuildState and ns.BuildState.GetSmartBindOverrides then
        prioritiesMap = ns.BuildState:GetSmartBindOverrides()
    end
    if not prioritiesMap then
        prioritiesMap = intel.smartBindPriorities
    end
    if not prioritiesMap then
        prioritiesMap = fallbackSmartBindPriorities
        ns:Print("SmartBind priorities missing. Using built-in fallback map.")
        ns:Debug("SmartBind fallback active", true)
    end

    local bindable = (ns.SpellBook and ns.SpellBook.GetBindable and ns.SpellBook:GetBindable()) or {}
    ns:Debug("SmartBind: Bindable spells count: " .. #bindable, true)
    if #bindable == 0 then
        ns:Print("SmartBind failed: No bindable spells found. Run /pb scan first.")
        return
    end

    local knownSpells = {}
    local normalizedKnown = {}
    local function normalize(s) return s:lower():gsub("[%s%p]", "") end

    for _, spell in ipairs(bindable) do
        local name = spell.name
        local resolved = name
        if ns.EnchantDetect and ns.EnchantDetect.GetResolvedSpellName then
            resolved = ns.EnchantDetect:GetResolvedSpellName(name) or name
        end
        knownSpells[name:lower()] = resolved
        knownSpells[resolved:lower()] = resolved
        normalizedKnown[normalize(name)] = resolved
        normalizedKnown[normalize(resolved)] = resolved
    end

    wipe(ns.DB.bindings)

    local usedSpells = {}

    local changesMade = 0

    local caps = ns.SpellBook and ns.SpellBook.dispelCapabilities
    if caps and (caps.Magic or caps.Curse or caps.Disease or caps.Poison) then
        local cleanseSlot = nil
        for _, candidateSlot in ipairs({ "Shift-LeftButton", "MiddleButton", "Button5" }) do
            if isEmpty(self:Get(candidateSlot)) then
                cleanseSlot = candidateSlot
                break
            end
        end

        if cleanseSlot then
            local bestCleanse = pickBestCleanseSpell(knownSpells, bindable)
            if bestCleanse then
                local rec = self:Get(cleanseSlot)
                rec.type = "macro"
                rec.value = "/cast [@mouseover,help,nodead][] " .. bestCleanse
                usedSpells[bestCleanse:lower()] = true
                ns:Print("SmartBind: Assigned Cleanse to " .. cleanseSlot)
                changesMade = changesMade + 1
            end
        end
    end

    for _, slot in ipairs(orderedSlots) do
        local priorities = prioritiesMap[slot]
        if priorities then
            for _, candidate in ipairs(priorities) do
                local cname = candidate.name
                local exactName = knownSpells[cname:lower()] or normalizedKnown[normalize(cname)]

                if exactName and not usedSpells[exactName:lower()] then
                    self:SetBinding(slot, "spell", exactName)
                    usedSpells[exactName:lower()] = true
                    ns:Print("SmartBind: Assigned " .. exactName .. " to " .. slot)
                    changesMade = changesMade + 1
                    break
                end
            end
        end
    end

    ns:Print(string.format("SmartBind finished. Changes=%d", changesMade))
    if changesMade > 0 then
        if ns.ClickCast then ns.ClickCast:RefreshAll() end
        if ns.UI_Bindings then ns.UI_Bindings:RefreshSlots() end
        if ns.UI_Main then ns.UI_Main:RefreshKeybinds() end
    end
end
