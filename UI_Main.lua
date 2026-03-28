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
    s:SetWidth(150); s:SetMinMaxValues(minv, maxv); s:SetValueStep(step)
    if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
    
    local name = s:GetName()
    _G[name .. "Low"]:SetText(tostring(minv))
    _G[name .. "High"]:SetText(tostring(maxv))

    local text = s:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    text:SetPoint("BOTTOM", s, "TOP", 0, 2)
    s.text = text

    s:SetScript("OnValueChanged", function(self, value)
        value = math.floor((value / step) + 0.5) * step
        setter(value)
        self.text:SetText(label .. ": " .. tostring(value))
        if ns.Frames and ns.Frames.ApplyLayout then ns.Frames:ApplyLayout() end
    end)
    
    s:SetValue(getter())
    s.text:SetText(label .. ": " .. tostring(getter()))
    return s
end

local function openColorPicker(current, callback)
    local r, g, bl = current[1], current[2], current[3]
    ColorPickerFrame.func = function()
        local nr, ng, nb = ColorPickerFrame:GetColorRGB()
        callback({nr, ng, nb})
    end
    ColorPickerFrame.cancelFunc = function(prev)
        callback({prev.r, prev.g, prev.b})
    end
    ColorPickerFrame.hasOpacity = false
    ColorPickerFrame.previousValues = { r = r, g = g, b = bl }
    ColorPickerFrame:SetColorRGB(r, g, bl)
    ColorPickerFrame:Hide(); ColorPickerFrame:Show()
end

