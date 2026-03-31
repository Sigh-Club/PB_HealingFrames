local _, ns = ...
local UI = ns:RegisterModule("UI_Main", {})
ns.UI_Main = UI

local frame
local tabs = {}
local activeTab = "General"
local tabContent = {}

local function mkCheck(parent, label, tooltip, get, set)
    local b = CreateFrame("CheckButton", "PB_HF_Check"..math.random(1000,9999), parent, "InterfaceOptionsCheckButtonTemplate")
    local text = _G[b:GetName() .. "Text"]
    if text then text:SetText(label) end
    b.tooltipText = tooltip
    b:SetChecked(get())
    b:SetScript("OnClick", function(self)
        set(self:GetChecked())
        if ns.Frames and ns.Frames.ApplyLayout then ns.Frames:ApplyLayout() end
    end)
    return b
end

local function mkSlider(parent, label, minv, maxv, step, getter, setter)
    local s = CreateFrame("Slider", "PB_HF_Slider"..math.random(1000,9999), parent, "OptionsSliderTemplate")
    s:SetWidth(180); s:SetMinMaxValues(minv, maxv); s:SetValueStep(step)
    if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
    
    local name = s:GetName()
    _G[name .. "Low"]:SetText(tostring(minv))
    _G[name .. "High"]:SetText(tostring(maxv))

    local text = s:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    text:SetPoint("BOTTOM", s, "TOP", 0, 2)
    s.text = text

    s:SetScript("OnValueChanged", function(self, value)
        value = math.floor((value / step) + 0.5) * step
        if value ~= getter() then
            setter(value)
            self.text:SetText(label .. ": " .. tostring(value))
            if ns.Frames and ns.Frames.ApplyLayout then ns.Frames:ApplyLayout() end
        end
    end)
    
    s:SetValue(getter())
    s.text:SetText(label .. ": " .. tostring(getter()))
    return s
end

local function openColorPicker(current, callback)
    local r, g, bl, a = current[1], current[2], current[3], current[4] or 1
    ColorPickerFrame.func = function()
        local nr, ng, nb = ColorPickerFrame:GetColorRGB()
        local na = ColorPickerFrame.hasOpacity and (1 - OpacitySliderFrame:GetValue()) or 1
        callback({nr, ng, nb, na})
    end
    ColorPickerFrame.cancelFunc = function(prev)
        callback({prev.r, prev.g, prev.b, prev.opacity and (1 - prev.opacity) or 1})
    end
    ColorPickerFrame.hasOpacity = (current[4] ~= nil)
    ColorPickerFrame.opacity = 1 - a
    ColorPickerFrame.previousValues = { r = r, g = g, b = bl, opacity = 1 - a }
    ColorPickerFrame:SetColorRGB(r, g, bl)
    ColorPickerFrame:Hide(); ColorPickerFrame:Show()
end

local function mkColorButton(parent, label, getter, setter)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(100, 24); btn:SetText(label)
    btn.swatch = btn:CreateTexture(nil, "OVERLAY")
    btn.swatch:SetSize(18, 18); btn.swatch:SetPoint("LEFT", btn, "RIGHT", 5, 0)
    
    local function updateSwatch()
        local c = getter()
        btn.swatch:SetTexture(c[1], c[2], c[3], c[4] or 1)
    end
    
    btn:SetScript("OnClick", function()
        openColorPicker(getter(), function(c) 
            setter(c)
            updateSwatch()
            if ns.Frames and ns.Frames.ApplyLayout then ns.Frames:ApplyLayout() end
        end)
    end)
    updateSwatch()
    return btn
end

local function CreateFrameBackdrop(f)
    if not f.SetBackdrop then return end
    f:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    f:SetBackdropColor(0, 0, 0, 0.95)
    f:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
end

function UI:CreateMainWindow()
    if frame then return end

    frame = CreateFrame("Frame", "PB_HealingFramesConfig", UIParent)
    frame:SetSize(850, 600)
    frame:SetPoint("CENTER")
    frame:SetMovable(true); frame:EnableMouse(true); frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetFrameStrata("DIALOG")
    CreateFrameBackdrop(frame)
    frame:SetBackdropColor(0, 0, 0, 0.9)
    
    frame:Hide()

    local headerIcon = frame:CreateTexture(nil, "OVERLAY")
    headerIcon:SetSize(40, 40)
    headerIcon:SetPoint("TOPLEFT", 10, -5)
    headerIcon:SetTexture("Interface\\AddOns\\PB_HealingFrames\\Media\\MTCbadge.tga")

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetFont("Fonts\\FRIZQT__.TTF", 20, "OUTLINE")
    title:SetPoint("LEFT", headerIcon, "RIGHT", 10, 0)
    title:SetText("PB: Healing Frames V 1.3.6 beta")

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -5, -5)

    local sidebar = CreateFrame("Frame", nil, frame)
    sidebar:SetSize(180, 520); sidebar:SetPoint("TOPLEFT", 10, -65)
    CreateFrameBackdrop(sidebar); sidebar:SetBackdropColor(0.1, 0.1, 0.1, 0.5)

    local sideIcon = sidebar:CreateTexture(nil, "BACKGROUND")
    sideIcon:SetSize(160, 160)
    sideIcon:SetPoint("BOTTOM", sidebar, "BOTTOM", 0, 15)
    sideIcon:SetTexture("Interface\\AddOns\\PB_HealingFrames\\Media\\MekTownChoppaz.tga")
    sideIcon:SetAlpha(0.9)

    local content = CreateFrame("Frame", nil, frame)
    content:SetSize(640, 520); content:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 10, 0)
    CreateFrameBackdrop(content); content:SetBackdropColor(0.1, 0.1, 0.1, 0.5)
    self.contentArea = content

    local wallpaper = content:CreateTexture(nil, "BACKGROUND", nil, -8)
    wallpaper:SetPoint("CENTER", 0, 0)
    wallpaper:SetSize(512, 512)
    wallpaper:SetTexture("Interface\\AddOns\\PB_HealingFrames\\Media\\MTCIcon.tga")
    wallpaper:SetAlpha(0.8)
    
    local tint = content:CreateTexture(nil, "BACKGROUND", nil, -7)
    tint:SetAllPoints()
    tint:SetTexture(0, 0, 0, 0.3)

    local tabList = { "General", "Layout", "Style", "Keybinds", "Profiles" }
    for i, name in ipairs(tabList) do
        local btn = CreateFrame("Button", nil, sidebar, "UIPanelButtonTemplate")
        btn:SetSize(160, 36); btn:SetPoint("TOP", 0, -20 - (i-1) * 42)
        btn:SetText(name)
        btn:SetScript("OnClick", function() self:ShowTab(name) end)
        tabs[name] = btn
        
        local scroll = CreateFrame("ScrollFrame", "PB_HF_TabScroll"..name, content, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 15, -15)
        scroll:SetPoint("BOTTOMRIGHT", -35, 15)
        scroll:Hide()
        
        local child = CreateFrame("Frame", nil, scroll)
        child:SetSize(580, 1200)
        scroll:SetScrollChild(child)
        
        tabContent[name] = { scroll = scroll, child = child }
    end
