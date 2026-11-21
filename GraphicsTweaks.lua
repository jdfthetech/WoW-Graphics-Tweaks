-- GraphicsTweaks - rebuild major UI changes, adding sidebar with panels rather than tabs, and also opacity slider
-- TOC requirement: ## SavedVariables: GraphicsTweaksDB
-- Retains original slider ranges and existing saved-variable keys.
-- several new categories and sections for hidden console variables
local addonName = ...
local assets = "Interface\\AddOns\\" .. (addonName or "GraphicsTweaks") .. "\\Textures\\"
local ready = false
local UpdateControls

-- create local cvar db
local function Database()
    if type(GraphicsTweaksDB) ~= "table" then
        GraphicsTweaksDB = {}
    end
    return GraphicsTweaksDB
end

-- message to wow console
local function Message(text)
    print("|cff00ff00Graphics Tweaks:|r " .. tostring(text))
end

-- create cvar functions
local function ReadCVar(name)
    local getter = C_CVar and C_CVar.GetCVar or GetCVar
    if type(getter) ~= "function" then return nil end
    local ok, value = pcall(getter, name)
    if ok then return value end
end


local function WriteCVar(name, value)
    local setter = C_CVar and C_CVar.SetCVar or SetCVar
    if type(setter) ~= "function" then
        Message("This client does not expose SetCVar.")
        return false
    end
    local ok = pcall(setter, name, tostring(value))
    if not ok or tonumber(ReadCVar(name)) ~= tonumber(value) then
        Message("The client could not apply " .. name .. " = " .. tostring(value) .. ".")
        return false
    end
    return true
end

-- Main Window Frame
local CONTENT_WIDTH, SIDEBAR_WIDTH = 560, 200
local MainFrame = CreateFrame("Frame", "GraphicsTweaksMainFrame", UIParent, "BasicFrameTemplateWithInset")
MainFrame:SetSize(CONTENT_WIDTH + SIDEBAR_WIDTH, 800)
MainFrame:SetPoint("CENTER", UIParent, "CENTER")
MainFrame:SetFrameStrata("DIALOG")
MainFrame:SetClampedToScreen(true)
MainFrame:SetMovable(true)
MainFrame:EnableMouse(true)
MainFrame:RegisterForDrag("LeftButton")
MainFrame:SetScript("OnDragStart", MainFrame.StartMoving)
MainFrame:SetScript("OnDragStop", MainFrame.StopMovingOrSizing)
MainFrame.TitleText:SetText("Graphics Tweaks Categories")
MainFrame:Hide()
table.insert(UISpecialFrames, "GraphicsTweaksMainFrame")

-- Replace the template's overlapping background textures with a single fill.
-- Draw it below the template's border so its opacity can change independently.
MainFrame:DisableDrawLayer("BACKGROUND")
local background = MainFrame:CreateTexture(nil, "BORDER", nil, -8)
background:SetPoint("TOPLEFT", MainFrame, "TOPLEFT", 2, -2)
background:SetPoint("BOTTOMRIGHT", MainFrame, "BOTTOMRIGHT", -2, 2)
background:SetColorTexture(0.06, 0.06, 0.06, 1)

local opacitySlider = CreateFrame("Slider", "GraphicsTweaksOpacitySlider", MainFrame, "UISliderTemplate")
opacitySlider:SetSize(220, 16)
opacitySlider:SetPoint("BOTTOM", MainFrame, "BOTTOM", SIDEBAR_WIDTH / 2, 16)
opacitySlider:SetMinMaxValues(0, 100)
opacitySlider:SetValueStep(1)
opacitySlider:SetObeyStepOnDrag(true)
opacitySlider:SetValue(100)
opacitySlider:SetScript("OnValueChanged", function(_, value)
    background:SetAlpha(value / 100)
    if ready then
        Database().backgroundOpacity = value
    end
end)

local opacityLabel = opacitySlider:CreateFontString(nil, "OVERLAY", "GameFontNormal")
opacityLabel:SetPoint("BOTTOM", opacitySlider, "TOP", 0, 4)
opacityLabel:SetText("Background Opacity")

local sidebar = CreateFrame("Frame", nil, MainFrame)
sidebar:SetPoint("TOPLEFT", MainFrame, "TOPLEFT", 8, -28)
sidebar:SetPoint("BOTTOMLEFT", MainFrame, "BOTTOMLEFT", 8, 8)
sidebar:SetWidth(SIDEBAR_WIDTH - 8)

local divider = sidebar:CreateTexture(nil, "BORDER")
divider:SetPoint("TOPRIGHT", sidebar, "TOPRIGHT")
divider:SetPoint("BOTTOMRIGHT", sidebar, "BOTTOMRIGHT")
divider:SetWidth(1)
divider:SetColorTexture(0.34, 0.26, 0.16, 1)

MainFrame.Tabs = {}
MainFrame.Panels = {}

