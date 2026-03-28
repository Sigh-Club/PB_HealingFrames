local _, ns = ...
local Frames = ns:RegisterModule("Frames", {})
ns.Frames = Frames

Frames.container = nil
Frames.anchors = {}
Frames.buttons = {}
Frames.MAX = 40
Frames.queue = {}

local classColors = RAID_CLASS_COLORS or {}
local STATUS_BAR_TEX = "Interface\\TargetingFrame\\UI-StatusBar"
local SOLID_TEX = "Interface\\Buttons\\WHITE8X8"

local function unpackColor(t, default)
    if type(t) == "table" then return t[1] or 1, t[2] or 1, t[3] or 1 end
    return unpack(default or {1,1,1})
end

local function healthColor(pct)
    local f = ns.DB.frame
    local crit = f.criticalThreshold or 35
    local inj = f.injuredThreshold or 70
    if pct <= crit then return unpackColor(f.criticalColor, {0.95, 0.15, 0.15})
    elseif pct <= inj then return unpackColor(f.injuredColor, {0.95, 0.82, 0.20})
    else return unpackColor(f.healthyColor, {0.15, 0.78, 0.22}) end
end

local function getDispelColor(dtype)
    local intel = ns.HealingIntel or {}
    local c = (ns.DB.frame and ns.DB.frame.dispelColors and ns.DB.frame.dispelColors[dtype]) or (intel.dispelColors and intel.dispelColors[dtype])
    if not c then
        if dtype == "Magic" then return {0.2, 0.6, 1}
        elseif dtype == "Curse" then return {0.6, 0, 1}
        elseif dtype == "Poison" then return {0, 0.6, 0}
        elseif dtype == "Disease" then return {0.6, 0.4, 0}
        end
    end
    return c or { 1, 0, 1 }
end

local function IsUnitInHealRange(unit)
    if not unit or not UnitExists(unit) then return false end
    if UnitIsUnit(unit, "player") or UnitIsUnit(unit, "pet") then return true end
    if UnitIsDeadOrGhost(unit) then return true end
    local spell
    if ns.SpellBook and ns.SpellBook.GetRangeSpellName then
        spell = ns.SpellBook:GetRangeSpellName()
    end
    if spell then
        local r = ns.Compat:IsSpellInRange(spell, unit)
        if r == 1 then return true end
        if r == 0 then return false end
    end
    if UnitInRange and (UnitInParty(unit) or UnitInRaid(unit)) then
        local ok = UnitInRange(unit)
        if ok ~= nil then return ok and true or false end
    end
    return true
end

local function getCurableDebuff(unit)
    local intel = ns.HealingIntel or {}
    local prio = (ns.DB.frame and ns.DB.frame.dispelPriority) or intel.dispelPriority or {"Magic", "Curse", "Poison", "Disease"}
    local best
    for i = 1, 40 do
        local name, _, icon, count, dtype, duration, expirationTime = UnitDebuff(unit, i)
        if not name then break end
        if dtype and ns.SpellBook and ns.SpellBook:PlayerCanDispel(dtype) then
            local rank = 999
            for idx, d in ipairs(prio) do if d == dtype then rank = idx break end end
            if not best or rank < best.rank then
                best = { name = name, texture = icon, dtype = dtype, rank = rank, duration = duration, expires = expirationTime, count = count }
            end
        end
    end
    return best
end

local function CreateAuraIndicator(parent, point, x, y)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(14, 14)
    f:SetPoint(point, parent, point, x, y)
    f:EnableMouse(false)
    
    local icon = f:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon:SetBlendMode("ADD")
    f.icon = icon
    
    local cd = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
    cd:SetAllPoints()
    cd:SetReverse(true)
    if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(true) end
    f.cd = cd
    
    local count = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    count:SetPoint("BOTTOMRIGHT", 1, -1)
    count:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
    f.countText = count

    local timer = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    timer:SetPoint("CENTER", 0, 0)
    timer:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    f.timerText = timer
    
    f:Hide()
    return f
end