local function mkColorButton(parent, label, getter, setter)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(90, 24); btn:SetText(label)
    btn.swatch = btn:CreateTexture(nil, "OVERLAY")
    btn.swatch:SetSize(16, 16); btn.swatch:SetPoint("LEFT", btn, "RIGHT", 5, 0)
    
    local function updateSwatch()
        local c = getter()
        btn.swatch:SetTexture(c[1], c[2], c[3], 1)
    end
    
    btn:SetScript("OnClick", function()
        openColorPicker(getter(), function(c) 
            setter(c)
            updateSwatch()
            if ns.Frames and ns.Frames.ApplyLayout then ns.Frames.ApplyLayout() end
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
    frame:SetSize(580, 420)
    frame:SetPoint("CENTER")
    frame:SetMovable(true); frame:EnableMouse(true); frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetFrameStrata("DIALOG")
    CreateFrameBackdrop(frame)
    frame:Hide()

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 12, -12)
    title:SetText("PB: Healing Frames V 1.0 beta")

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)

    local sidebar = CreateFrame("Frame", nil, frame)
    sidebar:SetSize(120, 380); sidebar:SetPoint("TOPLEFT", 10, -40)
    CreateFrameBackdrop(sidebar); sidebar:SetBackdropColor(0.1, 0.1, 0.1, 0.5)

    local content = CreateFrame("Frame", nil, frame)
    content:SetSize(430, 380); content:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 10, 0)
    CreateFrameBackdrop(content); content:SetBackdropColor(0.1, 0.1, 0.1, 0.5)
    self.contentArea = content

    local tabList = { "General", "Layout", "Style", "Keybinds" }
    for i, name in ipairs(tabList) do
        local btn = CreateFrame("Button", nil, sidebar, "UIPanelButtonTemplate")
        btn:SetSize(100, 28); btn:SetPoint("TOP", 0, -10 - (i-1) * 32)
        btn:SetText(name)
        btn:SetScript("OnClick", function() self:ShowTab(name) end)
        tabs[name] = btn
        
        local scroll = CreateFrame("ScrollFrame", "PB_HF_TabScroll"..name, content, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 5, -5)
        scroll:SetPoint("BOTTOMRIGHT", -25, 5)
        scroll:Hide()
        
        local child = CreateFrame("Frame", nil, scroll)
        child:SetSize(400, 800)
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
            elseif name == "Keybinds" then self:LoadKeybinds(data.child) end
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
    y = y - 30

    local master = mkCheck(c, "Enable PB: Healing Frames", "Toggle the entire addon on or off.", 
        function() return ns.DB.enabled ~= false end, function(v) ns:SetEnabled(v) end)
    master:SetPoint("TOPLEFT", 15, y); y = y - 30

    local lock = mkCheck(c, "Lock Position", "Lock the frame position.", 
        function() return ns.DB.locked end, function(v) ns.DB.locked = v end)
    lock:SetPoint("TOPLEFT", 15, y); y = y - 30

    local reset = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
    reset:SetSize(120, 24); reset:SetPoint("TOPLEFT", 15, y); reset:SetText("Reset Profile")
    reset:SetScript("OnClick", function()
        if ns.Profiles and ns.Profiles.ResetCurrentProfile then
            ns.Profiles:ResetCurrentProfile()
            ReloadUI()
        end
    end); y = y - 30

    local scan = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
    scan:SetSize(120, 24); scan:SetPoint("TOPLEFT", 15, y); scan:SetText("Scan Spells")
    scan:SetScript("OnClick", function() ns.SpellBook:Scan() end); y = y - 30
    
    local test = mkCheck(c, "Test Mode", "Show fake frames for setup.", 
        function() return ns.DB.frame.fakeMode end, 
        function(v) if ns.Roster then ns.Roster:SetFakeMode(v, ns.DB.frame.fakeSize or 10) end end)
    test:SetPoint("TOPLEFT", 15, y); y = y - 30

    c.fakeSize = mkSlider(c, "Test Units", 5, 40, 1, function() return ns.DB.frame.fakeSize or 10 end, function(v) ns.DB.frame.fakeSize = v; if ns.Roster then ns.Roster:SetFakeMode(true, v) end end)
    c.fakeSize:SetPoint("TOPLEFT", 15, y); y = y - 40

    local th1 = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    th1:SetPoint("TOPLEFT", 15, y); th1:SetText("--- Health Thresholds ---"); y = y - 25

    c.critThresh = mkSlider(c, "Critical %", 10, 50, 5, function() return ns.DB.frame.criticalThreshold or 35 end, function(v) ns.DB.frame.criticalThreshold = v end)
    c.critThresh:SetPoint("TOPLEFT", 15, y); y = y - 40

    c.injThresh = mkSlider(c, "Injured %", 50, 90, 5, function() return ns.DB.frame.injuredThreshold or 70 end, function(v) ns.DB.frame.injuredThreshold = v end)
    c.injThresh:SetPoint("TOPLEFT", 15, y); y = y - 40

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
    y = y - 30

    local mode = mkCheck(c, "Grid Mode (Squares)", "Switch to square grid layout.", 
        function() return ns.DB.frame.layoutStyle == "grid" end, 
        function(v) ns.DB.frame.layoutStyle = v and "grid" or "bars"; self:UpdateLayoutVisibility(c) end)
    mode:SetPoint("TOPLEFT", 15, y); y = y - 35

    local barHeader = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    barHeader:SetPoint("TOPLEFT", 15, y); barHeader:SetText("--- Bar Mode Settings ---")
    c.barHeader = barHeader

    c.bScale = mkSlider(c, "Scale", 0.5, 2.0, 0.05, function() return ns.DB.frame.bars.scale or 1 end, function(v) ns.DB.frame.bars.scale = v end)
    c.bScale:SetPoint("TOPLEFT", 15, y - 25); c.bScale:SetWidth(120)

    c.bWidth = mkSlider(c, "Width", 40, 300, 2, function() return ns.DB.frame.bars.width or 180 end, function(v) ns.DB.frame.bars.width = v end)
    c.bWidth:SetPoint("TOPLEFT", 200, y - 25); c.bWidth:SetWidth(120); y = y - 55

    c.bHeight = mkSlider(c, "Height", 10, 80, 1, function() return ns.DB.frame.bars.height or 22 end, function(v) ns.DB.frame.bars.height = v end)
    c.bHeight:SetPoint("TOPLEFT", 15, y); c.bHeight:SetWidth(120)

    c.bSpacing = mkSlider(c, "Spacing", 0, 20, 1, function() return ns.DB.frame.bars.spacing or 4 end, function(v) ns.DB.frame.bars.spacing = v end)
    c.bSpacing:SetPoint("TOPLEFT", 200, y); c.bSpacing:SetWidth(120); y = y - 40

    c.bCols = mkSlider(c, "Groups/Row", 1, 8, 1, function() return ns.DB.frame.bars.groupsPerRow or 2 end, function(v) ns.DB.frame.bars.groupsPerRow = v end)
    c.bCols:SetPoint("TOPLEFT", 15, y); c.bCols:SetWidth(120)

    c.bGroupSp = mkSlider(c, "Group Gap", 5, 40, 1, function() return ns.DB.frame.bars.groupSpacing or 18 end, function(v) ns.DB.frame.bars.groupSpacing = v end)
    c.bGroupSp:SetPoint("TOPLEFT", 200, y); c.bGroupSp:SetWidth(120); y = y - 40

    local gridHeader = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    gridHeader:SetPoint("TOPLEFT", 15, y); gridHeader:SetText("--- Grid Mode Settings ---")
    c.gridHeader = gridHeader

    c.gScale = mkSlider(c, "Scale", 0.5, 2.0, 0.05, function() return ns.DB.frame.grid.scale or 1 end, function(v) ns.DB.frame.grid.scale = v end)
    c.gScale:SetPoint("TOPLEFT", 15, y - 25); c.gScale:SetWidth(120)

    c.gSize = mkSlider(c, "Size", 20, 100, 1, function() return ns.DB.frame.grid.size or 40 end, function(v) ns.DB.frame.grid.size = v end)
    c.gSize:SetPoint("TOPLEFT", 200, y - 25); c.gSize:SetWidth(120); y = y - 55

    c.gCols = mkSlider(c, "Columns", 1, 10, 1, function() return ns.DB.frame.grid.columns or 5 end, function(v) ns.DB.frame.grid.columns = v end)
    c.gCols:SetPoint("TOPLEFT", 15, y); c.gCols:SetWidth(120)

    c.gSpacing = mkSlider(c, "Spacing", 0, 20, 1, function() return ns.DB.frame.grid.spacing or 2 end, function(v) ns.DB.frame.grid.spacing = v end)
    c.gSpacing:SetPoint("TOPLEFT", 200, y)

    mode:HookScript("OnClick", function() self:UpdateLayoutVisibility(c) end)
    self:UpdateLayoutVisibility(c)
    c.loaded = true
