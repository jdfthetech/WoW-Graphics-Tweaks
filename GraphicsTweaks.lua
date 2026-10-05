-- Graphics Tweaks 0.0.5
local function Database()
    if type(GraphicsTweaksDB) ~= "table" then
        GraphicsTweaksDB = {}
    end
    return GraphicsTweaksDB
end

local function Message(text)
    print("|cff00ff00Graphics Tweaks:|r " .. text)
end

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

local frame = CreateFrame("Frame", "GraphicsTweaksFrame", UIParent,
    "BasicFrameTemplateWithInset")
frame:SetSize(560, 700)
frame:SetPoint("CENTER")
frame:SetMovable(true)
frame:SetClampedToScreen(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
frame:Hide()
UISpecialFrames = UISpecialFrames or {}
table.insert(UISpecialFrames, "GraphicsTweaksFrame")

local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
title:SetPoint("TOP", 0, -8)
title:SetText("Graphics Tweaks")

local function Checkbox(name, y, text)
    local button = CreateFrame("CheckButton", name, frame, "UICheckButtonTemplate")
    button:SetPoint("TOPLEFT", 20, y)
    local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", button, "RIGHT", 4, 0)
    label:SetText(text)
    return button
end

-- Both sliders use the same snapping track and independent saved originals.
local function GenericSlider(config)
    local MIN, MAX, STEP, TRACK_WIDTH = config.min, config.max, config.step, 420
    local assets = "Interface\\AddOns\\GraphicsTweaks\\Textures\\"
    local function Clamp(value) return math.max(MIN, math.min(MAX, value)) end
    local function Snap(value)
        return Clamp(MIN + math.floor((value - MIN) / STEP + 0.5) * STEP)
    end
    local function Position(value) return (Clamp(value) - MIN) / (MAX - MIN) * TRACK_WIDTH end

    local densityLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    densityLabel:SetPoint("TOP", 0, -48 - config.offset)
    local slider = CreateFrame("Frame", config.name, frame)
    slider:SetSize(TRACK_WIDTH, 38)
    slider:SetPoint("TOPLEFT", 70, -100 - config.offset)
    slider:EnableMouse(true)
    slider:EnableMouseWheel(true)
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
    local originalLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    originalLabel:SetPoint("TOP", 0, -172 - config.offset)

    local restore = CreateFrame("Button", config.restoreName, frame, "UIPanelButtonTemplate")
    restore:SetSize(180, 24)
    restore:SetPoint("TOP", 0, -199 - config.offset)
    restore:SetText("Restore original")
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
        if refreshing or applying then return end
        refreshing = true
        local current = ReadCVar(config.cvar)
        local density = tonumber(current)
        local original = RememberOriginal(current)
        local baseline = tonumber(original)
        slider.available = density ~= nil
        slider:EnableMouse(slider.available)
        slider:EnableMouseWheel(slider.available)
        slider:SetAlpha(slider.available and 1 or 0.4)
        densityLabel:SetText(config.label .. ": " .. tostring(current or "unavailable"))
        thumb:ClearAllPoints()
        thumb:SetPoint("CENTER", slider, "LEFT", Position(Snap(density or MIN)), 0)
        originalStar:ClearAllPoints()
        if baseline then
            originalStar:SetPoint("CENTER", slider, "LEFT", Position(baseline), 26)
            originalStar:Show()
            local suffix = ""
            if baseline < MIN then suffix = " (below slider range)"
            elseif baseline > MAX then suffix = " (above slider range)" end
            originalLabel:SetText("|cffffff00Original density: " .. tostring(original) .. suffix .. "|r")
        else
            originalStar:Hide()
            originalLabel:SetText("Original density unavailable")
        end
        restore:SetEnabled(density ~= nil and baseline ~= nil and density ~= baseline)
        refreshing = false
    end

    local function ApplyDensity(value)
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
            ApplyDensity(MIN + fraction * (MAX - MIN))
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
        if current and delta ~= 0 then ApplyDensity(Snap(current) + (delta > 0 and STEP or -STEP)) end
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

local RefreshGround = GenericSlider({
    name = "GraphicsTweaksDensitySlider",
    restoreName = "GraphicsTweaksRestoreOriginal",
    label = "Ground Effect Density", cvar = "groundEffectDensity",
    min = 16, max = 256, step = 16, offset = 0,
    savedKey = "previousGroundEffectDensity", overrideKey = "groundEffectOverride",
})
local RefreshWeather = GenericSlider({
    name = "GraphicsTweaksWeatherSlider",
    restoreName = "GraphicsTweaksRestoreWeatherOriginal",
    label = "Weather Density", cvar = "weatherdensity",
    min = 0, max = 3, step = 1, offset = 204,
    savedKey = "previousWeatherDensity", overrideKey = "weatherDensityOverride",
})
local Renderformat = GenericSlider({
    name = "GraphicsTweaksRenderformat",
    restoreName = "GraphicsTweaksRestoreRenderformatOriginal",
    label = "Render Format", cvar = "renderformat",
    min = 1, max = 3, step = 1, offset = 408,
    savedKey = "previousRenderformat", overrideKey = "RenderformatOverride",
})
local sharpen = Checkbox("GraphicsTweaksSharpen", -660, "Resample Always Sharpen")
local function UpdateControls()
    RefreshGround()
    RefreshWeather()
    Renderformat()
    local sharpening = tonumber(ReadCVar("ResampleAlwaysSharpen"))
    sharpen:SetChecked(sharpening == 1)
    sharpen:SetEnabled(sharpening ~= nil)
end

sharpen:SetScript("OnClick", function(self)
    local value = self:GetChecked() and "1" or "0"
    if WriteCVar("ResampleAlwaysSharpen", value) then
        Message("Resample Always Sharpen = " .. (value == "1" and "ON" or "OFF"))
    end
    UpdateControls()
end)

frame:SetScript("OnShow", UpdateControls)
SLASH_GRAPHICSTWEAKS1 = "/gt"
SLASH_GRAPHICSTWEAKS2 = "/graphicstweaks"
SlashCmdList["GRAPHICSTWEAKS"] = function()
    if frame:IsShown() then frame:Hide() else frame:Show() end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("CVAR_UPDATE")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        Database()
        Message("Loaded. Type /gt to open settings.")
    elseif frame:IsShown() then
        UpdateControls()
    end
end)