local function processQueue()
    if InCombatLockdown() then return end
    for btn, unit in pairs(Frames.queue) do
        btn:SetAttribute("unit", unit)
        Frames.queue[btn] = nil
    end
end

local function setUnit(btn, unit)
    if InCombatLockdown() then
        Frames.queue[btn] = unit
    else
        btn:SetAttribute("unit", unit)
        Frames.queue[btn] = nil
    end
end

local function CreateButton(i)
    local b = CreateFrame("Button", "PB_HF_UnitButton"..i, Frames.container, "SecureUnitButtonTemplate")
    b:RegisterForClicks("AnyUp")
    b:SetAttribute("type2", "target")
    b:SetAttribute("*type1", "target")
    b.index = i

    -- 1. Background (Bottom Layer)
    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(SOLID_TEX)
    bg:SetVertexColor(0, 0, 0, 0.95)
    b.bg = bg

    -- 1a. Border for Bars mode
    local border = b:CreateTexture(nil, "BORDER")
    border:SetAllPoints()
    border:SetTexture(0, 0, 0, 1)
    border:SetPoint("TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", 1, -1)
    b.border = border

    -- 1b. Inner highlight/shine
    local shine = b:CreateTexture(nil, "OVERLAY", nil, 1)
    shine:SetPoint("TOPLEFT", 1, -1)
    shine:SetPoint("BOTTOMRIGHT", -1, 1)
    shine:SetTexture(1, 1, 1, 0.08)
    shine:SetBlendMode("ADD")
    b.shine = shine

    -- 2. Bar Container
    local barContainer = CreateFrame("Frame", nil, b)
    barContainer:SetAllPoints()
    barContainer:SetFrameLevel(b:GetFrameLevel() + 1)
    barContainer:EnableMouse(false)
    b.barContainer = barContainer

    -- 3. Health & Prediction
    local incHeal = CreateFrame("StatusBar", nil, barContainer)
    incHeal:SetPoint("TOPLEFT", 1, -1)
    incHeal:SetPoint("BOTTOMRIGHT", -1, 1)
    incHeal:SetStatusBarTexture(STATUS_BAR_TEX)
    incHeal:SetStatusBarColor(0.2, 1.0, 0.2, 0.4)
    b.incHeal = incHeal

    local hp = CreateFrame("StatusBar", nil, barContainer)
    hp:SetPoint("TOPLEFT", 1, -1)
    hp:SetPoint("BOTTOMRIGHT", -1, 1)
    hp:SetStatusBarTexture(STATUS_BAR_TEX)
    b.hp = hp

    -- 4. Status Overlay (The Tint Fix) - Must cover the WHOLE bar
    local overlayLayer = CreateFrame("Frame", nil, b)
    overlayLayer:SetPoint("TOPLEFT", 1, -1)
    overlayLayer:SetPoint("BOTTOMRIGHT", -1, 1)
    overlayLayer:SetFrameLevel(b:GetFrameLevel() + 5)
    overlayLayer:EnableMouse(false)
    b.overlayLayer = overlayLayer

    local overlay = overlayLayer:CreateTexture(nil, "OVERLAY")
    overlay:SetAllPoints()
    overlay:SetTexture(SOLID_TEX)
    overlay:SetBlendMode("BLEND")
    overlay:Hide()
    b.statusOverlay = overlay

    -- Textured Pattern Overlay (Visual Distinction)
    local statusPattern = overlayLayer:CreateTexture(nil, "OVERLAY", nil, 1)
    statusPattern:SetAllPoints()
    statusPattern:SetTexture("Interface\\ScanningConsole\\ScanningConsole-Volumetrics") 
    statusPattern:SetAlpha(0.25)
    statusPattern:SetBlendMode("ADD")
    statusPattern:Hide()
    b.statusPattern = statusPattern

    -- 5. Selection Glow (Pixel Perfect Border)
    local glow = CreateFrame("Frame", nil, b)
    glow:SetPoint("TOPLEFT", -1, 1)
    glow:SetPoint("BOTTOMRIGHT", 1, -1)
    glow:SetFrameLevel(b:GetFrameLevel() + 8)
    glow:EnableMouse(false)
    local borderTop = glow:CreateTexture(nil, "OVERLAY")
    borderTop:SetPoint("TOPLEFT"); borderTop:SetPoint("TOPRIGHT"); borderTop:SetHeight(1)
    local borderBottom = glow:CreateTexture(nil, "OVERLAY")
    borderBottom:SetPoint("BOTTOMLEFT"); borderBottom:SetPoint("BOTTOMRIGHT"); borderBottom:SetHeight(1)
    local borderLeft = glow:CreateTexture(nil, "OVERLAY")
    borderLeft:SetPoint("TOPLEFT"); borderLeft:SetPoint("BOTTOMLEFT"); borderLeft:SetWidth(1)
    local borderRight = glow:CreateTexture(nil, "OVERLAY")
    borderRight:SetPoint("TOPRIGHT"); borderRight:SetPoint("BOTTOMRIGHT"); borderRight:SetWidth(1)
    
    glow.SetBorderColor = function(self, r, g, bl, a)
        borderTop:SetTexture(r, g, bl, a)
        borderBottom:SetTexture(r, g, bl, a)
        borderLeft:SetTexture(r, g, bl, a)
        borderRight:SetTexture(r, g, bl, a)
    end
    glow:Hide()
    b.glow = glow

    -- 5a. Target Glow (White border)
    local targetGlow = CreateFrame("Frame", nil, b)
    targetGlow:SetPoint("TOPLEFT", -2, 2)
    targetGlow:SetPoint("BOTTOMRIGHT", 2, -2)
    targetGlow:SetFrameLevel(b:GetFrameLevel() + 7)
    targetGlow:EnableMouse(false)
    local tgTop = targetGlow:CreateTexture(nil, "OVERLAY")
    tgTop:SetPoint("TOPLEFT"); tgTop:SetPoint("TOPRIGHT"); tgTop:SetHeight(2); tgTop:SetTexture(1, 1, 1, 0.7)
    local tgBottom = targetGlow:CreateTexture(nil, "BOTTOMLEFT"); tgBottom:SetPoint("BOTTOMRIGHT"); tgBottom:SetHeight(2); tgBottom:SetTexture(1, 1, 1, 0.7)
    local tgLeft = targetGlow:CreateTexture(nil, "TOPLEFT"); tgLeft:SetPoint("BOTTOMLEFT"); tgLeft:SetWidth(2); tgLeft:SetTexture(1, 1, 1, 0.7)
    local tgRight = targetGlow:CreateTexture(nil, "TOPRIGHT"); tgRight:SetPoint("BOTTOMRIGHT"); tgRight:SetWidth(2); tgRight:SetTexture(1, 1, 1, 0.7)
    targetGlow:Hide()
    b.targetGlow = targetGlow

    -- 5b. Focus Glow (Yellow dashed or thinner border)
    local focusGlow = CreateFrame("Frame", nil, b)
    focusGlow:SetPoint("TOPLEFT", -1, 1)
    focusGlow:SetPoint("BOTTOMRIGHT", 1, -1)
    focusGlow:SetFrameLevel(b:GetFrameLevel() + 7)
    focusGlow:EnableMouse(false)
    local fgTop = focusGlow:CreateTexture(nil, "OVERLAY")
    fgTop:SetPoint("TOPLEFT"); fgTop:SetPoint("TOPRIGHT"); fgTop:SetHeight(1); fgTop:SetTexture(1, 1, 0, 0.8)
    local fgBottom = focusGlow:CreateTexture(nil, "BOTTOMLEFT"); fgBottom:SetPoint("BOTTOMRIGHT"); fgBottom:SetHeight(1); fgBottom:SetTexture(1, 1, 0, 0.8)
    local fgLeft = focusGlow:CreateTexture(nil, "TOPLEFT"); fgLeft:SetPoint("BOTTOMLEFT"); fgLeft:SetWidth(1); fgLeft:SetTexture(1, 1, 0, 0.8)
    local fgRight = focusGlow:CreateTexture(nil, "TOPRIGHT"); fgRight:SetPoint("BOTTOMRIGHT"); fgRight:SetWidth(1); fgRight:SetTexture(1, 1, 0, 0.8)
    focusGlow:Hide()
    b.focusGlow = focusGlow

    -- 5c. Threat Glow (Red inner border)
    local threatGlow = CreateFrame("Frame", nil, b)
    threatGlow:SetPoint("TOPLEFT", 1, -1)
    threatGlow:SetPoint("BOTTOMRIGHT", -1, 1)
    threatGlow:SetFrameLevel(b:GetFrameLevel() + 6)
    threatGlow:EnableMouse(false)
    local thTop = threatGlow:CreateTexture(nil, "OVERLAY")
    thTop:SetPoint("TOPLEFT"); thTop:SetPoint("TOPRIGHT"); thTop:SetHeight(2); thTop:SetTexture(1, 0, 0, 1)
    local thBottom = threatGlow:CreateTexture(nil, "OVERLAY")
    thBottom:SetPoint("BOTTOMLEFT"); thBottom:SetPoint("BOTTOMRIGHT"); thBottom:SetHeight(2); thBottom:SetTexture(1, 0, 0, 1)
    local thLeft = threatGlow:CreateTexture(nil, "OVERLAY")
    thLeft:SetPoint("TOPLEFT"); thLeft:SetPoint("BOTTOMLEFT"); thLeft:SetWidth(2); thLeft:SetTexture(1, 0, 0, 1)
    local thRight = threatGlow:CreateTexture(nil, "OVERLAY")
    thRight:SetPoint("TOPRIGHT"); thRight:SetPoint("BOTTOMRIGHT"); thRight:SetWidth(2); thRight:SetTexture(1, 0, 0, 1)
    threatGlow:Hide()
    b.threatGlow = threatGlow

    -- 5c. Hover Highlight
    local hover = b:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetTexture(1, 1, 1, 0.1)
    hover:SetBlendMode("ADD")
    b.hover = hover

    -- 6. Interaction Layer (Top Level)
    local inter = CreateFrame("Frame", nil, b)
    inter:SetAllPoints()
    inter:SetFrameLevel(b:GetFrameLevel() + 15)
    inter:EnableMouse(false)
    b.inter = inter

    local statusText = inter:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statusText:SetPoint("BOTTOM", 0, 2)
    statusText:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
    b.statusText = statusText

    local name = inter:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    name:SetPoint("CENTER", 0, 2)
    name:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    name:SetShadowOffset(1, -1)
    name:SetTextColor(1, 1, 1)
    b.nameText = name

    local roleIcon = inter:CreateTexture(nil, "OVERLAY")
    roleIcon:SetSize(12, 12)
    roleIcon:SetPoint("TOPLEFT", 2, -2)
    roleIcon:Hide()
    b.roleIcon = roleIcon

    local mana = CreateFrame("StatusBar", nil, b)
    mana:SetStatusBarTexture(STATUS_BAR_TEX)
    mana:SetFrameLevel(b:GetFrameLevel() + 3)
    b.mana = mana

    b.auraIndicators = {
        topleft = CreateAuraIndicator(inter, "TOPLEFT", 2, -2),
        topright = CreateAuraIndicator(inter, "TOPRIGHT", -2, -2),
        bottomleft = CreateAuraIndicator(inter, "BOTTOMLEFT", 2, 2),
        bottomright = CreateAuraIndicator(inter, "BOTTOMRIGHT", -2, 2),
        center = CreateAuraIndicator(inter, "CENTER", 0, 0),
    }
    b.auraIndicators.center:SetSize(20, 20)
    b.auraIndicators.center.icon:SetTexCoord(0, 1, 0, 1) -- Fuller icon for center
    b.auraIndicators.center:SetFrameLevel(inter:GetFrameLevel() + 5)

    return b