end

function UI:ShowTab(name)
    if not frame then self:CreateMainWindow() end
    activeTab = name
    for tName, data in pairs(tabContent) do
        if tName == name then
            tabs[tName]:LockHighlight()
            data.scroll:Show()
            if name == "General" then self:LoadGeneral(data.child)
            elseif name == "Layout" then self:LoadLayout(data.child)
            elseif name == "Style" then self:LoadStyle(data.child)
            elseif name == "Keybinds" then self:LoadKeybinds(data.child)
            elseif name == "Profiles" then self:LoadProfiles(data.child) end
        else
            tabs[tName]:UnlockHighlight()
            data.scroll:Hide()
        end
    end
end

function UI:LoadGeneral(c)
    if c.loaded then return end
    local y = 0
    
    local title = c:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 15, y); title:SetText("General")
    y = y - 45

    local master = mkCheck(c, "Enable PB: Healing Frames", "Toggle the entire addon on or off.", 
        function() return ns.DB.enabled ~= false end, function(v) ns:SetEnabled(v) end)
    master:SetPoint("TOPLEFT", 15, y); y = y - 40

    local lock = mkCheck(c, "Lock Position", "Lock the frame position.", 
        function() return ns.DB.locked end, function(v) ns.DB.locked = v end)
    lock:SetPoint("TOPLEFT", 15, y); y = y - 40

    local reset = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
    reset:SetSize(160, 28); reset:SetPoint("TOPLEFT", 15, y); reset:SetText("Reset Profile")
    reset:SetScript("OnClick", function()
        if ns.Profiles and ns.Profiles.ResetCurrentProfile then
            ns.Profiles:ResetCurrentProfile()
            ReloadUI()
        end
    end); y = y - 40

    local scan = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
    scan:SetSize(160, 28); scan:SetPoint("TOPLEFT", 15, y); scan:SetText("Scan Spells")
    scan:SetScript("OnClick", function() ns.SpellBook:Scan(true) end); y = y - 40
    
    local test = mkCheck(c, "Test Mode", "Show fake frames for setup.", 
        function() return ns.DB.frame.fakeMode end, 
        function(v) if ns.Roster then ns.Roster:SetFakeMode(v, ns.DB.frame.fakeSize or 10) end end)
    test:SetPoint("TOPLEFT", 15, y); y = y - 40

    c.fakeSize = mkSlider(c, "Test Units", 5, 40, 1, 
        function() return ns.DB.frame.fakeSize or 10 end, 
        function(v) 
            ns.DB.frame.fakeSize = v
            if ns.DB.frame.fakeMode and ns.Roster then 
                ns.Roster:SetFakeMode(true, v) 
            end 
        end)
    c.fakeSize:SetPoint("TOPLEFT", 15, y); y = y - 55

    local th1 = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    th1:SetPoint("TOPLEFT", 15, y); th1:SetText("--- Health Thresholds ---"); y = y - 35

    c.critThresh = mkSlider(c, "Critical %", 10, 50, 5, function() return ns.DB.frame.criticalThreshold or 35 end, function(v) ns.DB.frame.criticalThreshold = v end)
    c.critThresh:SetPoint("TOPLEFT", 15, y); y = y - 55

    c.injThresh = mkSlider(c, "Injured %", 50, 90, 5, function() return ns.DB.frame.injuredThreshold or 70 end, function(v) ns.DB.frame.injuredThreshold = v end)
    c.injThresh:SetPoint("TOPLEFT", 15, y); y = y - 55

    c.outRange = mkSlider(c, "OOR Alpha", 0.1, 0.8, 0.05, function() return ns.DB.frame.outOfRangeAlpha or 0.35 end, function(v) ns.DB.frame.outOfRangeAlpha = v end)
    c.outRange:SetPoint("TOPLEFT", 15, y)

    c.loaded = true
end

