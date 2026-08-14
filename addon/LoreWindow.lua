local LoreBuddyCore = _G.LoreBuddyCore or {}
_G.LoreBuddyCore = LoreBuddyCore

LoreBuddyCore.Addon = LoreBuddyCore.Addon or {}
local LoreWindow = {}
LoreWindow.__index = LoreWindow

-- v0.1 window: a minimal search box plus a detail readout. This is the
-- in-game equivalent of the desktop Explorer, scoped down for a first pass.
function LoreWindow.new(engine)
    local self = setmetatable({ engine = engine }, LoreWindow)
    if not CreateFrame then
        return self -- outside WoW (e.g. Lua tests); UI stays inert
    end

    local frame = CreateFrame("Frame", "LoreBuddyWindowFrame", UIParent, "BackdropTemplate")
    frame:SetSize(360, 420)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()
    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface/Tooltips/UI-Tooltip-Background",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
    end

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -14)
    title:SetText("LoreBuddy")

    if CreateFrame then
        local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
        closeButton:SetPoint("TOPRIGHT", -4, -4)
        closeButton:SetScript("OnClick", function()
            frame:Hide()
        end)
    end

    local searchBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    searchBox:SetSize(300, 20)
    searchBox:SetPoint("TOP", title, "BOTTOM", 0, -14)
    if searchBox.SetAutoFocus then
        searchBox:SetAutoFocus(false)
    end

    local resultLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    resultLabel:SetPoint("TOPLEFT", searchBox, "BOTTOMLEFT", 0, -12)
    resultLabel:SetJustifyH("LEFT")

    local detail = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    detail:SetPoint("TOPLEFT", resultLabel, "BOTTOMLEFT", 0, -8)
    detail:SetPoint("BOTTOMRIGHT", -16, 16)
    detail:SetJustifyH("LEFT")
    detail:SetJustifyV("TOP")
    if detail.SetWordWrap then
        detail:SetWordWrap(true)
    end

    searchBox:SetScript("OnEnterPressed", function(box)
        self:search(box:GetText())
        box:ClearFocus()
    end)

    self.frame = frame
    self.searchBox = searchBox
    self.resultLabel = resultLabel
    self.detail = detail
    return self
end

function LoreWindow:search(query)
    if not self.engine or not query or query == "" then
        return
    end
    local matches = self.engine:findCharacter(query)
    if #matches == 0 then
        matches = self.engine.entities:find(query)
    end
    if #matches == 0 then
        self.resultLabel:SetText('No matches for "' .. query .. '"')
        self.detail:SetText("")
        return
    end
    local entity = matches[1].entity
    self.resultLabel:SetText(entity.name)
    local lore = self.engine:findLoreAbout(entity.name, { detailLevel = "quick" })
    local text = ""
    if lore[1] then
        text = lore[1].statement.text
    end
    self.detail:SetText(text)
end

function LoreWindow:toggle()
    if not self.frame then
        return
    end
    if self.frame:IsShown() then
        self.frame:Hide()
    else
        self.frame:Show()
    end
end

LoreBuddyCore.Addon.LoreWindow = LoreWindow