end

function Frames:CreateAnchor(id)
    local name = id and ("PB_HF_Anchor" .. id) or "PB_HF_Anchor"
    local f = _G[name] or CreateFrame("Frame", name, UIParent)
    f:SetSize(id and 100 or 200, id and 20 or 100)
    
    -- Load position
    local dbf = ns.DB.frame
    if id then
        local pos = dbf.groupPositions[id]
        if pos and pos.x then
            f:ClearAllPoints()
            f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", pos.x, pos.y)
        else
            f:SetPoint("CENTER", -200 + (id-1)*60, 100)
        end
    else
        if dbf.x then
            f:ClearAllPoints()
            f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", dbf.x, dbf.y)
        else
            f:SetPoint("CENTER")
        end
    end

    f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(s) if not ns.DB.locked then s:StartMoving() end end)
    f:SetScript("OnDragStop", function(s) 
        s:StopMovingOrSizing()
        local x, y = s:GetLeft(), s:GetBottom()
        if id then
            dbf.groupPositions[id] = { x = x, y = y }
        else
            dbf.x = x
            dbf.y = y
        end
    end)

    if not f.bg then
        local bg = f:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetTexture(0, 0, 0, 0.4)
        f.bg = bg
    end
    
    if not f.label then
        local lbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("CENTER")
        f.label = lbl
    end
    f.label:SetText(id and ("G" .. id) or "PB:HF")

    f:Show()
    return f