end

function UI:UpdateLayoutVisibility(c)
    local isGrid = ns.DB.frame.layoutStyle == "grid"
    c.barHeader:SetShown(not isGrid)
    c.bScale:SetShown(not isGrid); c.bWidth:SetShown(not isGrid); c.bHeight:SetShown(not isGrid)
    c.bSpacing:SetShown(not isGrid); c.bCols:SetShown(not isGrid); c.bGroupSp:SetShown(not isGrid)
    c.gridHeader:SetShown(isGrid)
    c.gScale:SetShown(isGrid); c.gSize:SetShown(isGrid); c.gCols:SetShown(isGrid); c.gSpacing:SetShown(isGrid)
end

function UI:LoadStyle(c)
    if c.loaded then return end
    local y = 0
    
    local title = c:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 15, y); title:SetText("Visual Style")
    y = y - 30

    local th1 = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    th1:SetPoint("TOPLEFT", 15, y); th1:SetText("--- Health Colors ---"); y = y - 25

    mkColorButton(c, "Healthy", function() return ns.DB.frame.healthyColor or {0.15, 0.78, 0.22} end, function(v) ns.DB.frame.healthyColor = v end):SetPoint("TOPLEFT", 15, y)
    mkColorButton(c, "Injured", function() return ns.DB.frame.injuredColor or {0.95, 0.82, 0.20} end, function(v) ns.DB.frame.injuredColor = v end):SetPoint("TOPLEFT", 115, y)
    mkColorButton(c, "Critical", function() return ns.DB.frame.criticalColor or {0.95, 0.15, 0.15} end, function(v) ns.DB.frame.criticalColor = v end):SetPoint("TOPLEFT", 215, y); y = y - 35

    local th2 = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    th2:SetPoint("TOPLEFT", 15, y); th2:SetText("--- Display Options ---"); y = y - 25

    mkCheck(c, "Highlight Debuffs", "Color bar for curable debuffs.", 
        function() return ns.DB.frame.highlightCurableDebuffs ~= false end, function(v) ns.DB.frame.highlightCurableDebuffs = v end):SetPoint("TOPLEFT", 15, y); y = y - 28

    mkCheck(c, "Show Mana Bar", "Display mana/power bar.", 
        function() return ns.DB.frame.showManaBar ~= false end, function(v) ns.DB.frame.showManaBar = v end):SetPoint("TOPLEFT", 15, y); y = y - 28

    mkCheck(c, "Health %", "Display health percentage.", 
        function() return ns.DB.frame.showHealthText ~= false end, function(v) ns.DB.frame.showHealthText = v end):SetPoint("TOPLEFT", 15, y); y = y - 28

    mkCheck(c, "Status Text", "Display DEAD/AFK/etc.", 
        function() return ns.DB.frame.showStatusText ~= false end, function(v) ns.DB.frame.showStatusText = v end):SetPoint("TOPLEFT", 15, y); y = y - 28

    mkCheck(c, "Class Colors", "Use class colors for names.", 
        function() return ns.DB.frame.classColorNames ~= false end, function(v) ns.DB.frame.classColorNames = v end):SetPoint("TOPLEFT", 15, y); y = y - 28

    mkCheck(c, "Heal Comm", "Show incoming heal predictions.", 
        function() return ns.DB.frame.showHealComm ~= false end, function(v) ns.DB.frame.showHealComm = v end):SetPoint("TOPLEFT", 15, y); y = y - 28

    mkCheck(c, "Aura Timers", "Show cooldown timers on auras.", 
        function() return ns.DB.frame.showAuraTimers ~= false end, function(v) ns.DB.frame.showAuraTimers = v end):SetPoint("TOPLEFT", 15, y); y = y - 35

    local th3 = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    th3:SetPoint("TOPLEFT", 15, y); th3:SetText("--- Name Options ---"); y = y - 25

    mkCheck(c, "Shorten Names", "Truncate long names.", 
        function() return ns.DB.frame.bars.shortenNames end, function(v) ns.DB.frame.bars.shortenNames = v end):SetPoint("TOPLEFT", 15, y); y = y - 28
    mkCheck(c, "Shorten Grid Names", "Truncate long names in grid.", 
        function() return ns.DB.frame.grid.shortenNames end, function(v) ns.DB.frame.grid.shortenNames = v end):SetPoint("TOPLEFT", 15, y); y = y - 35

    c.manaH = mkSlider(c, "Mana Height", 0, 8, 1, function() return ns.DB.frame.manaBarHeight or 3 end, function(v) ns.DB.frame.manaBarHeight = v end)
    c.manaH:SetPoint("TOPLEFT", 15, y)

    c.loaded = true
