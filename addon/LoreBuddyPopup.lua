local LoreBuddyCore = _G.LoreBuddyCore or {}
_G.LoreBuddyCore = LoreBuddyCore

LoreBuddyCore.Addon = LoreBuddyCore.Addon or {}
local Theme = LoreBuddyCore.Addon.Theme
local LoreBuddyPopup = {}
LoreBuddyPopup.__index = LoreBuddyPopup

local TYPE_META = {
    character = { icon = "\240\159\147\150", label = "CHARACTER" },
    creature = { icon = "\240\159\147\150", label = "CHARACTER" },
    location = { icon = "\240\159\147\141", label = "LOCATION" },
    zone = { icon = "\240\159\147\141", label = "LOCATION" },
    dungeon = { icon = "\240\159\147\141", label = "LOCATION" },
    raid = { icon = "\240\159\147\141", label = "LOCATION" },
    event = { icon = "\240\159\147\156", label = "EVENT" },
    faction = { icon = "\240\159\155\161", label = "FACTION" },
    organization = { icon = "\240\159\155\161", label = "FACTION" },
    item = { icon = "\240\159\151\161", label = "ITEM" },
    quest = { icon = "\226\157\148", label = "QUEST" }
}
local DEFAULT_META = { icon = "\240\159\147\150", label = "LORE" }

-- The main gameplay UI: a small parchment card that tempts rather than
-- lectures. Never covers the center of the screen by default; draggable,
-- position persisted. onRead/onLater are invoked with the discovered entity.
function LoreBuddyPopup.new(state, onRead, onLater)
    local self = setmetatable({ onRead = onRead, onLater = onLater }, LoreBuddyPopup)
    if not CreateFrame then
        return self -- outside WoW (e.g. Lua tests); UI stays inert
    end

    local frame = CreateFrame("Frame", "LoreBuddyPopupFrame", UIParent, "BackdropTemplate")
    frame:SetSize(300, 160)
    frame:SetFrameStrata("HIGH")
    Theme.applyPanelBackdrop(frame)
    Theme.makeDraggable(frame, state, "popup", { point = "BOTTOMRIGHT", relativePoint = "BOTTOMRIGHT", x = -30, y = 30 })
    frame:Hide()

    local portrait = frame:CreateTexture(nil, "ARTWORK")
    portrait:SetSize(36, 36)
    portrait:SetPoint("TOPLEFT", 10, -10)
    if portrait.SetTexture then
        portrait:SetTexture("Interface/AddOns/LoreBuddy/Media/portrait.png")
    end

    local header = frame:CreateFontString(nil, "OVERLAY", Theme.fonts.heading)
    header:SetPoint("TOPLEFT", portrait, "TOPRIGHT", 8, -2)
    header:SetText("NEW LORE DISCOVERED")
    Theme.styleHeading(header)

    local typeLine = frame:CreateFontString(nil, "OVERLAY", Theme.fonts.body)
    typeLine:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -6)
    typeLine:SetJustifyH("LEFT")
    Theme.styleBody(typeLine)

    local nameLine = frame:CreateFontString(nil, "OVERLAY", Theme.fonts.heading)
    nameLine:SetPoint("TOPLEFT", typeLine, "BOTTOMLEFT", 0, -4)
    nameLine:SetJustifyH("LEFT")
    Theme.styleHeading(nameLine)

    local connectionLine = frame:CreateFontString(nil, "OVERLAY", Theme.fonts.body)
    connectionLine:SetPoint("TOPLEFT", portrait, "BOTTOMLEFT", 0, -8)
    connectionLine:SetPoint("RIGHT", -10, 0)
    connectionLine:SetJustifyH("LEFT")
    Theme.styleBody(connectionLine)

    local descriptionLine = frame:CreateFontString(nil, "OVERLAY", Theme.fonts.body)
    descriptionLine:SetPoint("TOPLEFT", connectionLine, "BOTTOMLEFT", 0, -8)
    descriptionLine:SetPoint("RIGHT", -10, 0)
    descriptionLine:SetJustifyH("LEFT")
    descriptionLine:SetJustifyV("TOP")
    if descriptionLine.SetWordWrap then
        descriptionLine:SetWordWrap(true)
    end
    Theme.styleBody(descriptionLine)

    local readButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    readButton:SetSize(90, 22)
    readButton:SetPoint("BOTTOMLEFT", 10, 10)
    readButton:SetText("Read More")

    local laterButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    laterButton:SetSize(70, 22)
    laterButton:SetPoint("LEFT", readButton, "RIGHT", 6, 0)
    laterButton:SetText("Later")

    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", -2, -2)
    closeButton:SetScript("OnClick", function()
        Theme.fadeOut(frame, 0.15)
    end)

    readButton:SetScript("OnClick", function()
        local entity = self.currentEntity
        Theme.fadeOut(frame, 0.15, function()
            if self.onRead and entity then self.onRead(entity) end
        end)
    end)
    laterButton:SetScript("OnClick", function()
        local entity = self.currentEntity
        Theme.fadeOut(frame, 0.15, function()
            if self.onLater and entity then self.onLater(entity) end
        end)
    end)

    self.frame = frame
    self.typeLine = typeLine
    self.nameLine = nameLine
    self.connectionLine = connectionLine
    self.descriptionLine = descriptionLine
    self.readButton = readButton
    self.laterButton = laterButton
    return self
end

function LoreBuddyPopup:show(entity, connectionEntity, text)
    if not self.frame then
        return
    end
    self.currentEntity = entity
    local meta = TYPE_META[entity.type] or DEFAULT_META
    self.typeLine:SetText(meta.icon .. " " .. meta.label)
    self.nameLine:SetText(entity.name)
    if connectionEntity then
        self.connectionLine:SetText("\240\159\148\151 CONNECTION: " .. connectionEntity.name)
    else
        self.connectionLine:SetText("")
    end
    self.descriptionLine:SetText(text or "")
    Theme.fadeIn(self.frame, 0.2)

    if self.hideTimer and self.hideTimer.Cancel then
        self.hideTimer:Cancel()
    end
    if C_Timer and C_Timer.NewTimer then
        -- Safety net: if the player ignores every button, treat it as "Later".
        self.hideTimer = C_Timer.NewTimer(30, function()
            Theme.fadeOut(self.frame, 0.15, function()
                if self.onLater and self.currentEntity == entity then
                    self.onLater(entity)
                end
            end)
        end)
    end
end

LoreBuddyCore.Addon.LoreBuddyPopup = LoreBuddyPopup