end

function Frames:EnsureAnchors(activeGroups)
    local dbf = ns.DB.frame
    if not self.container then self.container = self:CreateAnchor() end
    
    if not ns.DB.enabled then
        self.container:Hide()
        for i = 1, 8 do
            if self.anchors[i] then self.anchors[i]:Hide() end
        end
        return
    end

    self.container:Show()

    if dbf.splitGroups then
        -- Hide master container visuals
        self.container.bg:Hide()
        self.container.label:Hide()
        
        -- If Unlocked: Show all 8 anchors
        -- If Locked: Only show anchors for groups that have players
        local isUnlocked = not ns.DB.locked
        
        for i = 1, 8 do
            if not self.anchors[i] then
                self.anchors[i] = self:CreateAnchor(i)
            end
            
            local hasPlayers = activeGroups and activeGroups[i]
            if isUnlocked or hasPlayers then
                self.anchors[i]:Show()
                -- Visuals (G1-G8 labels and dark background) only show when UNLOCKED
                -- When locked, the anchor itself is visible (so buttons can be attached) 
                -- but we hide the label/background to keep UI clean.
                if isUnlocked then
                    self.anchors[i].bg:Show()
                    self.anchors[i].label:Show()
                else
                    self.anchors[i].bg:Hide()
                    self.anchors[i].label:Hide()
                end
            else
                self.anchors[i]:Hide()
            end
        end
    else
        -- Combined mode: Only show master anchor visuals if UNLOCKED
        local isUnlocked = not ns.DB.locked
        self.container.bg:SetShown(isUnlocked)
        self.container.label:SetShown(isUnlocked)
        
        for i = 1, 8 do
            if self.anchors[i] then self.anchors[i]:Hide() end
        end
    end