function UI:LoadLayout(c)
    if c.loaded then 
        self:UpdateLayoutVisibility(c)
        return 
    end
    local y = 0
    
    local title = c:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 15, y); title:SetText("Layout Mode")
    y = y - 45

    local mode = mkCheck(c, "Grid Mode (Squares)", "Switch to square grid layout.", 
        function() return ns.DB.frame.layoutStyle == "grid" end, 
        function(v) ns.DB.frame.layoutStyle = v and "grid" or "bars"; self:UpdateLayoutVisibility(c) end)
    mode:SetPoint("TOPLEFT", 15, y); y = y - 40

    local split = mkCheck(c, "Split Group Anchors", "Allow moving each raid group independently.", 
        function() return ns.DB.frame.splitGroups end, function(v) ns.DB.frame.splitGroups = v; if ns.Frames then ns.Frames:ApplyLayout() end end)
    split:SetPoint("TOPLEFT", 15, y)
    c.splitCheck = split

    local resetPos = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
    resetPos:SetSize(160, 28); resetPos:SetPoint("LEFT", split, "RIGHT", 200, 0); resetPos:SetText("Reset Anchors")
    resetPos:SetScript("OnClick", function() if ns.Frames and ns.Frames.ResetAnchorPositions then ns.Frames:ResetAnchorPositions() end end)

    y = y - 50

    local barHeader = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    barHeader:SetPoint("TOPLEFT", 15, y); barHeader:SetText("--- Bar Mode Settings ---")
    c.barHeader = barHeader

    c.bScale = mkSlider(c, "Scale", 0.5, 2.0, 0.05, function() return ns.DB.frame.bars.scale or 1 end, function(v) ns.DB.frame.bars.scale = v end)
    c.bScale:SetPoint("TOPLEFT", 15, y - 40); c.bScale:SetWidth(180)

    c.bWidth = mkSlider(c, "Width", 40, 400, 2, function() return ns.DB.frame.bars.width or 180 end, function(v) ns.DB.frame.bars.width = v end)
    c.bWidth:SetPoint("TOPLEFT", 280, y - 40); c.bWidth:SetWidth(180); y = y - 85

    c.bHeight = mkSlider(c, "Height", 10, 120, 1, function() return ns.DB.frame.bars.height or 22 end, function(v) ns.DB.frame.bars.height = v end)
    c.bHeight:SetPoint("TOPLEFT", 15, y); c.bHeight:SetWidth(180)

    c.bSpacing = mkSlider(c, "Spacing", 0, 40, 1, function() return ns.DB.frame.bars.spacing or 4 end, function(v) ns.DB.frame.bars.spacing = v end)
    c.bSpacing:SetPoint("TOPLEFT", 280, y); c.bSpacing:SetWidth(180); y = y - 65

    c.bCols = mkSlider(c, "Groups/Row", 1, 8, 1, function() return ns.DB.frame.bars.groupsPerRow or 4 end, function(v) ns.DB.frame.bars.groupsPerRow = v end)
    c.bCols:SetPoint("TOPLEFT", 15, y); c.bCols:SetWidth(180)

    c.bGroupSp = mkSlider(c, "Group Gap", 5, 100, 1, function() return ns.DB.frame.bars.groupSpacing or 18 end, function(v) ns.DB.frame.bars.groupSpacing = v end)
    c.bGroupSp:SetPoint("TOPLEFT", 280, y); c.bGroupSp:SetWidth(180); y = y - 65

    local function updateBarUnitsVisibility()
        if not c.bUnits then return end
        local show = (ns.DB.frame.bars.horizontalFill ~= false)
        c.bUnits:SetShown(show)
    end

    c.bHorizontal = mkCheck(c, "Horizontal Fill (Bars)", "Fill each group left-to-right before moving down.",
        function() return ns.DB.frame.bars.horizontalFill ~= false end,
        function(v)
            ns.DB.frame.bars.horizontalFill = v
            updateBarUnitsVisibility()
            if ns.Frames then ns.Frames:ApplyLayout() end
        end)
    c.bHorizontal:SetPoint("TOPLEFT", 15, y)

    c.bUnits = mkSlider(c, "Units/Row", 1, 10, 1,
        function() return ns.DB.frame.bars.unitsPerRow or 1 end,
        function(v) ns.DB.frame.bars.unitsPerRow = v end)
    c.bUnits:SetPoint("TOPLEFT", 280, y - 5); c.bUnits:SetWidth(180); y = y - 70
    updateBarUnitsVisibility()

    local gridHeader = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    gridHeader:SetPoint("TOPLEFT", 15, y); gridHeader:SetText("--- Grid Mode Settings ---")
    c.gridHeader = gridHeader

    c.gScale = mkSlider(c, "Scale", 0.5, 2.0, 0.05, function() return ns.DB.frame.grid.scale or 1 end, function(v) ns.DB.frame.grid.scale = v end)
    c.gScale:SetPoint("TOPLEFT", 15, y - 40); c.gScale:SetWidth(180)

    c.gSize = mkSlider(c, "Size", 20, 200, 1, function() return ns.DB.frame.grid.size or 40 end, function(v) ns.DB.frame.grid.size = v end)
    c.gSize:SetPoint("TOPLEFT", 280, y - 40); c.gSize:SetWidth(180); y = y - 85

    c.gCols = mkSlider(c, "Units/Line", 1, 20, 1, function() return ns.DB.frame.grid.columns or 5 end, function(v) ns.DB.frame.grid.columns = v end)
    c.gCols:SetPoint("TOPLEFT", 15, y); c.gCols:SetWidth(180)

    c.gSpacing = mkSlider(c, "Spacing", 0, 40, 1, function() return ns.DB.frame.grid.spacing or 2 end, function(v) ns.DB.frame.grid.spacing = v end)
    c.gSpacing:SetPoint("TOPLEFT", 280, y); c.gSpacing:SetWidth(180); y = y - 65

    c.gHorizontal = mkCheck(c, "Horizontal Fill (Grid)", "Fill grid rows left-to-right before moving down.",
        function() return ns.DB.frame.grid.horizontalFill ~= false end,
        function(v)
            ns.DB.frame.grid.horizontalFill = v
            if ns.Frames then ns.Frames:ApplyLayout() end
        end)
    c.gHorizontal:SetPoint("TOPLEFT", 15, y); y = y - 40

    mode:HookScript("OnClick", function() self:UpdateLayoutVisibility(c) end)
    self:UpdateLayoutVisibility(c)
    c.loaded = true