end

local spellPickerFrame

local function CreateSpellPicker()
    if spellPickerFrame then return spellPickerFrame end
    
    local f = CreateFrame("Frame", "PB_SpellPicker", UIParent)
    f:SetSize(250, 300)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:Hide()
    f:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    f:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
    
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 10, -10)
    title:SetText("Select Spell")
    f.title = title
    
    local filterLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    filterLabel:SetPoint("TOPLEFT", 10, -30)
    filterLabel:SetText("Filter:")
    
    local editbox = CreateFrame("EditBox", nil, f)
    editbox:SetSize(180, 20)
    editbox:SetPoint("LEFT", filterLabel, "RIGHT", 5, 0)
    editbox:SetFontObject("ChatFontNormal")
    editbox:SetText("")
    editbox:SetAutoFocus(false)
    f.editbox = editbox
    
    local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 10, -60)
    scroll:SetPoint("BOTTOMRIGHT", -10, 40)
    
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(210, 1000)
    scroll:SetScrollChild(child)
    f.scrollChild = child
    f.scroll = scroll
    
    editbox:SetScript("OnTextChanged", function(self)
        local txt = self:GetText():lower()
        f:UpdateSpellList(txt)
    end)
    
    local closeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    closeBtn:SetSize(60, 20)
    closeBtn:SetPoint("BOTTOMRIGHT", -10, -5)
    closeBtn:SetText("Close")
    closeBtn:SetScript("OnClick", function() f:Hide() end)
    
    local targetBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    targetBtn:SetSize(60, 20)
    targetBtn:SetPoint("RIGHT", closeBtn, "LEFT", -5, 0)
    targetBtn:SetText("Target")
    targetBtn:SetScript("OnClick", function()
        ns.Bindings:SetTarget(f.currentSlot)
        if ns.UI_Main then ns.UI_Main:RefreshKeybinds() end
        f:Hide()
    end)
    f.targetBtn = targetBtn
    
    local menuBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    menuBtn:SetSize(50, 20)
    menuBtn:SetPoint("RIGHT", targetBtn, "LEFT", -5, 0)
    menuBtn:SetText("Menu")
    menuBtn:SetScript("OnClick", function()
        ns.Bindings:SetMenu(f.currentSlot)
        if ns.UI_Main then ns.UI_Main:RefreshKeybinds() end
        f:Hide()
    end)
    f.menuBtn = menuBtn
    
    spellPickerFrame = f
    f.buttons = {}
    
    f.Open = function(self, slot, parent)
        self.currentSlot = slot
        self:ClearAllPoints()
        self:SetPoint("LEFT", parent, "RIGHT", 10, 0)
        self.title:SetText("Assign: " .. slot)
        self:Show()
        self.editbox:SetText("")
        self:UpdateSpellList("")
    end
    
    f.UpdateSpellList = function(self, filter)
        local child = self.scrollChild
        local bindable = (ns.SpellBook and ns.SpellBook.GetBindable and ns.SpellBook:GetBindable()) or {}
        
        for _, btn in ipairs(self.buttons) do btn:Hide() end
        
        local count = 0
        local y = 0
        
        for i, spell in ipairs(bindable) do
            local name = spell.name:lower()
            if filter == "" or name:find(filter, 1, true) then
                count = count + 1
                local btn = self.buttons[count]
                if not btn then
                    btn = CreateFrame("Button", nil, child, "UIPanelButtonTemplate")
                    btn:SetSize(200, 22)
                    btn:SetText("")
                    
                    local icon = btn:CreateTexture(nil, "OVERLAY")
                    icon:SetSize(18, 18)
                    icon:SetPoint("LEFT", 2, 0)
                    btn.icon = icon
                    
                    local t = btn:GetFontString()
                    t:ClearAllPoints()
                    t:SetPoint("LEFT", icon, "RIGHT", 5, 0)
                    t:SetJustifyH("LEFT")
                    
                    btn:SetScript("OnClick", function()
                        ns.Bindings:SetSpell(self.currentSlot, spell.name)
                        if ns.UI_Main then ns.UI_Main:RefreshKeybinds() end
                        self:Hide()
                    end)
                    self.buttons[count] = btn
                end
                btn:SetPoint("TOPLEFT", 5, -y)
                btn:SetText(spell.name)
                btn.icon:SetTexture(spell.texture)
                btn:Show()
                y = y + 24
            end
        end
        
        if count == 0 then
            local nofit = child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            nofit:SetPoint("TOPLEFT", 5, 0)
            nofit:SetText("No spells found. Run /scan first.")
        end
        
        child:SetHeight(math.max(y, 100))
    end
    
    return f
