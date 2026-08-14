local LoreBuddyCore = _G.LoreBuddyCore or {}
_G.LoreBuddyCore = LoreBuddyCore

LoreBuddyCore.Addon = LoreBuddyCore.Addon or {}
local Theme = LoreBuddyCore.Addon.Theme

local LoreBuddyIndicator = {}
LoreBuddyIndicator.__index = LoreBuddyIndicator

-- A tiny, always-present, draggable medallion. Glows briefly when new lore
-- is queued; never animates constantly and never blocks gameplay.
function LoreBuddyIndicator.new(state, onClick)
    local self = setmetatable({}, LoreBuddyIndicator)
    if not CreateFrame then
        return self -- outside WoW (e.g. Lua tests); UI stays inert
    end

    local frame = CreateFrame("Button", "LoreBuddyIndicatorFrame", UIParent, "BackdropTemplate")
    frame:SetSize(36, 36)
    frame:SetFrameStrata("LOW")
    Theme.applyPanelBackdrop(frame)
    Theme.makeDraggable(frame, state, "indicator", { point = "RIGHT", relativePoint = "RIGHT", x = -20, y = 0 })

    local portrait = frame:CreateTexture(nil, "ARTWORK")
    portrait:SetPoint("CENTER")
    portrait:SetSize(28, 28)
    if portrait.SetTexture then
        portrait:SetTexture("Interface/AddOns/LoreBuddy/Media/portrait.png")
    end

    local glow = frame:CreateTexture(nil, "OVERLAY")
    glow:SetPoint("CENTER")
    glow:SetSize(40, 40)
    if glow.SetColorTexture then
        glow:SetColorTexture(Theme.colors.purple[1], Theme.colors.purple[2], Theme.colors.purple[3], 0.6)
    end
    glow:Hide()

    frame:SetScript("OnClick", function()
        self:clearGlow()
        if onClick then onClick() end
    end)

    self.frame = frame
    self.glow = glow
    return self
end

function LoreBuddyIndicator:showGlow()
    if not self.glow then return end
    self.glow:Show()
    if C_Timer and C_Timer.After then
        C_Timer.After(2, function()
            self:clearGlow()
        end)
    end
end

function LoreBuddyIndicator:clearGlow()
    if self.glow then
        self.glow:Hide()
    end
end

LoreBuddyCore.Addon.LoreBuddyIndicator = LoreBuddyIndicator