end

function UI:UpdateLayoutVisibility(c)
    local isGrid = ns.DB.frame.layoutStyle == "grid"
    c.splitCheck:SetShown(not isGrid)
    c.barHeader:SetShown(not isGrid)
    c.bScale:SetShown(not isGrid); c.bWidth:SetShown(not isGrid); c.bHeight:SetShown(not isGrid)
    c.bSpacing:SetShown(not isGrid); c.bCols:SetShown(not isGrid); c.bGroupSp:SetShown(not isGrid)
    if c.bHorizontal then c.bHorizontal:SetShown(not isGrid) end
    if c.bUnits then
        local showUnits = (not isGrid) and (ns.DB.frame.bars.horizontalFill ~= false)
        c.bUnits:SetShown(showUnits)
    end
    c.gridHeader:SetShown(isGrid)
    c.gScale:SetShown(isGrid); c.gSize:SetShown(isGrid); c.gCols:SetShown(isGrid); c.gSpacing:SetShown(isGrid)
    if c.gHorizontal then c.gHorizontal:SetShown(isGrid) end
end

function UI:LoadStyle(c)
    if c.loaded then return end
    local y = 0
    
    local title = c:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 15, y); title:SetText("Visual Style")
    y = y - 45

    local th1 = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    th1:SetPoint("TOPLEFT", 15, y); th1:SetText("--- Health Colors ---"); y = y - 35

    mkColorButton(c, "Healthy", function() return ns.DB.frame.healthyColor or {0.15, 0.78, 0.22} end, function(v) ns.DB.frame.healthyColor = v end):SetPoint("TOPLEFT", 15, y)
    mkColorButton(c, "Injured", function() return ns.DB.frame.injuredColor or {0.95, 0.82, 0.20} end, function(v) ns.DB.frame.injuredColor = v end):SetPoint("TOPLEFT", 145, y)
    mkColorButton(c, "Critical", function() return ns.DB.frame.criticalColor or {0.95, 0.15, 0.15} end, function(v) ns.DB.frame.criticalColor = v end):SetPoint("TOPLEFT", 275, y); y = y - 40

    local th1b = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    th1b:SetPoint("TOPLEFT", 15, y); th1b:SetText("--- Dispel Colors ---"); y = y - 40

    mkColorButton(c, "Magic", function() return ns.DB.frame.dispelColors.Magic or {0.2, 0.6, 1} end, function(v) ns.DB.frame.dispelColors.Magic = v end):SetPoint("TOPLEFT", 15, y)
    mkColorButton(c, "Curse", function() return ns.DB.frame.dispelColors.Curse or {0.6, 0, 1} end, function(v) ns.DB.frame.dispelColors.Curse = v end):SetPoint("TOPLEFT", 145, y)
    mkColorButton(c, "Poison", function() return ns.DB.frame.dispelColors.Poison or {0, 0.6, 0} end, function(v) ns.DB.frame.dispelColors.Poison = v end):SetPoint("TOPLEFT", 275, y)
    mkColorButton(c, "Disease", function() return ns.DB.frame.dispelColors.Disease or {0.6, 0.4, 0} end, function(v) ns.DB.frame.dispelColors.Disease = v end):SetPoint("TOPLEFT", 405, y); y = y - 55

    local th2 = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    th2:SetPoint("TOPLEFT", 15, y); th2:SetText("--- Display Options ---"); y = y - 35

    mkCheck(c, "Highlight Debuffs", "Color bar for curable debuffs.", 
        function() return ns.DB.frame.highlightCurableDebuffs ~= false end, function(v) ns.DB.frame.highlightCurableDebuffs = v end):SetPoint("TOPLEFT", 15, y); y = y - 32

    mkCheck(c, "Show Mana Bar", "Display mana/power bar.", 
        function() return ns.DB.frame.showManaBar ~= false end, function(v) ns.DB.frame.showManaBar = v end):SetPoint("TOPLEFT", 15, y); y = y - 32

    mkCheck(c, "Health %", "Display health percentage.", 
        function() return ns.DB.frame.showHealthText ~= false end, function(v) ns.DB.frame.showHealthText = v end):SetPoint("TOPLEFT", 15, y); y = y - 32

    mkCheck(c, "Status Text", "Display DEAD/AFK/etc.", 
        function() return ns.DB.frame.showStatusText ~= false end, function(v) ns.DB.frame.showStatusText = v end):SetPoint("TOPLEFT", 15, y); y = y - 32

    mkCheck(c, "Class Colors", "Use class colors for names.", 
        function() return ns.DB.frame.classColorNames ~= false end, function(v) ns.DB.frame.classColorNames = v end):SetPoint("TOPLEFT", 15, y); y = y - 32

    mkCheck(c, "Heal Comm", "Show incoming heal predictions.", 
        function() return ns.DB.frame.showHealComm ~= false end, function(v) ns.DB.frame.showHealComm = v end):SetPoint("TOPLEFT", 15, y); y = y - 32

    mkCheck(c, "Use Class Colors", "Use class colors for the health bars.", 
        function() return ns.DB.frame.useClassColors end, function(v) ns.DB.frame.useClassColors = v end):SetPoint("TOPLEFT", 15, y); y = y - 32

    mkCheck(c, "Aggro Border", "Show red border when unit has aggro.", 
        function() return ns.DB.frame.showAggroBorder ~= false end, function(v) ns.DB.frame.showAggroBorder = v end):SetPoint("TOPLEFT", 15, y); y = y - 32

    mkCheck(c, "Target Glow", "Show white border on current target.", 
        function() return ns.DB.frame.showTargetGlow ~= false end, function(v) ns.DB.frame.showTargetGlow = v end):SetPoint("TOPLEFT", 15, y); y = y - 32

    mkCheck(c, "Raid Icons", "Display raid target markers on frames.",
        function() return ns.DB.frame.showRaidIcons ~= false end,
        function(v)
            ns.DB.frame.showRaidIcons = v
            if ns.Frames then ns.Frames:ApplyLayout() end
        end):SetPoint("TOPLEFT", 15, y); y = y - 32

    mkCheck(c, "Show Deficit", "Show -HP instead of % when injured.", 
        function() return ns.DB.frame.showDeficit ~= false end, function(v) ns.DB.frame.showDeficit = v end):SetPoint("TOPLEFT", 15, y); y = y - 32

    mkCheck(c, "Inverted (Deficit)", "Show health deficit instead of full bar.", 
        function() return ns.DB.frame.invertedColors end, function(v) ns.DB.frame.invertedColors = v end):SetPoint("TOPLEFT", 15, y); y = y - 32

    mkColorButton(c, "Hover Color", function() return ns.DB.frame.hoverColor or {1, 1, 1, 0.15} end, function(v) ns.DB.frame.hoverColor = v end):SetPoint("TOPLEFT", 15, y); y = y - 45

    local textures = {
        { name = "Classic", path = "Interface\\TargetingFrame\\UI-StatusBar" },
        { name = "Smooth", path = "Interface\\RaidFrame\\Shield-Fill" },
        { name = "Glossy", path = "Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar" },
        { name = "Minimalist", path = "Interface\\Buttons\\WHITE8X8" },
    }

    local texLabel = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    texLabel:SetPoint("TOPLEFT", 15, y - 5); texLabel:SetText("Texture:")
    
    for i, t in ipairs(textures) do
        local btn = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
        btn:SetSize(100, 24)
        btn:SetPoint("TOPLEFT", 90 + (i-1)*110, y)
        btn:SetText(t.name)
        btn:SetScript("OnClick", function()
            ns.DB.frame.barTexture = t.path
            if ns.Frames then ns.Frames:ApplyLayout() end
        end)
    end
    y = y - 45

    mkCheck(c, "Aura Timers", "Show cooldown timers on auras.", 
        function() return ns.DB.frame.showAuraTimers ~= false end, function(v) ns.DB.frame.showAuraTimers = v end):SetPoint("TOPLEFT", 15, y); y = y - 45

    local raidSizeSlider = mkSlider(c, "Raid Icon Size", 8, 32, 1,
        function() return ns.DB.frame.raidIconSize or 16 end,
        function(v)
            ns.DB.frame.raidIconSize = v
            if ns.Frames then ns.Frames:ApplyLayout() end
        end)
    raidSizeSlider:SetPoint("TOPLEFT", 280, y + 15)
    raidSizeSlider:SetWidth(180)

    y = y - 65

    local th3 = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    th3:SetPoint("TOPLEFT", 15, y); th3:SetText("--- Name Options ---"); y = y - 35

    mkCheck(c, "Shorten Names", "Truncate long names.", 
        function() return ns.DB.frame.bars.shortenNames end, function(v) ns.DB.frame.bars.shortenNames = v end):SetPoint("TOPLEFT", 15, y); y = y - 35
    mkCheck(c, "Shorten Grid Names", "Truncate long names in grid.", 
        function() return ns.DB.frame.grid.shortenNames end, function(v) ns.DB.frame.grid.shortenNames = v end):SetPoint("TOPLEFT", 15, y); y = y - 50

    c.nameFS = mkSlider(c, "Name Font Size", 6, 28, 1, function() return ns.DB.frame.nameFontSize or 10 end, function(v) ns.DB.frame.nameFontSize = v end)
    c.nameFS:SetPoint("TOPLEFT", 15, y); y = y - 55

    c.statusFS = mkSlider(c, "Status Font Size", 6, 28, 1, function() return ns.DB.frame.statusFontSize or 8 end, function(v) ns.DB.frame.statusFontSize = v end)
    c.statusFS:SetPoint("TOPLEFT", 15, y); y = y - 55

    c.manaH = mkSlider(c, "Mana Height", 0, 16, 1, function() return ns.DB.frame.manaBarHeight or 3 end, function(v) ns.DB.frame.manaBarHeight = v end)
    c.manaH:SetPoint("TOPLEFT", 15, y)

    c.loaded = true