-- create table tabGroup number vars for easier placement later
local textures_numTab = 1
local nPC_Char_num = 2
local environment_numTab = 3
local part_Fog_numTab = 4
local lighting_numTab = 5
local shadows_numTab = 6
local hDR_numTab = 7
local rendering_numTab = 8
local devnotes_numTab = 9
-- these can be used in place of MainFrame.Panels[#]


local tabGroups = {
-- rewrite of new sections starts here    
    { title = "3d Models", tabs = { "Textures", "Character Models"} },
    { title = "The World", tabs = { "Environment", "Particles and Fog", "Lighting", "Shadows"} },
    { title = "Performance", tabs = { "HDR", "Rendering"}, },
    { title = "Info", tabs = { "Developer Notes"} },
    
}

local function UpdateTabAppearance(tab)
    local selected, hovered = tab.selected, tab.hovered
    tab.highlight:SetAlpha(selected and 0.62 or hovered and 0.35 or 0)
    tab.selectionMark:SetShown(selected)
    if selected or hovered then
        tab.label:SetTextColor(1, 0.92, 0.68)
    else
        tab.label:SetTextColor(1, 0.82, 0.32)
    end
end

local function ClearTabHover(tab)
    tab.hovered = false
    UpdateTabAppearance(tab)
end

-- Function to Handle Tab Switching Visibility
local function SwitchToTab(targetIndex)
    if not MainFrame.Panels[targetIndex] then return end
    for i, tab in ipairs(MainFrame.Tabs) do
        local selected = i == targetIndex
        local panel = MainFrame.Panels[i]
        panel:SetShown(selected)
        panel.Viewport:SetShown(selected)
        tab.selected = selected
        UpdateTabAppearance(tab)
    end
    if ready and UpdateControls then UpdateControls() end
end

local function CreateSidebarTab(name, tabIndex, y)
    local tab = CreateFrame("Button", nil, sidebar)
    tab:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 3, y)
    tab:SetPoint("TOPRIGHT", sidebar, "TOPRIGHT", -5, y)
    tab:SetHeight(22)
    tab:EnableMouse(true)

    tab.highlight = tab:CreateTexture(nil, "BACKGROUND")
    tab.highlight:SetAllPoints(tab)
    tab.highlight:SetColorTexture(0.38, 0.28, 0.14, 1)

    tab.selectionMark = tab:CreateTexture(nil, "ARTWORK")
    tab.selectionMark:SetPoint("TOPLEFT", tab, "TOPLEFT", 0, -2)
    tab.selectionMark:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 0, 2)
    tab.selectionMark:SetWidth(2)
    tab.selectionMark:SetColorTexture(0.91, 0.69, 0.31, 1)

    tab.label = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalMed1")
    tab.label:SetPoint("LEFT", tab, "LEFT", 16, 0)
    tab.label:SetText(name)

    tab:SetScript("OnClick", function(self)
        if not self.selected then SwitchToTab(tabIndex) end
    end)
    tab:SetScript("OnEnter", function(self)
        self.hovered = true
        UpdateTabAppearance(self)
    end)
    tab:SetScript("OnLeave", ClearTabHover)
    tab:SetScript("OnHide", ClearTabHover)
    return tab
end

local function CreateSettingsPanel(name)
    local leftInset, rightInset, topInset, bottomInset = 15, 22, 34, 58
    local viewport = CreateFrame("ScrollFrame", nil, MainFrame)
    viewport:SetPoint("TOPLEFT", MainFrame, "TOPLEFT", SIDEBAR_WIDTH + leftInset, -topInset)
    viewport:SetPoint("BOTTOMRIGHT", MainFrame, "BOTTOMRIGHT", -rightInset, bottomInset)
    viewport:Hide()

    local panel = CreateFrame("Frame", nil, viewport)
    panel.Viewport = viewport
    panel:SetSize(CONTENT_WIDTH - leftInset - rightInset, MainFrame:GetHeight() - topInset - bottomInset)
    viewport:SetScrollChild(panel)
    panel:SetPoint("TOPLEFT", viewport, "TOPLEFT", 0, 0)
    viewport:EnableMouse(true)
    panel:EnableMouse(true)

    local scrollBar = CreateFrame("Slider", nil, viewport)
    scrollBar:SetPoint("TOPLEFT", viewport, "TOPRIGHT", 4, 0)
    scrollBar:SetPoint("BOTTOMLEFT", viewport, "BOTTOMRIGHT", 4, 0)
    scrollBar:SetWidth(12)
    scrollBar:SetOrientation("VERTICAL")
    scrollBar:SetMinMaxValues(0, 1)
    scrollBar:SetValue(0)
    scrollBar:EnableMouse(true)
    scrollBar:Hide()

    local track = scrollBar:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints(scrollBar)
    track:SetColorTexture(0.21, 0.16, 0.10, 1)

    scrollBar:SetThumbTexture("Interface\\Buttons\\WHITE8X8")
    local thumb = scrollBar:GetThumbTexture()
    thumb:SetSize(8, 26)
    thumb:SetVertexColor(0.84, 0.66, 0.32)

    local scrollRange, syncing, layoutPasses = 0, false, 0

    local function SetScrollOffset(value)
        value = math.max(0, math.min(scrollRange, value))
        syncing = true
        scrollBar:SetValue(value)
        viewport:SetVerticalScroll(value)
        syncing = false
    end
    scrollBar:SetScript("OnValueChanged", function(_, value)
        if not syncing then SetScrollOffset(value) end
    end)

    -- Anchor offsets stay valid while the window is hidden or off screen.
    local function RegionHeight(region)
        local height = region:GetHeight() or 0
        if region.GetStringHeight then
            height = math.max(height, region:GetStringHeight() or 0)
        end
        return height
    end
    local function AnchorFraction(point)
        if point:find("TOP", 1, true) then return 0 end
        if point:find("BOTTOM", 1, true) then return 1 end
        return 0.5
    end
    local function ResizeContent()
        local cache, resolving = { [panel] = 0 }, {}
        local function TopOffset(region)
            if cache[region] ~= nil then return cache[region] end
            if resolving[region] then return nil end
            if region:GetNumPoints() == 0 then return nil end
            resolving[region] = true
            local point, relative, relativePoint, _, y = region:GetPoint(1)
            if type(relative) == "string" then relative = _G[relative] end
            local top
            if point and relative then
                local relativeTop = TopOffset(relative)
                if relativeTop then
                    top = relativeTop + AnchorFraction(relativePoint or point) * RegionHeight(relative)
                        - (y or 0) - AnchorFraction(point) * RegionHeight(region)
                end
            end
            resolving[region] = nil
            cache[region] = top
            return top
        end
        local contentHeight = 0
        local function IncludeRegion(region)
            if not region:IsShown() then return end
            local top = TopOffset(region)
            if top then contentHeight = math.max(contentHeight, top + RegionHeight(region)) end
        end
        local function MeasureChildren(frame)
            for _, region in ipairs({ frame:GetRegions() }) do IncludeRegion(region) end
            for _, child in ipairs({ frame:GetChildren() }) do
                if child:IsShown() then
                    IncludeRegion(child)
                    MeasureChildren(child)
                end
            end
        end
        MeasureChildren(panel)
        local visibleHeight = math.max(1, viewport:GetHeight())
        local height = math.max(visibleHeight, math.ceil(contentHeight + 16))
        if panel:GetHeight() ~= height then panel:SetHeight(height) end
        scrollRange = math.max(0, height - visibleHeight)
        viewport:UpdateScrollChildRect()
        syncing = true
        scrollBar:SetMinMaxValues(0, math.max(1, scrollRange))
        syncing = false
        scrollBar:SetShown(scrollRange > 0)
        SetScrollOffset(viewport:GetVerticalScroll())
    end

    -- A second layout pass includes FontStrings after wrapping is resolved.
    local function FinishLayout(self)
        ResizeContent()
        layoutPasses = layoutPasses - 1
        if layoutPasses <= 0 then self:SetScript("OnUpdate", nil) end
    end
    panel.RequestLayout = function()
        layoutPasses = 2
        viewport:SetScript("OnUpdate", FinishLayout)
    end
    panel.ScrollBy = function(delta)
        if scrollRange <= 0 then return false end
        SetScrollOffset(viewport:GetVerticalScroll() - delta * 40)
        return true
    end
    local function ScrollWithWheel(_, delta)
        panel.ScrollBy(delta)
    end
    -- Cover both the viewport and its content, including blank areas.
    viewport:EnableMouseWheel(true)
    panel:EnableMouseWheel(true)
    scrollBar:EnableMouseWheel(true)
    viewport:SetScript("OnMouseWheel", ScrollWithWheel)
    panel:SetScript("OnMouseWheel", ScrollWithWheel)
    scrollBar:SetScript("OnMouseWheel", ScrollWithWheel)
    viewport:SetScript("OnSizeChanged", function(_, width)
        panel:SetWidth(math.max(width, 1))
        panel.RequestLayout()
    end)
    viewport:SetScript("OnShow", function()
        ResizeContent()
        panel.RequestLayout()
    end)

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -10)
    title:SetTextColor(0.96, 0.93, 0.86)
    title:SetText(name)

    local rule = panel:CreateTexture(nil, "ARTWORK")
    rule:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -34)
    rule:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -10, -34)
    rule:SetHeight(1)
    rule:SetColorTexture(0.34, 0.26, 0.16, 1)

    if name == "Developer Notes" then
	local notes = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")

	notes:ClearAllPoints()
	notes:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -40)
	notes:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -20, -40)

	notes:SetJustifyH("LEFT")
	notes:SetJustifyV("TOP")
	notes:SetWordWrap(true)
	notes:SetNonSpaceWrap(true)
	notes:SetHeight(0)
        notes:SetText("I built this tool because I wanted an easy to use UI for the more complicated graphics console variables.  The idea is to bring these commands to the folks who may not be comfortable with console commands and how to use them.  \n\nI hope this helps you to tweak your settings for gameplay and easily jack things up for screenshots etc.  \n\n\n\n NOTE: \n\n There have been some issues with the latest release of WoW Forever where the clients begin seeing hitching over time.  It has been identified as an issue with Triple Buffering.  I have found an easy fix is to pull up triple buffering in the video settings and enable / disable it.  This seems to clear the memory leak.  \n\n\n\nThe latest version of this addon will always be at:\n\n\n\n https://github.com/jdfthetech/WoW-Graphics-Tweaks/releases")
    end

    panel:Hide()
    return panel
