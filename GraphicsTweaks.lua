-- GraphicsTweaks 0.1.1 - corrected tabbed version
-- TOC requirement: ## SavedVariables: GraphicsTweaksDB
-- Retains the uploaded slider ranges and existing saved-variable keys.
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
local MainFrame = CreateFrame("Frame", "GraphicsTweaksMainFrame", UIParent, "BasicFrameTemplateWithInset")
MainFrame:SetSize(560, 600)
MainFrame:SetPoint("CENTER")
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

-- Tables for tabs and panels
MainFrame.Tabs = {}
MainFrame.Panels = {}

-- Tab Names - (can add more tabs by adding into the array)
local tabNames = { "In Game Objects", "Lighting", "Rendering" }

-- Function to Handle Tab Switching Visibility
local function SwitchToTab(targetIndex)
    if not MainFrame.Panels[targetIndex] then return end
    for i = 1, #tabNames do
        if i == targetIndex then
            MainFrame.Panels[i]:Show()
            MainFrame.Tabs[i]:Disable() -- Disabling the button makes it look "selected"
        else
            MainFrame.Panels[i]:Hide()
            MainFrame.Tabs[i]:Enable()
        end
    end
    if ready and UpdateControls then UpdateControls() end
end

--  UI loop
for i, name in ipairs(tabNames) do
    -- Create the Tab Button (Uses the safe, standard UI Panel Button)
    local tab = CreateFrame("Button", nil, MainFrame, "UIPanelButtonTemplate")
    tab:SetSize(160, 26)
    tab:SetText(name)
    
    -- Keep the tabs above the content panels.
    if i == 1 then
        tab:SetPoint("TOPLEFT", MainFrame, "TOPLEFT", 20, -32)
    else
        tab:SetPoint("LEFT", MainFrame.Tabs[i-1], "RIGHT", 8, 0)
    end
    
    local tabIndex = i
    tab:SetScript("OnClick", function() SwitchToTab(tabIndex) end)
    MainFrame.Tabs[i] = tab

    -- Create the Panel Container where your options go
    local panel = CreateFrame("Frame", nil, MainFrame)
    panel:SetPoint("TOPLEFT", MainFrame, "TOPLEFT", 15, -68)
    panel:SetPoint("BOTTOMRIGHT", MainFrame, "BOTTOMRIGHT", -15, 15)
    panel:Hide()
    MainFrame.Panels[i] = panel
end

--- more functions


local function Checkbox(parent, name, y, text)
    assert(parent, "Checkbox requires a parent panel")
    local button = CreateFrame("CheckButton", name, parent, "UICheckButtonTemplate")
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, y)
    local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", button, "RIGHT", 4, 0)
    label:SetText(text)
    return button
end

-- All sliders use a snapping track and preserve independent original values.

local function GenericSlider(config)
    local parent = assert(config.parent, "GenericSlider requires a parent panel")
    local MIN, MAX, STEP, TRACK_WIDTH = config.min, config.max, config.step, 420
    assert(MAX > MIN and STEP > 0, "Invalid slider range or step")
    local offset = config.offset or 0
    local function Clamp(value) return math.max(MIN, math.min(MAX, value)) end
    local function Snap(value)
        return Clamp(MIN + math.floor((value - MIN) / STEP + 0.5) * STEP)
    end
    local function Position(value) return (Clamp(value) - MIN) / (MAX - MIN) * TRACK_WIDTH end

    local valueLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    valueLabel:SetPoint("TOP", parent, "TOP", 0, -48 - offset)
    local slider = CreateFrame("Frame", config.name, parent)
    slider:SetSize(TRACK_WIDTH, 38)
    slider:SetPoint("TOP", parent, "TOP", 0, -100 - offset)
    slider:EnableMouse(false)
    slider:EnableMouseWheel(false)
    local track = slider:CreateTexture(nil, "BACKGROUND")
    track:SetColorTexture(0.4, 0.4, 0.4, 1)
    track:SetSize(TRACK_WIDTH, 3)
    track:SetPoint("LEFT", slider, "LEFT", 0, 0)
    for value = MIN, MAX, STEP do
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
    thumb:SetSize(20, 20)
    local originalStar = slider:CreateTexture(nil, "OVERLAY")
    originalStar:SetTexture(assets .. "Star.tga")
    originalStar:SetSize(22, 22)
    local originalLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")

    local restore = CreateFrame("Button", config.restoreName, parent, "UIPanelButtonTemplate")
    restore:SetSize(180, 24)
    restore:SetPoint("TOP", parent, "TOP", 0, -70 - offset)
    restore:SetText("Restore original")
    restore:Disable()
    originalLabel:SetPoint("TOP", restore, "BOTTOM", 0, -8)
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
        slider:EnableMouseWheel(slider.available)
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
            ApplyValue(MIN + fraction * (MAX - MIN))
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
        local current = tonumber(ReadCVar(config.cvar))
        if current and delta ~= 0 then ApplyValue(Snap(current) + (delta > 0 and STEP or -STEP)) end
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

    return UpdateControls
end






-- Open to the first tab by default
SwitchToTab(1)

----------------------------------------------------
-- Build the panels here
----------------------------------------------------