end

local spellPickerFrame

local function CreateSpellPicker()
    if spellPickerFrame then return spellPickerFrame end
    
    local f = CreateFrame("Frame", "PB_SpellPicker", UIParent)
    f:SetSize(450, 500)
    f:SetPoint("CENTER")
    f:SetFrameStrata("TOOLTIP") -- Highest strata
    f:Hide()
    CreateFrameBackdrop(f)
    f:SetBackdropColor(0.05, 0.05, 0.05, 0.98)
    
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 20, -20)
    title:SetText("Select Spell")
    f.title = title
    
    local categories = { "All", "Healing", "Support", "Buffs", "Cleanse", "Res" }
    f.currentCategoryIdx = 1
    
    local catBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    catBtn:SetSize(140, 26)
    catBtn:SetPoint("TOPLEFT", 20, -50)
    catBtn:SetText("Filter: All")
    catBtn:SetScript("OnClick", function()
        f.currentCategoryIdx = (f.currentCategoryIdx % #categories) + 1
        local cat = categories[f.currentCategoryIdx]
        catBtn:SetText("Filter: " .. cat)
        f.currentCategory = cat
        f:UpdateSpellList(f.editbox:GetText():lower())
    end)
    f.currentCategory = "All"

    local filterLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    filterLabel:SetPoint("LEFT", catBtn, "RIGHT", 15, 0)
    filterLabel:SetText("Search:")
    
    local editbox = CreateFrame("EditBox", "PB_SpellPickerFilter", f, "InputBoxTemplate")
    editbox:SetSize(180, 22); editbox:SetPoint("LEFT", filterLabel, "RIGHT", 10, 0); editbox:SetAutoFocus(false)
    f.editbox = editbox
    
    local scroll = CreateFrame("ScrollFrame", "PB_SpellPickerScroll", f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 20, -90)
    scroll:SetPoint("BOTTOMRIGHT", -40, 50)
    
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(380, 1000)
    scroll:SetScrollChild(child)
    f.scrollChild = child
    
    editbox:SetScript("OnTextChanged", function(self)
        f:UpdateSpellList(self:GetText():lower())
    end)
    
    local closeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    closeBtn:SetSize(80, 24); closeBtn:SetPoint("BOTTOMRIGHT", -20, -15); closeBtn:SetText("Close")
    closeBtn:SetScript("OnClick", function() f:Hide() end)
    
    local targetBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    targetBtn:SetSize(80, 24); targetBtn:SetPoint("RIGHT", closeBtn, "LEFT", -10, 0); targetBtn:SetText("Target")
    targetBtn:SetScript("OnClick", function()
        ns.Bindings:SetTarget(f.currentSlot)
        if ns.UI_Main then ns.UI_Main:RefreshKeybinds() end
        f:Hide()
    end)
    
    local menuBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    menuBtn:SetSize(70, 24); menuBtn:SetPoint("RIGHT", targetBtn, "LEFT", -10, 0); menuBtn:SetText("Menu")
    menuBtn:SetScript("OnClick", function()
        ns.Bindings:SetMenu(f.currentSlot)
        if ns.UI_Main then ns.UI_Main:RefreshKeybinds() end
        f:Hide()
    end)
    
    f.buttons = {}
    
    f.Open = function(self, slot, parent)
        self.currentSlot = slot
        self:ClearAllPoints()
        self:SetPoint("CENTER")
        self.title:SetText("Assign: " .. slot)
        self:Show()
        self.editbox:SetText("")
        self:UpdateSpellList("")
    end
    
    f.UpdateSpellList = function(self, filter)
        local bindable = (ns.SpellBook and ns.SpellBook.GetBindable and ns.SpellBook:GetBindable()) or {}
        local intel = ns.HealingIntel or {}
        local count, y, cat = 0, 0, self.currentCategory
        
        for _, btn in ipairs(self.buttons) do btn:Hide() end
        
        for _, spell in ipairs(bindable) do
            local name = spell.name:lower()
            local inCat = (cat == "All")
            if not inCat then
                local role = spell.role
                if cat == "Healing" and (role == "heal" or role == "hot" or role == "shield_absorb") then inCat = true
                elseif cat == "Support" and role == "support" then inCat = true
                elseif cat == "Buffs" and role == "buff" then inCat = true
                elseif cat == "Cleanse" and role == "cleanse" then inCat = true
                elseif cat == "Res" and role == "resurrection" then inCat = true
                end
            end

            if inCat and (filter == "" or name:find(filter, 1, true)) then
                count = count + 1
                local btn = self.buttons[count]
                if not btn then
                    btn = CreateFrame("Button", nil, self.scrollChild)
                    btn:SetSize(370, 30)
                    
                    local bg = btn:CreateTexture(nil, "BACKGROUND")
                    bg:SetAllPoints(); bg:SetTexture(0, 0, 0, 0.5)
                    btn.bg = bg
                    
                    local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
                    highlight:SetAllPoints(); highlight:SetTexture(1, 1, 1, 0.1)
                    
                    local icon = btn:CreateTexture(nil, "OVERLAY")
                    icon:SetSize(24, 24); icon:SetPoint("LEFT", 5, 0)
                    btn.icon = icon
                    
                    local text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                    text:SetPoint("LEFT", icon, "RIGHT", 10, 0)
                    text:SetJustifyH("LEFT")
                    btn:SetFontString(text)
                    
                    btn:SetScript("OnClick", function()
                        local s = btn.spellData
                        if s then
                            ns.Bindings:SetSpell(self.currentSlot, s.name)
                            if ns.UI_Main then ns.UI_Main:RefreshKeybinds() end
                            self:Hide()
                        end
                    end)
                    
                    btn:SetScript("OnEnter", function(selfRow)
                        local s = selfRow.spellData
                        if not s then return end
                        GameTooltip:SetOwner(selfRow, "ANCHOR_RIGHT")
                        if GameTooltip.SetSpellBookItem then
                            GameTooltip:SetSpellBookItem(s.slot, "spell")
                        elseif s.link then
                            GameTooltip:SetHyperlink(s.link)
                        end
                        GameTooltip:Show()
                    end)
                    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
                    
                    self.buttons[count] = btn
                end
                btn.spellData = spell
                btn:SetPoint("TOPLEFT", 5, -y)
                btn:SetText(spell.name)
                btn.icon:SetTexture(spell.texture)
                btn:Show()
                y = y + 32
            end
        end
        self.scrollChild:SetHeight(math.max(y, 100))
    end
    
    spellPickerFrame = f
    return f
end

local bindCaptureFrame

local function CreateBindCapture()
    if bindCaptureFrame then return bindCaptureFrame end
    
    local f = CreateFrame("Frame", "PB_BindCapture", UIParent)
    f:SetSize(300, 80)
    f:SetFrameStrata("TOOLTIP")
    f:Hide()
    CreateFrameBackdrop(f)
    f:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
    
    local txt = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    txt:SetPoint("TOP", 0, -15); txt:SetText("Waiting for input...")
    f.txt = txt

    local help = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    help:SetPoint("TOP", txt, "BOTTOM", 0, -5); help:SetText("Press Mouse, Wheel, or Key")
    
    local cancel = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    cancel:SetSize(80, 20); cancel:SetPoint("BOTTOM", 0, 10); cancel:SetText("Cancel")
    cancel:SetScript("OnClick", function() f:Hide() end)
    
    local blocker = CreateFrame("Frame", nil, f)
    blocker:SetAllPoints(UIParent)
    blocker:SetFrameStrata("TOOLTIP")
    blocker:SetFrameLevel(f:GetFrameLevel() + 10) -- Ensure blocker is on TOP of everything
    blocker:EnableMouse(true)
    blocker:EnableMouseWheel(true)
    blocker:EnableKeyboard(true)
    
    local function finish(slot)
        f:Hide()
        blocker:Hide()
        if f.callback then f.callback(slot) end
    end

    blocker:SetScript("OnMouseDown", function(_, button)
        local mods = ""
        if IsShiftKeyDown() then mods = mods .. "Shift-" end
        if IsControlKeyDown() then mods = mods .. "Ctrl-" end
        if IsAltKeyDown() then mods = mods .. "Alt-" end
        finish(mods .. button)
    end)

    blocker:SetScript("OnMouseWheel", function(_, delta)
        local mods = ""
        if IsShiftKeyDown() then mods = mods .. "Shift-" end
        if IsControlKeyDown() then mods = mods .. "Ctrl-" end
        if IsAltKeyDown() then mods = mods .. "Alt-" end
        finish(mods .. ((delta > 0) and "MouseWheelUp" or "MouseWheelDown"))
    end)

    blocker:SetScript("OnKeyDown", function(_, key)
        if key == "ESCAPE" then f:Hide(); blocker:Hide(); return end
        if key:find("SHIFT") or key:find("CTRL") or key:find("ALT") then return end
        local mods = ""
        if IsShiftKeyDown() then mods = mods .. "Shift-" end
        if IsControlKeyDown() then mods = mods .. "Ctrl-" end
        if IsAltKeyDown() then mods = mods .. "Alt-" end
        finish(mods .. key)
    end)
    
    f:SetScript("OnShow", function() blocker:Show() end)
    f:SetScript("OnHide", function() blocker:Hide() end)
    
    bindCaptureFrame = f
    return f
end

function UI:LoadKeybinds(c)
    if c.loaded then self:RefreshKeybinds(); return end
    local y = 0
    
    local title = c:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 15, y); title:SetText("Keybinds")
    
    local captureAnchor = CreateFrame("Frame", nil, c)
    captureAnchor:SetSize(350, 60); captureAnchor:SetPoint("TOPLEFT", 15, y - 30)
    c.captureAnchor = captureAnchor

    y = y - 90 -- Push buttons down further to make room for capture UI

    local tip = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tip:SetPoint("TOPLEFT", 15, y); tip:SetText("Click + to assign a spell, X to clear, or use Auto Bind")
    tip:SetTextColor(0.7, 0.7, 0.7); y = y - 40

    local smart = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
    smart:SetSize(160, 28); smart:SetPoint("TOPLEFT", 15, y); smart:SetText("Auto Bind")
    smart:SetScript("OnClick", function() ns.Bindings:SmartBind(); self:RefreshKeybinds() end)

    local addBind = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
    addBind:SetSize(160, 28); addBind:SetPoint("LEFT", smart, "RIGHT", 15, 0); addBind:SetText("Add Binding")
    addBind:SetScript("OnClick", function()
        local capture = CreateBindCapture()
        capture:ClearAllPoints(); capture:SetPoint("CENTER", captureAnchor, "CENTER", 0, 0)
        capture.callback = function(slot)
            if not spellPickerFrame then CreateSpellPicker() end
            spellPickerFrame:Open(slot, addBind)
        end
        capture:Show()
    end)

    local clearAll = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
    clearAll:SetSize(140, 28); clearAll:SetPoint("LEFT", addBind, "RIGHT", 15, 0); clearAll:SetText("Clear All")
    clearAll:SetScript("OnClick", function() 
        for _, slot in ipairs(ns.Bindings:GetOrderedSlots()) do ns.Bindings:Clear(slot) end
        self:RefreshKeybinds() 
    end); y = y - 55

    c.keyHeader = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    c.keyHeader:SetPoint("TOPLEFT", 15, y); c.keyHeader:SetText("--- Bindings ---")
    c.keyRows = {}
    c.keyY = y - 35
    self:RefreshKeybinds()
    c.loaded = true
