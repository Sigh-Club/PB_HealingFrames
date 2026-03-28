
local _, ns = ...
local ClickCast = ns:RegisterModule("ClickCast", {})
ns.ClickCast = ClickCast

local buttonMap = {
    LeftButton = "1",
    RightButton = "2",
    MiddleButton = "3",
    Button4 = "4",
    Button5 = "5",
}

local function parseSlot(slot)
    local button = slot
    local prefix = nil
    local dash = string.find(slot, "-", 1, true)
    if dash then
        prefix = string.lower(string.sub(slot, 1, dash - 1))
        button = string.sub(slot, dash + 1)
    end
    return prefix, buttonMap[button]
end

local function clearBinding(btn, slot)
    local prefix, index = parseSlot(slot)
    if not index then return end
    if prefix then
        ns:SafeSetAttribute(btn, prefix .. "-type" .. index, nil)
        ns:SafeSetAttribute(btn, prefix .. "-spell" .. index, nil)
        ns:SafeSetAttribute(btn, prefix .. "-macrotext" .. index, nil)
    else
        ns:SafeSetAttribute(btn, "type" .. index, nil)
        ns:SafeSetAttribute(btn, "spell" .. index, nil)
        ns:SafeSetAttribute(btn, "macrotext" .. index, nil)
    end
end

local function applyBinding(btn, slot, data)
    clearBinding(btn, slot)
    local prefix, index = parseSlot(slot)
    if not index or not data then return end

    local tkey = (prefix and (prefix .. "-type" .. index)) or ("type" .. index)
    local skey = (prefix and (prefix .. "-spell" .. index)) or ("spell" .. index)
    local mkey = (prefix and (prefix .. "-macrotext" .. index)) or ("macrotext" .. index)

    if data.type == "spell" and data.value and data.value ~= "" then
        ns:SafeSetAttribute(btn, tkey, "spell")
        ns:SafeSetAttribute(btn, skey, data.value)
    elseif data.type == "target" then
        ns:SafeSetAttribute(btn, tkey, "target")
    elseif data.type == "menu" then
        ns:SafeSetAttribute(btn, tkey, "menu")
    elseif data.type == "macro" and data.value and data.value ~= "" then
        ns:SafeSetAttribute(btn, tkey, "macro")
        ns:SafeSetAttribute(btn, mkey, data.value)
    end
end

function ClickCast:RefreshAll()
    if InCombatLockdown() then
        ns:Debug("Skipped binding refresh in combat")
        return
    end
    if not ns.Frames or not ns.Frames.buttons then return end
    for _, btn in ipairs(ns.Frames.buttons) do
        if btn then
            self:ApplyBindings(btn)
        end
    end
    ns:Debug((ns.L and ns.L.STATUS_REFRESH) or "Click-cast bindings refreshed")
end

function ClickCast:ApplyBindings(btn)
    if not btn then return end
    for _, slot in ipairs(ns.Bindings:GetOrderedSlots()) do
        applyBinding(btn, slot, ns.Bindings:Get(slot))
    end
end

function ClickCast:OnLeaveCombat()
    self:RefreshAll()
end

function ClickCast:OnEnable()
    self:RefreshAll()
end