end

local y = -6
for _, group in ipairs(tabGroups) do
    local header = CreateFrame("Frame", nil, sidebar)
    header:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 1, y)
    header:SetPoint("TOPRIGHT", sidebar, "TOPRIGHT", -2, y)
    header:SetHeight(22)

    local headerBorder = header:CreateTexture(nil, "BACKGROUND")
    headerBorder:SetAllPoints(header)
    headerBorder:SetColorTexture(0.33, 0.24, 0.14, 1)

    local headerFill = header:CreateTexture(nil, "ARTWORK")
    headerFill:SetPoint("TOPLEFT", header, "TOPLEFT", 1, -1)
    headerFill:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", -1, 1)
    headerFill:SetColorTexture(0.13, 0.085, 0.045, 1)

    local heading = header:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    heading:SetPoint("LEFT", header, "LEFT", 10, 0)
    heading:SetText(group.title)

    y = y - 25
    for _, name in ipairs(group.tabs) do
        local index = #MainFrame.Tabs + 1
        MainFrame.Tabs[index] = CreateSidebarTab(name, index, y)
        MainFrame.Panels[index] = CreateSettingsPanel(name)
        y = y - 22
    end
    y = y - 12
end

--- more functions


local function Checkbox(parent, name, y, text, options)
    assert(parent, "Checkbox requires a parent panel")
    local button = CreateFrame("CheckButton", name, parent, "UICheckButtonTemplate")
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, y)
    button:EnableMouseWheel(true)
    button:SetScript("OnMouseWheel", function(_, delta)
        if parent.ScrollBy then parent.ScrollBy(delta) end
    end)
    local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", button, "RIGHT", 4, 0)
    label:SetText(text)

    local checkDesc = options and options.checkDesc
    if type(checkDesc) == "string" and checkDesc ~= "" then
        local description = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        description:SetPoint("TOPLEFT", button, "BOTTOMRIGHT", 4, -4)
        description:SetWidth(420)
        description:SetJustifyH("LEFT")
        description:SetWordWrap(true)
        description:SetText(checkDesc)
    end

    -- Keep the checkbox and label on the left; align restoration with this row.
    local function RefreshCheckbox() end
    if options and options.cvar and options.savedKey then
        local restore = CreateFrame("Button", name .. "RestoreOriginal", parent, "UIPanelButtonTemplate")
        restore:SetSize(140, 24)
        restore:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -20, y - 4)
        restore:SetText("Restore original")
        restore:Disable()
        restore:EnableMouseWheel(true)
        restore:SetScript("OnMouseWheel", function(_, delta)
            if parent.ScrollBy then parent.ScrollBy(delta) end
        end)
        label:SetPoint("RIGHT", restore, "LEFT", -12, 0)
        label:SetJustifyH("LEFT")

        RefreshCheckbox = function()
            if not ready then return end
            local current = ReadCVar(options.cvar)
            local currentValue = tonumber(current)
            local db = Database()
            -- Capture once, preserving saved originals and the value zero.
            if tonumber(db[options.savedKey]) == nil and currentValue ~= nil then
                db[options.savedKey] = current
            end
            local original = tonumber(db[options.savedKey])
            button:SetChecked(currentValue == 1)
            button:SetEnabled(currentValue ~= nil)
            restore:SetEnabled(currentValue ~= nil and original ~= nil and currentValue ~= original)
        end

        restore:SetScript("OnClick", function()
            if not ready then return end
            local original = Database()[options.savedKey]
            if tonumber(original) ~= nil and WriteCVar(options.cvar, original) then
                Message(text .. " restored to original = " .. tostring(original))
            end
            UpdateControls()
        end)
    end

    if parent.RequestLayout then parent.RequestLayout() end
    return button, RefreshCheckbox