end

function UI:RefreshKeybinds()
    local data = tabContent["Keybinds"]
    if not data or not data.child then return end
    local content = data.child
    local y = content.keyY or -140
    
    if not spellPickerFrame then CreateSpellPicker() end
    
    local slots = ns.Bindings:GetOrderedSlots()
    if not content.keyRows then content.keyRows = {} end

    for _, row in ipairs(content.keyRows) do row:Hide() end

    for i, slot in ipairs(slots) do
        local row = content.keyRows[i]
        if not row then
            row = CreateFrame("Frame", nil, content)
            row:SetSize(550, 32); row:SetPoint("TOPLEFT", 15, y - (i-1) * 34)
            
            local rowBg = row:CreateTexture(nil, "BACKGROUND")
            rowBg:SetAllPoints(); rowBg:SetTexture(0, 0, 0, 0.3)
            
            row.txt = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.txt:SetPoint("LEFT", 10, 0)
            
            row.spell = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row.spell:SetPoint("LEFT", 160, 0); row.spell:SetWidth(300)
            
            local plus = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            plus:SetSize(32, 24); plus:SetPoint("RIGHT", -5, 0); plus:SetText("+")
            row.plus = plus
            
            local clr = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            clr:SetSize(32, 24); clr:SetPoint("RIGHT", plus, "LEFT", -5, 0); clr:SetText("X")
            row.clr = clr
            
            content.keyRows[i] = row
        end
        
        row.txt:SetText(slot)
        local rec = ns.Bindings:Get(slot)
        local text = rec.value or ""
        if text == "" then text = "|cff888888-- " .. rec.type .. " --|r" end
        row.spell:SetText(text)
        
        row.plus:SetScript("OnClick", function()
            spellPickerFrame:Open(slot, row)
        end)
        
        row.clr:SetScript("OnClick", function()
            ns.Bindings:Clear(slot)
            self:RefreshKeybinds()
        end)

        row:Show()
    end