end

function Frames:ApplyLayout()
    local dbf = ns.DB.frame
    local isGrid = dbf.layoutStyle == "grid"
    local cfg = isGrid and dbf.grid or dbf.bars
    local tex = dbf.barTexture or STATUS_BAR_TEX
    
    -- We'll call EnsureAnchors from ApplyRoster now to know active groups
    if not self.container then self.container = self:CreateAnchor() end
    
    local scale = cfg.scale or 1
    self.container:SetScale(scale)
    for i = 1, 8 do
        if self.anchors[i] then self.anchors[i]:SetScale(scale) end
    end

    for i = 1, self.MAX do
        local b = self.buttons[i] or CreateButton(i)
        self.buttons[i] = b
        
        b.hp:SetStatusBarTexture(tex)
        b.incHeal:SetStatusBarTexture(tex)
        
        if isGrid then
            b:SetSize(cfg.size or 40, cfg.size or 40)
            b.nameText:ClearAllPoints()
            b.nameText:SetPoint("CENTER", 0, 0)
            b.nameText:SetJustifyH("CENTER")
            b.statusText:Hide()
            b.border:Hide()
            b.shine:Hide()
        else
            b:SetSize(cfg.width or 180, cfg.height or 22)
            b.nameText:ClearAllPoints()
            b.nameText:SetPoint("LEFT", 6, 0)
            b.nameText:SetJustifyH("LEFT")
            b.statusText:Show()
            b.border:Show()
            b.shine:Show()
        end

        local nfs = dbf.nameFontSize or 10
        local sfs = dbf.statusFontSize or 8
        b.nameText:SetFont("Fonts\\FRIZQT__.TTF", nfs, "OUTLINE")
        b.statusText:SetFont("Fonts\\FRIZQT__.TTF", sfs, "OUTLINE")

        local mh = (dbf.showManaBar and (dbf.manaBarHeight or 3) or 0)
        if mh > 0 then
            b.mana:ClearAllPoints()
            b.mana:SetPoint("BOTTOMLEFT", 1, 1)
            b.mana:SetPoint("BOTTOMRIGHT", -1, 1)
            b.mana:SetHeight(mh)
            b.mana:Show()
        else
            b.mana:Hide()
        end
    end
    self:ApplyRoster()
