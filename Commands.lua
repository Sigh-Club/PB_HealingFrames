local _, ns = ...
local Commands = ns:RegisterModule("Commands", {})
ns.Commands = Commands

SLASH_PBHF1 = "/pb"
SLASH_PBHF2 = "/pbhf"

local function trim(s) return (s or ""):gsub("^%s+", ""):gsub("%s+$", "") end

SlashCmdList["PBHF"] = function(msg)
    if not ns or not ns.DB then 
        print("|cff7cc7ffPB:HF|r Error: Addon database not initialized yet.")
        return 
    end
    msg = trim(msg:lower())
    
    if msg == "config" or msg == "" then
        if ns.UI_Main and ns.UI_Main.Toggle then 
            ns.UI_Main:Toggle() 
        else 
            ns:Print("Error: UI module failed to load.") 
        end
    elseif msg == "on" then
        ns:SetEnabled(true); ns:Print("Enabled.")
    elseif msg == "off" then
        ns:SetEnabled(false); ns:Print("Disabled.")
    elseif msg == "toggle" then
        ns:SetEnabled(not ns.DB.enabled); ns:Print(ns.DB.enabled and "Enabled." or "Disabled.")
    elseif msg == "scan" then
        if ns.SpellBook and ns.SpellBook.Scan then ns.SpellBook:Scan() end
    elseif msg == "smartbind" then
        if ns.Bindings and ns.Bindings.SmartBind then ns.Bindings:SmartBind() end
    elseif msg:match("^test") then
        local n = tonumber(msg:match("test%s+(%d+)"))
        if msg == "test off" then
            if ns.Roster then ns.Roster:SetFakeMode(false) end
        else
            if ns.Roster then ns.Roster:SetFakeMode(true, n or 10) end
        end
    elseif msg == "lock" then
        ns.DB.locked = true; ns:Print("Frames Locked.")
    elseif msg == "unlock" then
        ns.DB.locked = false; ns:Print("Frames Unlocked.")
    else
        ns:Print("Usage: /pb [config|scan|smartbind|test 5-40|lock|unlock]")
    end
end