end

function UI:LoadProfiles(c)
    if c.loaded then self:RefreshProfiles(c); return end
    local y = 0
    
    local title = c:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 15, y); title:SetText("Profile Management")
    y = y - 45

    local curLabel = c:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    curLabel:SetPoint("TOPLEFT", 15, y); curLabel:SetText("Current Profile:")
    c.activeProfileText = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    c.activeProfileText:SetPoint("LEFT", curLabel, "RIGHT", 10, 0)
    y = y - 40

    local newLabel = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    newLabel:SetPoint("TOPLEFT", 15, y); newLabel:SetText("Create New Profile:")
    
    local eb = CreateFrame("EditBox", "PB_HF_NewProfileEdit", c, "InputBoxTemplate")
    eb:SetSize(200, 24); eb:SetPoint("LEFT", newLabel, "RIGHT", 10, 0); eb:SetAutoFocus(false)
    
    local createBtn = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
    createBtn:SetSize(80, 24); createBtn:SetPoint("LEFT", eb, "RIGHT", 10, 0); createBtn:SetText("Create")
    createBtn:SetScript("OnClick", function()
        local name = eb:GetText()
        if name and name ~= "" then
            ns.Profiles:CreateProfile(name)
            eb:SetText("")
            self:RefreshProfiles(c)
        end
    end)
    y = y - 50

    local listHeader = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    listHeader:SetPoint("TOPLEFT", 15, y); listHeader:SetText("Available Profiles")
    y = y - 30
    
    c.profileRows = {}
    c.profileY = y
    
    self:RefreshProfiles(c)
    c.loaded = true
