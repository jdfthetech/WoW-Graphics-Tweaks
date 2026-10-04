-- Graphics Tweaks 1.1.0
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
frame:SetSize(390, 200)
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

local groundEffects = Checkbox("GraphicsTweaksGroundEffects", -45,
    "Ground Effect Density 256")
local sharpen = Checkbox("GraphicsTweaksSharpen", -85,
    "Resample Always Sharpen")
local status = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
status:SetPoint("TOPLEFT", 26, -135)
status:SetWidth(338)
status:SetJustifyH("LEFT")

local function UpdateCheckboxes()
    local density = ReadCVar("groundEffectDensity")
    local sharpening = ReadCVar("ResampleAlwaysSharpen")
    groundEffects:SetChecked(tonumber(density) == 256)
    sharpen:SetChecked(tonumber(sharpening) == 1)
    groundEffects:SetEnabled(tonumber(density) ~= nil)
    sharpen:SetEnabled(tonumber(sharpening) ~= nil)
    local previous = Database().previousGroundEffectDensity
    status:SetText("Current density: " .. tostring(density or "unavailable") ..
        "\nSaved density: " .. tostring(previous or "none yet"))
end

groundEffects:SetScript("OnClick", function(self)
    local db = Database()
    if self:GetChecked() then
        local current = ReadCVar("groundEffectDensity")
        if tonumber(current) == nil then
            Message("Ground effect density is unavailable on this client.")
        else
            -- Preserve the exact value before applying the override. Do not
            -- replace a saved original with 256, including after a reload.
            if tonumber(current) ~= 256 then
                db.previousGroundEffectDensity = current
            end
            if WriteCVar("groundEffectDensity", "256") then
                db.groundEffectOverride = true
                Message("Ground Effect Density = 256")
            end
        end
    else
        local previous = db.previousGroundEffectDensity
        if tonumber(previous) ~= nil then
            if WriteCVar("groundEffectDensity", previous) then
                db.groundEffectOverride = false
                Message("Ground Effect Density restored to " .. tostring(previous))
            end
        else
            Message("No previous density was saved. Set your preferred density " ..
                "in graphics settings before enabling this override.")
        end
    end
    UpdateCheckboxes()
end)

sharpen:SetScript("OnClick", function(self)
    local value = self:GetChecked() and "1" or "0"
    if WriteCVar("ResampleAlwaysSharpen", value) then
        Message("Resample Always Sharpen = " .. (value == "1" and "ON" or "OFF"))
    end
    UpdateCheckboxes()
end)

frame:SetScript("OnShow", UpdateCheckboxes)
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
        UpdateCheckboxes()
    end
end)