end

function UI:LoadKeybinds(c)
    if c.loaded then self:RefreshKeybinds(); return end
    local y = 0
    
    local title = c:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 15, y); title:SetText("Keybinds")
    y = y - 35

    local tip = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tip:SetPoint("TOPLEFT", 15, y); tip:SetText("Click + to assign a spell, X to clear, or use Auto Bind")
    tip:SetTextColor(0.7, 0.7, 0.7); y = y - 30

    local smart = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
    smart:SetSize(120, 24); smart:SetPoint("TOPLEFT", 15, y); smart:SetText("Auto Bind")
    smart:SetScript("OnClick", function() ns.Bindings:SmartBind(); self:RefreshKeybinds() end)

    local clearAll = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
    clearAll:SetSize(100, 24); clearAll:SetPoint("LEFT", smart, "RIGHT", 8, 0); clearAll:SetText("Clear All")
    clearAll:SetScript("OnClick", function() 
        for _, slot in ipairs(ns.Bindings:GetOrderedSlots()) do ns.Bindings:Clear(slot) end
        self:RefreshKeybinds() 
    end); y = y - 35

    c.keyHeader = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    c.keyHeader:SetPoint("TOPLEFT", 15, y); c.keyHeader:SetText("--- Bindings ---")
    c.keyRows = {}
    c.keyY = y - 25
    self:RefreshKeybinds()
    c.loaded = true
end

function UI:RefreshKeybinds()
    local data = tabContent["Keybinds"]
    if not data or not data.child then return end
    local content = data.child
    local y = content.keyY or -60
    
    if not spellPickerFrame then CreateSpellPicker() end
    
    local slots = ns.Bindings:GetOrderedSlots()
    for i, slot in ipairs(slots) do
        local row = content.keyRows and content.keyRows[i]
        if not row then
            row = CreateFrame("Frame", nil, content)
            row:SetSize(360, 24)
            row:SetPoint("TOPLEFT", 15, y - (i-1) * 26)
            
            row.txt = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.txt:SetPoint("LEFT", 5, 0)
            row.txt:SetText(slot)
            
            row.spell = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row.spell:SetPoint("LEFT", 100, 0)
            row.spell:SetWidth(160)
            
            local plus = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            plus:SetSize(24, 18); plus:SetPoint("RIGHT", -5, 0); plus:SetText("+")
            plus:SetScript("OnClick", function()
                spellPickerFrame:Open(slot, row)
            end)
            row.plus = plus
            
            local clr = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            clr:SetSize(24, 18); clr:SetPoint("RIGHT", plus, "LEFT", -2, 0); clr:SetText("X")
            clr:SetScript("OnClick", function() ns.Bindings:Clear(slot); self:RefreshKeybinds() end)
            row.clr = clr
            
            if not content.keyRows then content.keyRows = {} end
            content.keyRows[i] = row
        end
        local rec = ns.Bindings:Get(slot)
        local text = rec.value or ""
        if text == "" then text = "|cff888888-- none --|r" end
        row.spell:SetText(text)
    end
end

function UI:Toggle()
    if not frame then self:CreateMainWindow() end
    if frame:IsShown() then frame:Hide() else frame:Show(); self:ShowTab(activeTab) end
end

function UI:OnInitialize()
end
