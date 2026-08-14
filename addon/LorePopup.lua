local LoreBuddyCore = _G.LoreBuddyCore or {}
_G.LoreBuddyCore = LoreBuddyCore

LoreBuddyCore.Addon = LoreBuddyCore.Addon or {}
local LorePopup = {}
LorePopup.__index = LorePopup

-- v0.1 popup: a small auto-hiding frame that announces one piece of lore.
function LorePopup.new()
    local self = setmetatable({}, LorePopup)
    if not CreateFrame then
        return self -- outside WoW (e.g. Lua tests); UI stays inert
    end

    local frame = CreateFrame("Frame", "LoreBuddyPopupFrame", UIParent, "BackdropTemplate")
    frame:SetSize(320, 90)
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

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 12, -10)
    title:SetPoint("TOPRIGHT", -12, -10)
    title:SetJustifyH("LEFT")

    local body = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    body:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    body:SetPoint("BOTTOMRIGHT", -12, 10)
    body:SetJustifyH("LEFT")
    body:SetJustifyV("TOP")
    if body.SetWordWrap then
        body:SetWordWrap(true)
    end

    frame:SetScript("OnMouseUp", function()
        frame:Hide()
    end)

    self.frame = frame
    self.title = title
    self.body = body
    return self
end

function LorePopup:show(entity, text, duration)
    if not self.frame then
        return
    end
    self.title:SetText(entity and entity.name or "LoreBuddy")
    self.body:SetText(text or "")
    self.frame:Show()
    if self.hideTimer and self.hideTimer.Cancel then
        self.hideTimer:Cancel()
    end
    if C_Timer and C_Timer.NewTimer then
        self.hideTimer = C_Timer.NewTimer(duration or 10, function()
            self.frame:Hide()
        end)
    end
end

function LorePopup:hide()
    if self.frame then
        self.frame:Hide()
    end
end

LoreBuddyCore.Addon.LorePopup = LorePopup
