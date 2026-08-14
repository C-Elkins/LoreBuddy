local LoreBuddyCore = _G.LoreBuddyCore or {}
_G.LoreBuddyCore = LoreBuddyCore

LoreBuddyCore.Addon = LoreBuddyCore.Addon or {}

-- Centralized visual styling so the whole addon can be reskinned from one
-- place. No UI is created here; this is just shared constants/helpers.
local Theme = {}

Theme.media = {
    portrait = "Interface/AddOns/LoreBuddy/Media/portrait.png",
    indicator = "Interface/AddOns/LoreBuddy/Media/lorebuddy-indicator.png",
    header = "Interface/AddOns/LoreBuddy/Media/lorebuddy-header.png",
}

Theme.colors = {
    gold = { 0.83, 0.68, 0.21 },
    parchment = { 0.90, 0.82, 0.65 },
    parchmentDark = { 0.16, 0.12, 0.08 },
    purple = { 0.35, 0.18, 0.55 },
    charcoal = { 0.10, 0.09, 0.08 },
    bronze = { 0.55, 0.42, 0.22 },
}

Theme.fonts = {
    title = "GameFontNormalLarge",
    heading = "GameFontNormal",
    body = "GameFontHighlightSmall",
}

-- A parchment/gold backdrop suitable for popups, the journal, and the
-- indicator's frame. Uses BackdropTemplate, correct for the modern client
-- engine TBC Anniversary runs on (see docs/TBC_ANNIVERSARY_COMPATIBILITY.md).
Theme.backdrop = {
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    edgeSize = 14,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
}

function Theme.applyPanelBackdrop(frame)
    if frame.SetBackdrop then
        frame:SetBackdrop(Theme.backdrop)
        frame:SetBackdropColor(Theme.colors.parchmentDark[1], Theme.colors.parchmentDark[2], Theme.colors.parchmentDark[3], 0.95)
        frame:SetBackdropBorderColor(Theme.colors.gold[1], Theme.colors.gold[2], Theme.colors.gold[3], 1)
    end
end

function Theme.styleHeading(fontString)
    fontString:SetTextColor(Theme.colors.gold[1], Theme.colors.gold[2], Theme.colors.gold[3])
end

function Theme.styleBody(fontString)
    fontString:SetTextColor(Theme.colors.parchment[1], Theme.colors.parchment[2], Theme.colors.parchment[3])
end

function Theme.setTexture(texture, path)
    if texture and texture.SetTexture then
        texture:SetTexture(path)
    end
end

-- Short fade in/out; falls back to an instant show/hide outside WoW or when
-- the fade helpers aren't available on the target client.
function Theme.fadeIn(frame, duration)
    if UIFrameFadeIn then
        frame:SetAlpha(0)
        frame:Show()
        UIFrameFadeIn(frame, duration or 0.2, 0, 1)
    else
        frame:SetAlpha(1)
        frame:Show()
    end
end

function Theme.fadeOut(frame, duration, onFinished)
    if UIFrameFadeOut then
        UIFrameFadeOut(frame, duration or 0.15, 1, 0)
        if C_Timer and C_Timer.After then
            C_Timer.After((duration or 0.15) + 0.02, function()
                frame:Hide()
                if onFinished then onFinished() end
            end)
        else
            frame:Hide()
            if onFinished then onFinished() end
        end
    else
        frame:Hide()
        if onFinished then onFinished() end
    end
end

LoreBuddyCore.Addon.Theme = Theme

-- Drag support with per-character position persistence. `state` is the
-- shared SavedVariables table; `key` identifies this frame (e.g. "indicator").
function Theme.makeDraggable(frame, state, key, defaultPoint)
    state.uiPositions = state.uiPositions or {}
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")

    local saved = state.uiPositions[key]
    frame:ClearAllPoints()
    if saved then
        frame:SetPoint(saved.point, UIParent, saved.relativePoint, saved.x, saved.y)
    elseif defaultPoint then
        frame:SetPoint(defaultPoint.point, UIParent, defaultPoint.relativePoint, defaultPoint.x, defaultPoint.y)
    end

    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint()
        state.uiPositions[key] = { point = point, relativePoint = relativePoint, x = x, y = y }
    end)
end
