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
        ns:SetEnabled(true)
    elseif msg == "off" then
        ns:SetEnabled(false)
    elseif msg == "toggle" then
        ns:SetEnabled(not ns.DB.enabled)
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
    elseif msg:match("^debug") then
        local args = trim(msg:sub(6))
        if args == "" then
            -- ns:Print("Usage: /pb debug [on|off|auras <unit>]")
        elseif args == "on" then
            if ns.Debug and ns.Debug.SetEnabled then ns.Debug:SetEnabled(true) end
        elseif args == "off" then
            if ns.Debug and ns.Debug.SetEnabled then ns.Debug:SetEnabled(false) end
        else
            local unit = args:match("^auras%s+(%S+)")
            if unit then
                if ns.Auras and ns.Auras.DumpUnitAuras then
                    ns.Auras:DumpUnitAuras(unit)
                else
                    ns:Print("Auras module not available.")
                end
            else
                -- ns:Print("Usage: /pb debug [on|off|auras <unit>]")
            end
        end
    elseif msg:match("^sample") then
        local args = trim(msg:sub(7))
        if ns.Auras and ns.Auras.HandleSampleCommand then
            ns.Auras:HandleSampleCommand(args)
        else
            ns:Print("Aura sampling module unavailable.")
        end
    elseif msg == "lock" then
        ns.DB.locked = true
    elseif msg == "unlock" then
        ns.DB.locked = false
    else
        -- ns:Print("Usage: /pb [config|scan|smartbind|test 5-40|debug|sample|lock|unlock]")
    end
end