end

function UI:RefreshProfiles(c)
    if not c then 
        local data = tabContent["Profiles"]
        if not data then return end
        c = data.child
    end
    
    c.activeProfileText:SetText(ns.Profiles:GetProfileName())
    local profiles = ns.Profiles:GetProfiles()
    local y = c.profileY
    
    for _, row in ipairs(c.profileRows or {}) do row:Hide() end
    c.profileRows = c.profileRows or {}
    
    for i, name in ipairs(profiles) do
        local row = c.profileRows[i]
        if not row then
            row = CreateFrame("Frame", nil, c)
            row:SetSize(500, 30); row:SetPoint("TOPLEFT", 15, y - (i-1) * 32)
            row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            row.name:SetPoint("LEFT", 5, 0)
            local setBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            setBtn:SetSize(80, 22); setBtn:SetPoint("RIGHT", -180, 0); setBtn:SetText("Select")
            row.setBtn = setBtn
            local copyBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            copyBtn:SetSize(80, 22); copyBtn:SetPoint("LEFT", setBtn, "RIGHT", 5, 0); copyBtn:SetText("Copy From")
            row.copyBtn = copyBtn
            local delBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            delBtn:SetSize(80, 22); delBtn:SetPoint("LEFT", copyBtn, "RIGHT", 5, 0); delBtn:SetText("Delete")
            row.delBtn = delBtn
            c.profileRows[i] = row
        end
        row.name:SetText(name)
        row.setBtn:SetScript("OnClick", function()
            ns.Profiles:SetProfile(name)
            self:RefreshProfiles(c)
            for tName, data in pairs(tabContent) do
                if data.child.loaded and tName ~= "Profiles" then data.child.loaded = false end
            end
        end)
        row.copyBtn:SetScript("OnClick", function()
            StaticPopupDialogs["PB_HF_COPY_PROFILE"] = {
                text = "Copy settings from '"..name.."' to current profile?",
                button1 = "Yes", button2 = "No",
                OnAccept = function()
                    PB_HF_DB.profiles[ns.Profiles:GetProfileName()] = ns.Profiles:DeepCopy(PB_HF_DB.profiles[name])
                    ns.Profiles:SetProfile(ns.Profiles:GetProfileName())
                end,
                timeout = 0, whileDead = true, hideOnEscape = true,
            }
            StaticPopup_Show("PB_HF_COPY_PROFILE")
        end)
        row.delBtn:SetScript("OnClick", function()
            if name == "Default" or name == ns.Profiles:GetProfileName() then return end
            ns.Profiles:DeleteProfile(name); self:RefreshProfiles(c)
        end)
        if name == "Default" or name == ns.Profiles:GetProfileName() then row.delBtn:Disable() else row.delBtn:Enable() end
        if name == ns.Profiles:GetProfileName() then row.name:SetTextColor(1, 0.8, 0); row.setBtn:Disable() else row.name:SetTextColor(1, 1, 1); row.setBtn:Enable() end
        row:Show()
    end
end

function UI:Toggle()
    if not frame then self:CreateMainWindow() end
    if frame:IsShown() then frame:Hide() else frame:Show(); self:ShowTab(activeTab) end
end

function UI:OnInitialize()
end