end

function Frames:ApplyRoster()
    local entries = ns.Roster.entries or {}
    local dbf = ns.DB.frame
    local isGrid = dbf.layoutStyle == "grid"
    local cfg = isGrid and dbf.grid or dbf.bars
    local spacing = cfg.spacing or 4
    local countInGroup = {}
    local activeGroups = {}
    
    local minX, maxX, minY, maxY = 0, 0, 0, 0
    local found = false

    for i = 1, self.MAX do
        local b = self.buttons[i]
        local entry = entries[i]
        if entry then
            b.unit = entry.unit
            b.fakeData = entry.fake and entry or nil
            b:ClearAllPoints()
            
            local group = entry.group or 1
            activeGroups[group] = true
            
            local x, y
            if isGrid then
                local cols = cfg.columns or 5
                local col = (i - 1) % cols
                local row = math.floor((i - 1) / cols)
                x = 8 + col * (cfg.size + spacing)
                y = -8 - row * (cfg.size + spacing)
                b:SetPoint("TOPLEFT", self.container, "TOPLEFT", x, y)
            elseif dbf.splitGroups then
                countInGroup[group] = (countInGroup[group] or 0) + 1
                local anchor = self.anchors[group] or self:CreateAnchor(group)
                self.anchors[group] = anchor
                b:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, - (countInGroup[group] - 1) * (cfg.height + spacing))
            else
                countInGroup[group] = (countInGroup[group] or 0) + 1
                local perRow = cfg.groupsPerRow or 2
                local groupSpacing = cfg.groupSpacing or 18
                local gCol = (group - 1) % perRow
                local gRow = math.floor((group - 1) / perRow)
                x = 8 + gCol * (cfg.width + groupSpacing)
                y = -8 - gRow * ((cfg.height + spacing) * 5 + groupSpacing) - (countInGroup[group] - 1) * (cfg.height + spacing)
                b:SetPoint("TOPLEFT", self.container, "TOPLEFT", x, y)
            end
            
            -- Track bounds for master container (non-split mode)
            if not dbf.splitGroups then
                local bw, bh = b:GetWidth(), b:GetHeight()
                if not found then
                    minX, maxX, minY, maxY = x, x + bw, y - bh, y
                    found = true
                else
                    minX = math.min(minX, x)
                    maxX = math.max(maxX, x + bw)
                    minY = math.min(minY, y - bh)
                    maxY = math.max(maxY, y)
                end
            end

            ns:SafeSetAttribute(b, "unit", entry.unit)
            b:Show()
            self:UpdateButton(b)
        else
            b:Hide()
            b.unit = nil
            ns:SafeSetAttribute(b, "unit", nil)
        end
    end

    if found and not dbf.splitGroups then
        -- Resize container to fit all buttons + padding
        self.container:SetSize(maxX - minX + 16, math.abs(maxY - minY) + 16)
    elseif not dbf.splitGroups then
        self.container:SetSize(200, 100)
    end
    
    -- Now ensure anchors are shown correctly based on active groups
    self:EnsureAnchors(activeGroups)
