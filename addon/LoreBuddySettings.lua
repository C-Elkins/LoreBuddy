local LoreBuddyCore = _G.LoreBuddyCore or {}
_G.LoreBuddyCore = LoreBuddyCore

LoreBuddyCore.Addon = LoreBuddyCore.Addon or {}
local Theme = LoreBuddyCore.Addon.Theme
local LoreBuddySettings = {}
LoreBuddySettings.__index = LoreBuddySettings

local SPOILER_OPTIONS = { "no_spoilers", "context_only", "moderate", "full_lore", "show_everything" }

local function setControlsFromState(self)
    if not self.frame or not self.engine then
        return
    end

    local spoilerValue = self.engine.discovery.state.spoilerPreference or "moderate"
    local spoilLabel = self.spoilerLabel
    if spoilLabel then
        spoilLabel:SetText("Spoiler level: " .. spoilerValue)
    end

    if self.combatCheck then
        self.combatCheck:SetChecked(self.state.suppressInCombat ~= false)
    end

    if self.mascotCheck then
        self.mascotCheck:SetChecked(self.state.mascotEnabled ~= false)
    end
end

-- Basic settings panel (first milestone scope only): spoiler level, combat
-- suppression, and mascot enable. Reads/writes engine.discovery.state and
-- the shared character-state table directly; no lore data lives here.
function LoreBuddySettings.new(engine, state)
    local self = setmetatable({ engine = engine, state = state }, LoreBuddySettings)
    if not CreateFrame then
        return self -- outside WoW (e.g. Lua tests); UI stays inert
    end

    local frame = CreateFrame("Frame", "LoreBuddySettingsFrame", UIParent, "BackdropTemplate")
    frame:SetSize(260, 200)
    frame:SetFrameStrata("DIALOG")
    Theme.applyPanelBackdrop(frame)
    Theme.makeDraggable(frame, state, "settings", { point = "CENTER", relativePoint = "CENTER", x = 40, y = 40 })
    frame:Hide()

    local title = frame:CreateFontString(nil, "OVERLAY", Theme.fonts.heading)
    title:SetPoint("TOP", 0, -12)
    title:SetText("Lore Buddy Settings")
    Theme.styleHeading(title)

    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", -2, -2)
    closeButton:SetScript("OnClick", function()
        frame:Hide()
    end)

    local spoilerLabel = frame:CreateFontString(nil, "OVERLAY", Theme.fonts.body)
    spoilerLabel:SetPoint("TOPLEFT", 14, -40)
    Theme.styleBody(spoilerLabel)
    self.spoilerLabel = spoilerLabel

    local spoilerButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    spoilerButton:SetSize(120, 22)
    spoilerButton:SetPoint("TOPLEFT", spoilerLabel, "BOTTOMLEFT", 0, -6)
    spoilerButton:SetText("Cycle")
    spoilerButton:SetScript("OnClick", function()
        local current = engine.discovery.state.spoilerPreference or "moderate"
        local index = 1
        for i, option in ipairs(SPOILER_OPTIONS) do
            if option == current then index = i end
        end
        local nextOption = SPOILER_OPTIONS[(index % #SPOILER_OPTIONS) + 1]
        engine.discovery.state.spoilerPreference = nextOption
        spoilerLabel:SetText("Spoiler level: " .. nextOption)
    end)

    local combatCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    combatCheck:SetPoint("TOPLEFT", spoilerButton, "BOTTOMLEFT", 0, -14)
    self.combatCheck = combatCheck
    combatCheck:SetScript("OnClick", function(checkbox)
        state.suppressInCombat = checkbox:GetChecked() and true or false
    end)
    local combatLabel = frame:CreateFontString(nil, "OVERLAY", Theme.fonts.body)
    combatLabel:SetPoint("LEFT", combatCheck, "RIGHT", 2, 0)
    combatLabel:SetText("Suppress popups in combat")
    Theme.styleBody(combatLabel)

    local mascotCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    mascotCheck:SetPoint("TOPLEFT", combatCheck, "BOTTOMLEFT", 0, -6)
    self.mascotCheck = mascotCheck
    mascotCheck:SetScript("OnClick", function(checkbox)
        state.mascotEnabled = checkbox:GetChecked() and true or false
    end)
    local mascotLabel = frame:CreateFontString(nil, "OVERLAY", Theme.fonts.body)
    mascotLabel:SetPoint("LEFT", mascotCheck, "RIGHT", 2, 0)
    mascotLabel:SetText("Show mascot indicator")
    Theme.styleBody(mascotLabel)

    self.frame = frame
    setControlsFromState(self)
    return self
end

function LoreBuddySettings:registerInterfaceOptions()
    local addCategory = _G["InterfaceOptions_AddCategory"]
    if not addCategory then
        return
    end

    local panel = CreateFrame("Frame", "LoreBuddyInterfaceOptions")
    panel.name = "LoreBuddy"
    panel.parent = "AddOns"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Lore Buddy")

    local icon = panel:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPRIGHT", -16, -12)
    icon:SetSize(28, 28)
    Theme.setTexture(icon, Theme.media.indicator)

    local summary = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    summary:SetPoint("TOPLEFT", 16, -52)
    summary:SetPoint("RIGHT", -16, 0)
    summary:SetText("Quiet lore discovery, optional settings, and compatibility-safe UI defaults for TBC Anniversary.")
    summary:SetJustifyH("LEFT")

    local check = CreateFrame("CheckButton", nil, panel, "OptionsCheckButtonTemplate")
    check:SetPoint("TOPLEFT", 16, -110)
    check:SetChecked(self.state.suppressInCombat ~= false)
    check:SetScript("OnClick", function(checkbox)
        self.state.suppressInCombat = checkbox:GetChecked() and true or false
    end)
    _G[check:GetName() .. "Text"]:SetText("Suppress popups in combat")

    local mascot = CreateFrame("CheckButton", nil, panel, "OptionsCheckButtonTemplate")
    mascot:SetPoint("TOPLEFT", 16, -150)
    mascot:SetChecked(self.state.mascotEnabled ~= false)
    mascot:SetScript("OnClick", function(checkbox)
        self.state.mascotEnabled = checkbox:GetChecked() and true or false
    end)
    _G[mascot:GetName() .. "Text"]:SetText("Show mascot indicator")

    panel.okay = function() end
    panel.cancel = function() end
    panel.default = function() end

    addCategory(panel)
    self.interfacePanel = panel
end

function LoreBuddySettings:toggle()
    if not self.frame then
        return
    end
    if self.frame:IsShown() then
        self.frame:Hide()
    else
        self.frame:Show()
    end
end

LoreBuddyCore.Addon.LoreBuddySettings = LoreBuddySettings