end

-- Sliders support explicit values lists or min/max/step ranges.
local TRACK_TOP_OFFSET = 100
local descriptionAnchors = {}

local function GenericSlider(config)
    local parent = assert(config.parent, "GenericSlider requires a parent panel")
    local MIN, MAX, STEP, TRACK_WIDTH = config.min, config.max, config.step, 420
    local stops = {}
    local listed = config.values ~= nil
    local function IsFinite(value)
        return type(value) == "number" and value == value
            and value > -math.huge and value < math.huge
    end
    if listed then
        assert(type(config.values) == "table" and #config.values >= 2,
            "GenericSlider values requires at least two numbers")
        for index = 1, #config.values do
            local value = config.values[index]
            assert(IsFinite(value) and (index == 1 or value > stops[index - 1]),
                "GenericSlider values must be finite numbers in strictly increasing order")
            stops[index] = value
        end
        for key in pairs(config.values) do
            assert(type(key) == "number" and key % 1 == 0 and key >= 1 and key <= #stops,
                "GenericSlider values must be a consecutive array")
        end
        MIN, MAX = stops[1], stops[#stops]
    else
        assert(IsFinite(MIN) and IsFinite(MAX) and IsFinite(STEP)
            and MAX > MIN and STEP > 0, "Invalid slider range or step")
        for value = MIN, MAX, STEP do
            stops[#stops + 1] = value
        end
    end
    local offset = config.offset or 0
    local anchor, anchorOffset = parent, offset
    local preceding = descriptionAnchors[parent]
    if preceding then
        -- Keep the configured spacing after the last slider that moved for a description.
        anchor = preceding.slider
        anchorOffset = offset - preceding.trackOffset
    end
    local function Clamp(value) return math.max(MIN, math.min(MAX, value)) end
    local function Snap(value)
        if listed then
            local best, distance = stops[1], math.abs(value - stops[1])
            for index = 2, #stops do
                local candidateDistance = math.abs(value - stops[index])
                if candidateDistance <= distance then
                    best, distance = stops[index], candidateDistance
                end
            end
            return best
        end
        return Clamp(MIN + math.floor((value - MIN) / STEP + 0.5) * STEP)
    end
    local function Position(value)
        value = Clamp(value)
        if listed then
            -- Equally space allowed stops. Interpolate saved originals that
            -- fall between them without changing the saved original value.
            for index = 2, #stops do
                if value <= stops[index] then
                    local fraction = (value - stops[index - 1]) / (stops[index] - stops[index - 1])
                    return (index - 2 + fraction) / (#stops - 1) * TRACK_WIDTH
                end
            end
            return TRACK_WIDTH
        end
        return (value - MIN) / (MAX - MIN) * TRACK_WIDTH
    end

    local valueLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    valueLabel:SetPoint("TOP", anchor, "TOP", 0, -48 - anchorOffset)
    local slider = CreateFrame("Frame", config.name, parent)
    slider:SetSize(TRACK_WIDTH, 38)
    slider:EnableMouse(false)
    slider:EnableMouseWheel(true)
    local track = slider:CreateTexture(nil, "BACKGROUND")
    track:SetColorTexture(0.4, 0.4, 0.4, 1)
    track:SetSize(TRACK_WIDTH, 3)
    track:SetPoint("LEFT", slider, "LEFT", 0, 0)
    for _, value in ipairs(stops) do
        local dot = slider:CreateTexture(nil, "ARTWORK")
        dot:SetTexture(assets .. "Dot.tga")
        dot:SetSize(8, 8)
        dot:SetPoint("CENTER", slider, "LEFT", Position(value), 0)
        local label = slider:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint("TOP", dot, "BOTTOM", 0, -8)
        label:SetText(tostring(value))
    end
    local thumb = slider:CreateTexture(nil, "OVERLAY")
    thumb:SetTexture(assets .. "Thumb.tga")
    thumb:SetSize(10, 10)
    local originalStar = slider:CreateTexture(nil, "OVERLAY")
    originalStar:SetTexture(assets .. "Star.tga")
    originalStar:SetSize(16, 16)
    
    local originalLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")

    local restore = CreateFrame("Button", config.restoreName, parent, "UIPanelButtonTemplate")
    restore:SetSize(180, 24)
    restore:SetPoint("TOP", anchor, "TOP", 0, -70 - anchorOffset)
    restore:SetText("Restore original")
    restore:Disable()
    restore:EnableMouseWheel(true)
    restore:SetScript("OnMouseWheel", function(_, delta)
        if parent.ScrollBy then parent.ScrollBy(delta) end
    end)
    originalLabel:SetPoint("TOP", restore, "BOTTOM", 0, -8)

    if type(config.description) == "string" and config.description ~= "" then
        local description = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        description:SetWidth(TRACK_WIDTH)
        description:SetPoint("TOP", originalLabel, "BOTTOM", 0, -4)
        description:SetText(config.description)

        -- Leave room for the original-value star above the slider track.
        slider:SetPoint("TOP", description, "BOTTOM", 0, -21)
        descriptionAnchors[parent] = { slider = slider, trackOffset = offset + TRACK_TOP_OFFSET }
    else
        slider:SetPoint("TOP", anchor, "TOP", 0, -TRACK_TOP_OFFSET - anchorOffset)
    end

    local refreshing, applying = false, false
    local UpdateControls

    local function RememberOriginal(current)
        local db = Database()
        -- Preserve an existing saved original, including on addon upgrades.
        -- Otherwise capture the current value before the first slider change.
        if tonumber(db[config.savedKey]) == nil and tonumber(current) ~= nil then
            db[config.savedKey] = current
        end
        return db[config.savedKey]
    end

    UpdateControls = function()
        if not ready or refreshing or applying then return end
        refreshing = true
        local current = ReadCVar(config.cvar)
        local currentValue = tonumber(current)
        local original = RememberOriginal(current)
        local baseline = tonumber(original)
        slider.available = currentValue ~= nil
        slider:EnableMouse(slider.available)
        slider:EnableMouseWheel(true)
        slider:SetAlpha(slider.available and 1 or 0.4)
        valueLabel:SetText(config.label .. ": " .. tostring(current or "unavailable"))
        thumb:ClearAllPoints()
        thumb:SetPoint("CENTER", slider, "LEFT", Position(Snap(currentValue or MIN)), 0)
        originalStar:ClearAllPoints()
        if baseline then
            originalStar:SetPoint("CENTER", slider, "LEFT", Position(baseline), 26)
            originalStar:Show()
            local suffix = ""
            if baseline < MIN then suffix = " (below slider range)"
            elseif baseline > MAX then suffix = " (above slider range)" end
            originalLabel:SetText("|cffffff00Original " .. config.label .. ": " .. tostring(original) .. suffix .. "|r")
        else
            originalStar:Hide()
            originalLabel:SetText("Original " .. config.label .. " unavailable")
        end
        restore:SetEnabled(currentValue ~= nil and baseline ~= nil and currentValue ~= baseline)
        if currentValue ~= nil and baseline ~= nil then
            Database()[config.overrideKey] = currentValue ~= baseline
        end
        refreshing = false
        if parent.RequestLayout then parent.RequestLayout() end
    end

    local function ApplyValue(value)
        if refreshing or applying or not slider.available then return end
        value = Snap(value)
        local current = ReadCVar(config.cvar)
        if tonumber(current) == value then return end
        RememberOriginal(current)
        applying = true
        local ok = WriteCVar(config.cvar, value)
        applying = false
        if ok then
            Database()[config.overrideKey] = tonumber(Database()[config.savedKey]) ~= value
        else
            slider.dragging = false
        end
        UpdateControls()
    end

    local function ApplyCursorPosition()
        local x = GetCursorPosition()
        local left = slider:GetLeft()
        if left then
            local fraction = (x / slider:GetEffectiveScale() - left) / TRACK_WIDTH
            if listed then
                fraction = math.max(0, math.min(1, fraction))
                local index = math.floor(fraction * (#stops - 1) + 0.5) + 1
                ApplyValue(stops[index])
            else
                ApplyValue(MIN + fraction * (MAX - MIN))
            end
        end
    end
    slider:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" and self.available then
            self.dragging = true
            ApplyCursorPosition()
        end
    end)
    slider:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then self.dragging = false end
    end)
    slider:SetScript("OnUpdate", function(self)
        if self.dragging then
            if IsMouseButtonDown("LeftButton") then ApplyCursorPosition()
            else self.dragging = false end
        end
    end)
    slider:SetScript("OnHide", function(self) self.dragging = false end)
    slider:SetScript("OnMouseWheel", function(_, delta)
        -- Normal wheel input scrolls an overflowing pane; Shift adjusts values.
        if not IsShiftKeyDown() and parent.ScrollBy and parent.ScrollBy(delta) then return end
        local current = tonumber(ReadCVar(config.cvar))
        if not current or delta == 0 then return end
        if listed then
            -- Move to the next allowed value, including from off-list values.
            local nextValue = delta > 0 and MAX or MIN
            if delta > 0 then
                for index = 1, #stops do
                    if stops[index] > current then nextValue = stops[index]; break end
                end
            else
                for index = #stops, 1, -1 do
                    if stops[index] < current then nextValue = stops[index]; break end
                end
            end
            ApplyValue(nextValue)
        else
            ApplyValue(Snap(current) + (delta > 0 and STEP or -STEP))
        end
    end)
    restore:SetScript("OnClick", function()
        local original = Database()[config.savedKey]
        if tonumber(original) ~= nil then
            applying = true
            local ok = WriteCVar(config.cvar, original)
            applying = false
            if ok then
                Database()[config.overrideKey] = false
                Message(config.label .. " restored to " .. tostring(original))
            end
        end
        UpdateControls()
    end)

    if parent.RequestLayout then parent.RequestLayout() end
    return UpdateControls
end

-- Open to the first tab by default
SwitchToTab(1)

----------------------------------------------------
-- Build the items in the panels here
----------------------------------------------------

----------------------------------------------------
-- TEXTURES
----------------------------------------------------

-- componentTexLoadLimit
local RefreshTexLoadLimit = GenericSlider({
    parent = MainFrame.Panels[textures_numTab ],
    name = "componentTexLoadLimitSlider",
    restoreName = "GraphicsTweaksRestorecomponentTexLoadLimitOriginal",
    label = "Component Texture Load Limit", cvar = "componentTexLoadLimit",
    min = 8, max = 128, step = 8, offset = 0,
    savedKey = "previouscomponentTexLoadLimit", overrideKey = "componentTexLoadLimitOverride",
    description = "how many character component textures are loaded per frame",
})

-- componentTexCacheSize
local RefreshcomponentTexCacheSize = GenericSlider({
    parent = MainFrame.Panels[textures_numTab],
    name = "componentTexCacheSizeSlider",
    restoreName = "GraphicsTweaksRestorecomponentTexCacheSizeOriginal",
    label = "Component Texture Cache Size", cvar = "componentTexCacheSize",
    min = 32, max = 128, step = 16, offset = 100,
    savedKey = "previouscomponentTexCacheSize", overrideKey = "componentTexCacheSizeOverride",
    description = "sets the size of the character component texture cache, in megabytes",
})

-- ResampleAlwaysSharpen

local funcSharpen, RefreshSharpen = Checkbox(MainFrame.Panels[textures_numTab], "GraphicsTweaksSharpen", -440, "Resample Always Sharpen", {
    cvar = "ResampleAlwaysSharpen", savedKey = "previousResampleAlwaysSharpen",
    checkDesc = "sharpen textures in the world",
})
funcSharpen:Disable()

-- componentCompress

local functexCompress, RefreshTexCompress = Checkbox(MainFrame.Panels[textures_numTab], "GraphicsTweakscomponentCompress", -540, "Model Texture Compression", {
    cvar = "componentCompress", savedKey = "previousComponentCompress",
    checkDesc = "Enable texture compression for character models",
})
functexCompress:Disable()


----------------------------------------------------
-- 3d Models
----------------------------------------------------


-- entityLodDist
local RefreshentityLodDist = GenericSlider({
    parent = MainFrame.Panels[nPC_Char_num],
    name = "entityLodDistSlider",
    restoreName = "GraphicsTweaksRestoreentityLodDistOriginal",
    label = "Entity Level of Detail Distance", cvar = "entityLodDist",
    min = 10, max = 1010, step = 100, offset = 0,
    savedKey = "previousentityLodDist", overrideKey = "entityLodDistOverride",
    description = "how far from your camera a unit can retain a more detailed 3D model",
})


-- bodyQuota
local RefreshbodyQuota = GenericSlider({
    parent = MainFrame.Panels[nPC_Char_num],
    name = "entitybodyQuotaSlider",
    restoreName = "GraphicsTweaksRestorebodyQuotaOriginal",
    label = "3d Body Quota", cvar = "bodyQuota",
    min = 10, max = 200, step = 10, offset = 120,
    savedKey = "previousbodyQuota", overrideKey = "bodyQuotaOverride",
    description = "how many assembled character models that can be shown at one time",
})


-- M2UseThreads

local funcM2UseThreads, RefreshM2UseThreads = Checkbox(MainFrame.Panels[nPC_Char_num], "GraphicsTweaksM2UseThreads", -540, "Multithreading for Model Animations", {
    cvar = "M2UseThreads", savedKey = "previousM2UseThreads",
    checkDesc = "Enables multithreading for model animations in WoW",
})
funcM2UseThreads:Disable()

----------------------------------------------------
-- Environment
----------------------------------------------------

-- groundEffectDensity
local RefreshGround = GenericSlider({
    parent = MainFrame.Panels[environment_numTab],
    name = "GraphicsTweaksDensitySlider",
    restoreName = "GraphicsTweaksRestoreOriginal",
    label = "Ground Effect Density", cvar = "groundEffectDensity",
    min = 16, max = 256, step = 16, offset = 0,
    savedKey = "previousGroundEffectDensity", overrideKey = "groundEffectOverride",
    description = "adjusts ground clutter density such as vegetation etc",
})


-- weatherdensity
local RefreshWeather = GenericSlider({
    parent = MainFrame.Panels[environment_numTab],
    name = "GraphicsTweaksWeatherSlider",
    restoreName = "GraphicsTweaksRestoreWeatherOriginal",
    label = "Weather Density", cvar = "weatherdensity",
    min = 0, max = 3, step = 1, offset = 450,
    savedKey = "previousWeatherDensity", overrideKey = "weatherDensityOverride",
    description = "change how detailed weather effects are",
})


-- groundEffectDist
local RefreshgroundEffectDist = GenericSlider({
    parent = MainFrame.Panels[environment_numTab],
    name = "GraphicsgroundEffectDistSlider",
    restoreName = "GraphicsTweaksgroundEffectDistOriginal",
    label = "Ground Effect Distance", cvar = "groundEffectDist",
    min = 240, max = 500, step = 20, offset = 100,
    savedKey = "previousgroundEffectDist", overrideKey = "groundEffectDistOverride",
    description = "change how far the vegetation and other ground effects appear",
})


-- violenceLevel
local RefreshViolenceLvl = GenericSlider({
    parent = MainFrame.Panels[environment_numTab],
    name = "ViolenceLvlSlider",
    restoreName = "ViolenceLvlOriginal",
    label = "Violence Level", cvar = "violenceLevel",
    min = 0, max = 5, step = 1, offset = 200,
    savedKey = "previousViolenceLvl", overrideKey = "ViolenceLvlOverride",
    description = "adjusts violence level, increase for more blood etc",
})



-- SkyCloudLOD
local RefreshSkyCloudLOD = GenericSlider({
    parent = MainFrame.Panels[environment_numTab],
    name = "GraphicsTweaksSkyCloudLODSlider",
    restoreName = "GraphicsTweaksRestoreSkyCloudLODOriginal",
    label = "Sky Cloud Level of Detail", cvar = "SkyCloudLOD",
    min = 0, max = 3, step = 1, offset = 500,
    savedKey = "previousSkyCloudLOD", overrideKey = "SkyCloudLODOverride",
    description = "change how detailed the sky looks",
})




----------------------------------------------------
-- Particles and Fog
----------------------------------------------------

-- graphicsComputeEffects
local RefreshGraphicsComputeEffects = GenericSlider({
    parent = MainFrame.Panels[part_Fog_numTab],
    name = "GraphicsTweaksGraphicsComputeEffectsSlider",
    restoreName = "GraphicsTweaksRestoreGraphicsComputeEffectsOriginal",
    label = "Graphics Computer Effects", cvar = "graphicsComputeEffects",
    min = 0, max = 4, step = 1, offset = 0,
    savedKey = "previousGraphicsComputeEffects", overrideKey = "GraphicsComputeEffectsOverride",
    description = "Governs how WoW renders mist and some particles",
})

-- volumeFogLevel
local RefreshVolumeFogLevel = GenericSlider({
    parent = MainFrame.Panels[part_Fog_numTab],
    name = "GraphicsTweaksVolumeFogLevelSlider",
    restoreName = "GraphicsTweaksRestoreVolumeFogLevelOriginal",
    label = "Volume Fog Level", cvar = "volumeFogLevel",
    min = 0, max = 4, step = 1, offset = 120,
    savedKey = "previousVolumeFogLevel", overrideKey = "VolumeFogLevelOverride",
    description = "Change the fog level - 4 is experimental",
})


-- graphicsSpellDensity
local RefreshGraphicsSpellDensity = GenericSlider({
    parent = MainFrame.Panels[part_Fog_numTab],
    name = "GraphicsTweaksGraphicsSpellDensitySlider",
    restoreName = "GraphicsTweaksRestoreGraphicsSpellDensityOriginal",
    label = "Graphics Spell Density", cvar = "graphicsSpellDensity",
    min = 0, max = 2, step = 1, offset = 240,
    savedKey = "previousGraphicsSpellDensity", overrideKey = "GraphicsSpellDensityOverride",
    description = "How much of other players’ spell effects you see - 2 is everything",
})


-- particleDensity
local RefreshParticleDensity = GenericSlider({
    parent = MainFrame.Panels[part_Fog_numTab],
    name = "GraphicsTweaksParticleDensitySlider",
    restoreName = "GraphicsTweaksRestoreParticleDensityOriginal",
    label = "Particle Effect Density", cvar = "particleDensity",
    min = 10, max = 100, step = 5, offset = 360,
    savedKey = "previousParticleDensity", overrideKey = "ParticleDensityOverride",
    description = "How densely particle effects such as sparks, spell effects etc are rendered",
})

-- particleMTDensity
local RefreshParticleMTDensity = GenericSlider({
    parent = MainFrame.Panels[part_Fog_numTab],
    name = "GraphicsTweaksParticleMTDensitySlider",
    restoreName = "GraphicsTweaksRestoreParticleMTDensityOriginal",
    label = "Multi-texture Particle Effect Density", cvar = "particleMTDensity",
    min = 10, max = 100, step = 5, offset = 480,
    savedKey = "previousParticleMTDensity", overrideKey = "ParticleMTDensityOverride",
    description = "Controls the density of particles that use multiple textures",
})

----------------------------------------------------
-- Lighting
----------------------------------------------------

-- giQuality
local RefreshGiQuality = GenericSlider({
    parent = MainFrame.Panels[lighting_numTab],
    name = "GraphicsTweaksGiQualitySlider",
    restoreName = "GraphicsTweaksGiQualityOriginal",
    label = "Global Illumination Quality", cvar = "giQuality",
    min = 1, max = 3, step = 1, offset = 0,
    savedKey = "previousGiQuality", overrideKey = "GiQualityOverride",
    description = "Controls the rendering quality of global illumination",
})

-- graphicsLightMode
local RefreshGraphicsLightMode = GenericSlider({
    parent = MainFrame.Panels[lighting_numTab],
    name = "GraphicsLightModeSlider",
    restoreName = "GraphicsTweaksGraphicsLightModeOriginal",
    label = "Graphics Light Mode", cvar = "graphicsLightMode",
    min = 0, max = 3, step = 1, offset = 120,
    savedKey = "previousGraphicsLightMode", overrideKey = "GraphicsLightModeOverride",
    description = "Controls the light mode - 0 = fair, 3 =  ultra",
})

----------------------------------------------------
-- Shadows
----------------------------------------------------

-- shadowMode
local RefreshShadowMode = GenericSlider({
    parent = MainFrame.Panels[shadows_numTab],
    name = "GraphicsTweaksShadowModeSlider",
    restoreName = "GraphicsTweaksShadowModeOriginal",
    label = "Shadow Mode", cvar = "shadowMode",
    min = 0, max = 4, step = 1, offset = 0,
    savedKey = "previousShadowMode", overrideKey = "ShadowModeOverride",
    description = "Sets how dynamic shadows are rendered",
})


-- shadowNumCascades
local RefreshShadowNumCascades = GenericSlider({
    parent = MainFrame.Panels[shadows_numTab],
    name = "GraphicsTweaksShadowNumCascades",
    restoreName = "GraphicsTweaksShadowNumCascadesOriginal",
    label = "Shadow Cascades", cvar = "shadowNumCascades",
    min = 0, max = 4, step = 1, offset = 120,
    savedKey = "previousShadowNumCascades", overrideKey = "ShadowNumCascadesOverride",
    description = "More cascades can reduce blocky shadow edges",
})


-- shadowSoft
local RefreshShadowSoft = GenericSlider({
    parent = MainFrame.Panels[shadows_numTab],
    name = "GraphicsTweaksShadowSoft",
    restoreName = "GraphicsTweaksShadowSoftOriginal",
    label = "Shadow Softness", cvar = "shadowSoft",
    min = 1, max = 4, step = 1, offset = 240,
    savedKey = "previousShadowSoft", overrideKey = "ShadowSoftOverride",
    description = "More cascades can reduce blocky shadow edges",
})


---------------
--HDR
---------------

-- HDROutput

local funcHDROutput, RefreshHDROutput = Checkbox(MainFrame.Panels[hDR_numTab], "GraphicsTweaksHDROutput", -50, "HDR Output", {
    cvar = "HDROutput", savedKey = "previousHDROutput",
    checkDesc = "Enables HDR output if your display supports it",
})
funcHDROutput:Disable()

-- HDRFactor

local RefreshHDRFactor = GenericSlider({
    parent = MainFrame.Panels[hDR_numTab],
    name = "GraphicsTweaksHDRFactor",
    restoreName = "GraphicsTweaksHDRFactorOriginal",
    label = "HDR Factor", cvar = "HDRFactor",
    min = 1.0, max = 2.0, step = .1, offset = 70,
    savedKey = "previousHDRFactor", overrideKey = "HDRFactorOverride",
    description = "Adjusts how far HDR lighting can exceed standard SDR lighting",
})

-- HDRBrightness

local RefreshHDRBrightness = GenericSlider({
    parent = MainFrame.Panels[hDR_numTab],
    name = "GraphicsTweaksHDRBrightness",
    restoreName = "GraphicsTweaksHDRBrightnessOriginal",
    label = "HDR Brightness", cvar = "HDRBrightness",
    min = 1.0, max = 2.0, step = .1, offset = 190,
    savedKey = "previousHDRBrightness", overrideKey = "HDRBrightnessOverride",
    description = "Sets an HDR brightness level in nits",
})

-- HDRPeakBrightness

local RefreshHDRPeakBrightness = GenericSlider({
    parent = MainFrame.Panels[hDR_numTab],
    name = "GraphicsTweaksHDRPeakBrightness",
    restoreName = "GraphicsTweaksHDRPeakBrightnessOriginal",
    label = "HDR Peak Brightness", cvar = "HDRPeakBrightness",
    min = 0, max = 1000, step = 100, offset = 310,
    savedKey = "previousHDRPeakBrightness", overrideKey = "HDRPeakBrightnessOverride",
    description = "Controls the normal white brightness of the world and UI during HDR rendering. 0 is automatic",
})


----------------------------------------------------
-- Rendering
----------------------------------------------------

-- renderformat - includes warning popup
local renderingPanel = MainFrame.Panels[rendering_numTab]
local renderingWarning = CreateFrame("Frame", nil, renderingPanel.Viewport, "BackdropTemplate")
renderingWarning:SetSize(340, 116)
renderingWarning:SetPoint("CENTER", renderingPanel.Viewport, "CENTER")
renderingWarning:SetFrameStrata("FULLSCREEN_DIALOG")
renderingWarning:EnableMouse(true)
renderingWarning:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    edgeSize = 24,
    insets = { left = 6, right = 6, top = 6, bottom = 6 },
})
renderingWarning:Hide()

local warningText = renderingWarning:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
warningText:SetPoint("TOP", 0, -21)
warningText:SetText("WARNING: Rendering settings are experimental!\nUse at your own risk")

local warningOkay = CreateFrame("Button", nil, renderingWarning, "UIPanelButtonTemplate")
warningOkay:SetSize(90, 24)
warningOkay:SetPoint("BOTTOM", 0, 15)
warningOkay:SetText("Okay")
warningOkay:SetScript("OnClick", function()
    renderingWarning:Hide()
end)

renderingPanel:SetScript("OnShow", function()
    renderingWarning:Show()
end)

local RefreshRenderFormat = GenericSlider({
    parent = MainFrame.Panels[rendering_numTab],
    name = "GraphicsTweaksRenderformat",
    restoreName = "GraphicsTweaksRestoreRenderformatOriginal",
    label = "Render Format", cvar = "renderformat",
    min = 1, max = 3, step = 1, offset = 0,
    savedKey = "previousRenderformat", overrideKey = "RenderformatOverride",
})







---------------------------------------------
--- update controls and load updates
---------------------------------------------

UpdateControls = function()
    if not ready then return end
    RefreshGround()
    RefreshWeather()
    RefreshRenderFormat()
    RefreshgroundEffectDist()
    RefreshSkyCloudLOD()
    RefreshViolenceLvl()
    RefreshSharpen()
    RefreshTexCompress()
    RefreshTexLoadLimit()
    RefreshcomponentTexCacheSize()
    RefreshentityLodDist()
    RefreshbodyQuota()
    RefreshM2UseThreads()
    RefreshGraphicsComputeEffects()
    RefreshVolumeFogLevel()
    RefreshGraphicsSpellDensity()
    RefreshParticleDensity()
    RefreshParticleMTDensity()
    RefreshGiQuality()
    RefreshGraphicsLightMode()
    RefreshShadowMode()
    RefreshShadowNumCascades()
    RefreshShadowSoft()
    RefreshHDROutput()
    RefreshHDRFactor()
    RefreshHDRBrightness()
    RefreshHDRPeakBrightness()
end
MainFrame:SetScript("OnShow", UpdateControls)

---------------------
--- Checkbox updates
---------------------

-- ResampleAlwaysSharpen

funcSharpen:SetScript("OnClick", function(self)
    local value = self:GetChecked() and "1" or "0"
    if WriteCVar("ResampleAlwaysSharpen", value) then
        Message("Resample Always Sharpen = " .. (value == "1" and "ON" or "OFF"))
    end
    UpdateControls()
end)



-- componentCompress

functexCompress:SetScript("OnClick", function(self)
    local value = self:GetChecked() and "1" or "0"
    if WriteCVar("componentCompress", value) then
        Message("Model Texture Compression = " .. (value == "1" and "ON" or "OFF"))
    end
    UpdateControls()
end)


-- M2UseThreads

funcM2UseThreads:SetScript("OnClick", function(self)
    local value = self:GetChecked() and "1" or "0"
    if WriteCVar("M2UseThreads", value) then
        Message("Multithreading for model animations = " .. (value == "1" and "ON" or "OFF"))
    end
    UpdateControls()
end)

-- HDROutput

funcHDROutput:SetScript("OnClick", function(self)
    local value = self:GetChecked() and "1" or "0"
    if WriteCVar("HDROutput", value) then
        Message("HDR Output = " .. (value == "1" and "ON" or "OFF"))
    end
    UpdateControls()
end)


----------------------------------------------------
-- CHAT COMMAND TO OPEN PANEL (/gt)
-- SLASH_ is a global lua switch within WoW
-- SLASH_GRAPHICSTWEAKS1 = "/gt" tells WoW that /gt is the first chat command for the GRAPHICSTWEAKS handler
-- We could use a 2 if we wanted to have a second global slash command referenced such as SLASH_GRAPHICSTWEAKS2 = "/graphicstweaks"
----------------------------------------------------
SlashCmdList["GRAPHICSTWEAKS"] = function()
    if MainFrame:IsShown() then MainFrame:Hide() else MainFrame:Show() end
end
SLASH_GRAPHICSTWEAKS1 = "/gt"


local relevantCVars = {

---------------
--Textures
---------------
    componentcompress = true,
    resamplealwayssharpen = true,
    componentTexLoadLimit = true,
    componentTexCacheSize = true,

---------------
--NPC and Character Models
---------------
    entityLodDist = true,
    bodyQuota = true,
    M2UseThreads = true,
--    componentThread = true,

---------------
--Particles and Fog
---------------

    weatherdensity = true,
    graphicsComputeEffects = true,
    volumeFogLevel = true,
    graphicsSpellDensity = true,
    particleDensity = true,
    particleMTDensity = true,

---------------
--Lighting
---------------
    giQuality = true,
    graphicsLightMode = true,

---------------
--Shadows
---------------
    shadowMode = true,
    shadowNumCascades = true,
    shadowNumCascades = true,
    shadowSoft = true,

---------------
--Environment
---------------

    doodadLodScale = true,
    groundEffectDist = true,
    groundEffectDensity = true,
    groundEffectFade = true,
    weatherdensity = true,
    violenceLevel = true,
    farclip = true,
    horizonClip = true,
    SkyCloudLOD = true,
    pbrLiquidDetail = true,
    resamplealwayssharpen = true,

---------------
--Rendering
--render warning
---------------
    SSAO = true,
    renderformat = true,
    
---------------
--HDR
---------------
    HDROutput = true,
    HDRFactor = true,
    HDRBrightness = true,
    HDRPeakBrightness = true,
       
   
    
}

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("CVAR_UPDATE")
events:SetScript("OnEvent", function(_, event, cvarName)
    if event == "PLAYER_LOGIN" then
        local opacity = tonumber(Database().backgroundOpacity) or 100
        opacitySlider:SetValue(math.max(0, math.min(100, opacity)))
        ready = true
        UpdateControls()
        
-- |c######## changes color of text |r  resets color    
        Message("Loaded. Type |cff00ff00/gt |rto open settings.")
    elseif ready and MainFrame:IsShown() and type(cvarName) == "string"
        and relevantCVars[string.lower(cvarName)] then
        UpdateControls()
    end
end)