end

local function ShortenName(name)
    local dbf = ns.DB.frame
    local isGrid = dbf.layoutStyle == "grid"
    local cfg = isGrid and dbf.grid or dbf.bars
    if not cfg.shortenNames then return name end
    local len = tonumber(cfg.nameLength) or (isGrid and 6 or 12)
    if not name or string.len(name) <= len then return name end
    
    if len <= 4 then
        return string.sub(name, 1, len)
    elseif len <= 6 then
        return string.sub(name, 1, 4) .. string.sub(name, -1, -1)
    else
        return string.sub(name, 1, len-1) .. "~"
    end
end

function Frames:UpdateButton(b)
    if not ns.DB.enabled then b:Hide(); return end
    local unit = b.unit
    local fake = b.fakeData
    local dbf = ns.DB.frame
    local name, hp, maxhp, pct, debuff, mana, maxmana, status, role, threat

    if fake then
        name = fake.name
        maxhp = 100
        local t = GetTime()
        hp = math.floor(25 + (math.sin(t + (b.index or 0)*0.5) + 1) * 35)
        pct = math.floor((hp / maxhp) * 100)
        if fake.fakeDebuff then debuff = { dtype = fake.fakeDebuff } end
        local cc = classColors[fake.classToken or "PRIEST"]
        b.nameText:SetTextColor(cc.r, cc.g, cc.b)
        threat = (b.index % 7 == 0) and 3 or 0
    else
        if not unit or not UnitExists(unit) then return end
        name, hp, maxhp = UnitName(unit), UnitHealth(unit), UnitHealthMax(unit)
        mana, maxmana = UnitPower(unit), UnitPowerMax(unit)
        maxhp = (maxhp > 0) and maxhp or 1
        pct = math.floor((hp / maxhp) * 100)
        debuff = getCurableDebuff(unit)
        local _, class = UnitClass(unit)
        local cc = classColors[class] or {r=1, g=1, b=1}
        b.nameText:SetTextColor(cc.r, cc.g, cc.b)
        
        if UnitInRaid(unit) then
            local _, raidRole = GetRaidRosterInfo(string.match(unit, "%d+") or 0)
            if raidRole == "MAINTANK" then role = "TANK" end
        end

        threat = UnitThreatSituation(unit) or 0

        if UnitIsDeadOrGhost(unit) then status = "DEAD"
        elseif not UnitIsConnected(unit) then status = "OFFLINE" end
        
        b.curableDebuff = debuff -- This now includes .texture, .count, .duration, .expires
    end

    b.nameText:SetText(ShortenName(name))

    b.hp:SetMinMaxValues(0, maxhp)
    b.hp:SetValue(hp)
    b.incHeal:SetMinMaxValues(0, maxhp)
    
    local r, g, bl = healthColor(pct)
    if dbf.useClassColors and not fake and unit then
        local _, class = UnitClass(unit)
        local cc = classColors[class] or {r=1, g=1, b=1}
        r, g, bl = cc.r, cc.g, cc.b
    elseif dbf.useClassColors and fake then
        local cc = classColors[fake.classToken or "PRIEST"]
        r, g, bl = cc.r, cc.g, cc.b
    end

    local tex = dbf.barTexture or STATUS_BAR_TEX
    b.hp:SetStatusBarTexture(tex)
    b.incHeal:SetStatusBarTexture(tex)

    if dbf.invertedColors then
        b.bg:SetVertexColor(r, g, bl, 0.9)
        b.hp:SetStatusBarColor(0, 0, 0, 0.8)
        b.hp:SetValue(maxhp - hp)
    else
        b.bg:SetVertexColor(0, 0, 0, 0.95)
        b.hp:SetStatusBarColor(r, g, bl, 0.9)
        b.hp:SetValue(hp)
    end

    -- Role Icon
    if role == "TANK" then
        b.roleIcon:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES")
        b.roleIcon:SetTexCoord(0, 19/64, 22/64, 41/64)
        b.roleIcon:Show()
    else
        b.roleIcon:Hide()
    end

    -- Threat Indicator
    if threat >= 2 and dbf.showAggroBorder ~= false then
        b.threatGlow:Show()
    else
        b.threatGlow:Hide()
    end

    -- THE FIX: Solid Color Overlay that scales perfectly
    if debuff and debuff.dtype and dbf.highlightCurableDebuffs then
        local dc = getDispelColor(debuff.dtype)
        b.statusOverlay:SetVertexColor(dc[1], dc[2], dc[3], 0.45)
        b.statusOverlay:Show()
        b.glow:SetBorderColor(dc[1], dc[2], dc[3], 1)
        b.glow:Show()
    else
        b.statusOverlay:Hide()
        b.glow:Hide()
    end

    if not fake and unit and UnitIsUnit(unit, "target") and dbf.showTargetGlow ~= false then
        b.targetGlow:Show()
    else
        b.targetGlow:Hide()
    end

    if not fake and unit and UnitIsUnit(unit, "focus") then
        b.focusGlow:Show()
    else
        b.focusGlow:Hide()
    end

    local stText = status
    if not stText then
        if hp < maxhp and dbf.showDeficit ~= false then
            local diff = maxhp - hp
            if diff >= 1000 then
                stText = string.format("-%.1fk", diff / 1000)
            else
                stText = "-" .. diff
            end
        else
            stText = pct .. "%"
        end
    end
    b.statusText:SetText(stText)
    
    if b.mana:IsShown() then
        b.mana:SetMinMaxValues(0, maxmana or 1)
        b.mana:SetValue(mana or 0)
        b.mana:SetStatusBarColor(0.2, 0.4, 1.0)
    end

    -- Hover Highlight
    local hc = dbf.hoverColor or {1, 1, 1, 0.1}
    b.hover:SetVertexColor(hc[1], hc[2], hc[3], hc[4] or 0.1)

    self:UpdateRange(b)
    if ns.Auras then ns.Auras:UpdateButtonAuras(b) end
    if ns.HealComm then ns.HealComm:UpdateUnit(b) end
    if ns.ClickCast then ns.ClickCast:ApplyBindings(b) end
