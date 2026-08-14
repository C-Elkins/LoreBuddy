local LoreBuddyCore = _G.LoreBuddyCore or {}
_G.LoreBuddyCore = LoreBuddyCore

LoreBuddyCore.Addon = LoreBuddyCore.Addon or {}
local DiscoveryToast = {}
DiscoveryToast.__index = DiscoveryToast

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

-- v0.1 "reward" card: a richer notification than the plain LorePopup,
-- shown specifically for first-time discoveries. onRead/onLater are
-- callbacks invoked with the discovered entity.
function DiscoveryToast.new(onRead, onLater)
    local self = setmetatable({ onRead = onRead, onLater = onLater }, DiscoveryToast)
    if not CreateFrame then
        return self -- outside WoW (e.g. Lua tests); UI stays inert
    end

    local frame = CreateFrame("Frame", "LoreBuddyDiscoveryToast", UIParent, "BackdropTemplate")
    frame:SetSize(300, 160)
    frame:SetPoint("TOP", UIParent, "TOP", 0, -140)
    frame:SetFrameStrata("HIGH")
    frame:Hide()
    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface/Tooltips/UI-Tooltip-Background",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            edgeSize = 12,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
    end

    local header = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOP", 0, -10)
    header:SetText("NEW LORE DISCOVERED!")

    local typeLine = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    typeLine:SetPoint("TOPLEFT", 12, -32)
    typeLine:SetJustifyH("LEFT")

    local nameLine = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameLine:SetPoint("TOPLEFT", typeLine, "BOTTOMLEFT", 0, -4)
    nameLine:SetJustifyH("LEFT")

    local connectionLine = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    connectionLine:SetPoint("TOPLEFT", nameLine, "BOTTOMLEFT", 0, -6)
    connectionLine:SetJustifyH("LEFT")

    local descriptionLine = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    descriptionLine:SetPoint("TOPLEFT", connectionLine, "BOTTOMLEFT", 0, -8)
    descriptionLine:SetPoint("RIGHT", -12, 0)
    descriptionLine:SetJustifyH("LEFT")
    descriptionLine:SetJustifyV("TOP")
    if descriptionLine.SetWordWrap then
        descriptionLine:SetWordWrap(true)
    end

    local readButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    readButton:SetSize(80, 22)
    readButton:SetPoint("BOTTOMLEFT", 12, 10)
    readButton:SetText("Read")

    local laterButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    laterButton:SetSize(80, 22)
    laterButton:SetPoint("LEFT", readButton, "RIGHT", 8, 0)
    laterButton:SetText("Later")

    readButton:SetScript("OnClick", function()
        local entity = self.currentEntity
        frame:Hide()
        if self.onRead and entity then
            self.onRead(entity)
        end
    end)
    laterButton:SetScript("OnClick", function()
        local entity = self.currentEntity
        frame:Hide()
        if self.onLater and entity then
            self.onLater(entity)
        end
    end)

    self.frame = frame
    self.header = header
    self.typeLine = typeLine
    self.nameLine = nameLine
    self.connectionLine = connectionLine
    self.descriptionLine = descriptionLine
    self.readButton = readButton
    self.laterButton = laterButton
    return self
end

function DiscoveryToast:show(entity, connectionEntity, text)
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
    self.frame:Show()

    if self.hideTimer and self.hideTimer.Cancel then
        self.hideTimer:Cancel()
    end
    if C_Timer and C_Timer.NewTimer then
        -- Safety net: if the player ignores both buttons, treat it as "Later".
        self.hideTimer = C_Timer.NewTimer(30, function()
            self.frame:Hide()
            if self.onLater and self.currentEntity == entity then
                self.onLater(entity)
            end
        end)
    end
end

LoreBuddyCore.Addon.DiscoveryToast = DiscoveryToast
