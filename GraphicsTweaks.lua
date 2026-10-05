-- Graphics Tweaks 1.2.0
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
frame:SetSize(560, 300)
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

-- A custom snapping track keeps the thumb and all 15 dots on the same
-- coordinate system, including on older clients with different slider APIs.
local MIN, MAX, STEP, TRACK_WIDTH = 32, 256, 16, 420
local assets = "Interface\\AddOns\\GraphicsTweaks\\Textures\\"
local function Clamp(value) return math.max(MIN, math.min(MAX, value)) end
local function Snap(value)
    return Clamp(MIN + math.floor((value - MIN) / STEP + 0.5) * STEP)
end
local function Position(value) return (Clamp(value) - MIN) / (MAX - MIN) * TRACK_WIDTH end

local densityLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
densityLabel:SetPoint("TOP", 0, -48)
local slider = CreateFrame("Frame", "GraphicsTweaksDensitySlider", frame)
slider:SetSize(TRACK_WIDTH, 38)
slider:SetPoint("TOPLEFT", 70, -100)
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
originalLabel:SetPoint("TOP", 0, -172)

local restore = CreateFrame("Button", "GraphicsTweaksRestoreOriginal", frame, "UIPanelButtonTemplate")
restore:SetSize(180, 24)
restore:SetPoint("TOP", 0, -199)
restore:SetText("Restore original")
local sharpen = Checkbox("GraphicsTweaksSharpen", -246, "Resample Always Sharpen")
local refreshing, applying = false, false
local UpdateControls

local function RememberOriginal(current)
    local db = Database()
    -- Reuse the value saved by 1.1.0, when available. Otherwise capture the
    -- current setting once, before the first slider change, even if it is 256.
    if tonumber(db.previousGroundEffectDensity) == nil and tonumber(current) ~= nil then
        db.previousGroundEffectDensity = current
    end
    return db.previousGroundEffectDensity
end

UpdateControls = function()
    if refreshing or applying then return end
    refreshing = true
    local current = ReadCVar("groundEffectDensity")
    local density = tonumber(current)
    local original = RememberOriginal(current)
    local baseline = tonumber(original)
    slider.available = density ~= nil
    slider:EnableMouse(slider.available)
    slider:EnableMouseWheel(slider.available)
    slider:SetAlpha(slider.available and 1 or 0.4)
    densityLabel:SetText("Ground Effect Density: " .. tostring(current or "unavailable"))
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
    local sharpening = tonumber(ReadCVar("ResampleAlwaysSharpen"))
    sharpen:SetChecked(sharpening == 1)
    sharpen:SetEnabled(sharpening ~= nil)
    refreshing = false
end

local function ApplyDensity(value)
    if refreshing or applying or not slider.available then return end
    value = Snap(value)
    local current = ReadCVar("groundEffectDensity")
    if tonumber(current) == value then return end
    RememberOriginal(current)
    applying = true
    local ok = WriteCVar("groundEffectDensity", value)
    applying = false
    if ok then
        Database().groundEffectOverride = tonumber(Database().previousGroundEffectDensity) ~= value
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
    local current = tonumber(ReadCVar("groundEffectDensity"))
    if current then ApplyDensity(Snap(current) + (delta > 0 and STEP or -STEP)) end
end)
restore:SetScript("OnClick", function()
    local original = Database().previousGroundEffectDensity
    if tonumber(original) ~= nil then
        applying = true
        local ok = WriteCVar("groundEffectDensity", original)
        applying = false
        if ok then
            Database().groundEffectOverride = false
            Message("Ground Effect Density restored to " .. tostring(original))
        end
    end
    UpdateControls()
end)

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