end

function Frames:UpdateRange(b)
    if not b.unit or b.fakeData then b:SetAlpha(1) return end
    local inRange = IsUnitInHealRange(b.unit)
    b:SetAlpha(inRange and 1 or (ns.DB.frame.outOfRangeAlpha or 0.35))
end

function Frames:ResetAnchorPositions()
    local dbf = ns.DB.frame
    dbf.x = nil
    dbf.y = nil
    dbf.groupPositions = {}
    
    if self.container then
        self.container:ClearAllPoints()
        self.container:SetPoint("CENTER")
    end
    
    for i = 1, 8 do
        if self.anchors[i] then
            self.anchors[i]:ClearAllPoints()
            self.anchors[i]:SetPoint("CENTER", -200 + (i-1)*60, 100)
        end
    end
    
    self:ApplyLayout()
    ns:Print("Anchor positions reset to default.")
end

function Frames:OnInitialize() self:EnsureAnchors() end
function Frames:OnEnable() self:ApplyLayout() end
function Frames:OnEvent(event, unit) 
    if event == "PLAYER_ENTERING_WORLD" or event == "PARTY_MEMBERS_CHANGED" or event == "RAID_ROSTER_UPDATE" then
        self:ApplyLayout() 
    elseif event == "PLAYER_REGEN_ENABLED" then
        processQueue()
    elseif event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_FOCUS_CHANGED" then
        for _, b in ipairs(self.buttons) do 
            if b:IsShown() and b.unit then self:UpdateButton(b) end 
        end
    elseif unit then
        for _, b in ipairs(self.buttons) do if b.unit == unit then self:UpdateButton(b) end end
    end
end