-- Target Panel 1 (objects)
local text1 = MainFrame.Panels[1]:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
text1:SetPoint("TOPLEFT", 10, -10)
text1:SetText("In Game Objects")

local RefreshGround = GenericSlider({
    parent = MainFrame.Panels[1],
    name = "GraphicsTweaksDensitySlider",
    restoreName = "GraphicsTweaksRestoreOriginal",
    label = "Ground Effect Density", cvar = "groundEffectDensity",
    min = 16, max = 256, step = 16, offset = 0,
    savedKey = "previousGroundEffectDensity", overrideKey = "groundEffectOverride",
})
local RefreshWeather = GenericSlider({
    parent = MainFrame.Panels[1],
    name = "GraphicsTweaksWeatherSlider",
    restoreName = "GraphicsTweaksRestoreWeatherOriginal",
    label = "Weather Density", cvar = "weatherdensity",
    min = 0, max = 3, step = 1, offset = 100,
    savedKey = "previousWeatherDensity", overrideKey = "weatherDensityOverride",
})

local RefreshgroundEffectDist = GenericSlider({
    parent = MainFrame.Panels[1],
    name = "GraphicsgroundEffectDistSlider",
    restoreName = "GraphicsTweaksgroundEffectDistOriginal",
    label = "Ground Effect Distance", cvar = "groundEffectDist",
    min = 240, max = 500, step = 20, offset = 200,
    savedKey = "previousgroundEffectDist", overrideKey = "groundEffectDistOverride",
})

local RefreshViolenceLvl = GenericSlider({
    parent = MainFrame.Panels[1],
    name = "ViolenceLvlSlider",
    restoreName = "ViolenceLvlOriginal",
    label = "Violence Level", cvar = "violenceLevel",
    min = 0, max = 5, step = 1, offset = 300,
    savedKey = "previousViolenceLvl", overrideKey = "ViolenceLvlOverride",
})



-- Target Panel 2 (lighting)
local text2 = MainFrame.Panels[2]:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
text2:SetPoint("TOPLEFT", 10, -10)
text2:SetText("Lighting")

local RefreshSkyCloudLOD = GenericSlider({
    parent = MainFrame.Panels[2],
    name = "GraphicsTweaksSkyCloudLODSlider",
    restoreName = "GraphicsTweaksRestoreSkyCloudLODOriginal",
    label = "Sky Cloud Level of Detail", cvar = "SkyCloudLOD",
    min = 0, max = 3, step = 1, offset = 0,
    savedKey = "previousSkyCloudLOD", overrideKey = "SkyCloudLODOverride",
})


-- Target Panel 3 (rendering)
local text3 = MainFrame.Panels[3]:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
text3:SetPoint("TOPLEFT", 10, -10)
text3:SetText("Rendering")

local RefreshRenderFormat = GenericSlider({
    parent = MainFrame.Panels[3],
    name = "GraphicsTweaksRenderformat",
    restoreName = "GraphicsTweaksRestoreRenderformatOriginal",
    label = "Render Format", cvar = "renderformat",
    min = 1, max = 3, step = 1, offset = 0,
    savedKey = "previousRenderformat", overrideKey = "RenderformatOverride",
})
local sharpen = Checkbox(MainFrame.Panels[3], "GraphicsTweaksSharpen", -240, "Resample Always Sharpen")
sharpen:Disable()


--- update controls and load updates

UpdateControls = function()
    if not ready then return end
    RefreshGround()
    RefreshWeather()
    RefreshRenderFormat()
    RefreshgroundEffectDist()
    RefreshSkyCloudLOD()
    RefreshViolenceLvl()
    local sharpening = tonumber(ReadCVar("ResampleAlwaysSharpen"))
    sharpen:SetChecked(sharpening == 1)
    sharpen:SetEnabled(sharpening ~= nil)
end
MainFrame:SetScript("OnShow", UpdateControls)

--- push updates

sharpen:SetScript("OnClick", function(self)
    local value = self:GetChecked() and "1" or "0"
    if WriteCVar("ResampleAlwaysSharpen", value) then
        Message("Resample Always Sharpen = " .. (value == "1" and "ON" or "OFF"))
    end
    UpdateControls()
end)


----------------------------------------------------
-- CHAT COMMAND TO OPEN PANEL (/gt)
----------------------------------------------------
SlashCmdList["GRAPHICSTWEAKS"] = function()
    if MainFrame:IsShown() then MainFrame:Hide() else MainFrame:Show() end
end
SLASH_GRAPHICSTWEAKS1 = "/gt"

local relevantCVars = {
    groundeffectdensity = true,
    weatherdensity = true,
    renderformat = true,
    resamplealwayssharpen = true,
    groundEffectDist = true,
}

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("CVAR_UPDATE")
events:SetScript("OnEvent", function(_, event, cvarName)
    if event == "PLAYER_LOGIN" then
        Database()
        ready = true
        UpdateControls()
        
-- |c######## changes color of text |r  resets color    
        Message("Loaded. Type |cff00ff00/gt |rto open settings.")
    elseif ready and MainFrame:IsShown() and type(cvarName) == "string"
        and relevantCVars[string.lower(cvarName)] then
        UpdateControls()
    end
end)
