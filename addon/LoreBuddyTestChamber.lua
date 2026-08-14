local LoreBuddyCore = _G.LoreBuddyCore or {}
_G.LoreBuddyCore = LoreBuddyCore

LoreBuddyCore.Addon = LoreBuddyCore.Addon or {}
local Theme = LoreBuddyCore.Addon.Theme
local LoreBuddyTestChamber = {}
LoreBuddyTestChamber.__index = LoreBuddyTestChamber

local function firstEntityOfType(engine, entityType)
    for _, entity in ipairs(engine.dataset.entities or {}) do
        if entity.type == entityType then
            return entity
        end
    end
    return nil
end

local function firstRelationship(engine)
    return engine.dataset.relationships and engine.dataset.relationships[1] or nil
end

-- /lorebuddy test: a developer-only panel to manually trigger every UI
-- surface with real dataset entities, so the UI can be iterated on without
-- hunting for live triggers in the world. Not part of normal play.
function LoreBuddyTestChamber.new(engine, popup, journal, indicator, combatQueue, state)
    local self = setmetatable({ engine = engine, popup = popup, journal = journal, indicator = indicator, combatQueue = combatQueue, state = state }, LoreBuddyTestChamber)
    if not CreateFrame then
        return self -- outside WoW (e.g. Lua tests); UI stays inert
    end

    local frame = CreateFrame("Frame", "LoreBuddyTestChamberFrame", UIParent, "BackdropTemplate")
    frame:SetSize(220, 320)
    frame:SetPoint("LEFT", 20, 0)
    frame:SetFrameStrata("DIALOG")
    Theme.applyPanelBackdrop(frame)
    frame:Hide()

    local title = frame:CreateFontString(nil, "OVERLAY", Theme.fonts.heading)
    title:SetPoint("TOP", 0, -10)
    title:SetText("Lore Buddy Test Chamber")
    Theme.styleHeading(title)

    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", -2, -2)
    closeButton:SetScript("OnClick", function() frame:Hide() end)

    local buttons = {
        { text = "Test Popup (Character)", action = function() self:testPopup("character") end },
        { text = "Test New Location", action = function() self:testPopup("location") end },
        { text = "Test Connection", action = function() self:testConnection() end },
        { text = "Test Journal", action = function() self.journal:show() end },
        { text = "Test Long Lore (Deep Dive)", action = function() self:testDeepDive() end },
        { text = "Test Combat Queue", action = function() self:testCombatQueue() end },
        { text = "Reset Positions", action = function() self:resetPositions() end },
    }

    local anchor = title
    for _, entry in ipairs(buttons) do
        local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        button:SetSize(190, 22)
        button:SetPoint("TOP", anchor, "BOTTOM", 0, anchor == title and -14 or -6)
        button:SetText(entry.text)
        button:SetScript("OnClick", entry.action)
        anchor = button
    end

    self.frame = frame
    return self
end

function LoreBuddyTestChamber:testPopup(entityType)
    local entity = firstEntityOfType(self.engine, entityType)
    if not entity then
        return
    end
    if self.indicator then self.indicator:showGlow() end
    self.popup:show(entity, nil, "This is a test popup triggered from the Test Chamber.")
end

function LoreBuddyTestChamber:testConnection()
    local relationship = firstRelationship(self.engine)
    if not relationship then
        return
    end
    local subject = self.engine.entities:get(relationship.subjectId)
    local object = self.engine.entities:get(relationship.objectId)
    if not subject or not object then
        return
    end
    if self.indicator then self.indicator:showGlow() end
    self.popup:show(subject, object, "You've encountered both of these. Here's a test connection.")
end

function LoreBuddyTestChamber:testDeepDive()
    local entity = firstEntityOfType(self.engine, "character") or (self.engine.dataset.entities or {})[1]
    if not entity then
        return
    end
    self.journal:selectEntity(entity.id)
    self.journal:setMode("deepdive")
    self.journal:show()
end

function LoreBuddyTestChamber:testCombatQueue()
    if self.combatQueue then
        self.combatQueue:simulateQueuedDiscovery()
    end
end

function LoreBuddyTestChamber:resetPositions()
    if not self.state or not self.state.uiPositions then
        return
    end
    for _, key in ipairs({ "indicator", "popup", "journal", "settings" }) do
        self.state.uiPositions[key] = nil
    end
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("LoreBuddy: positions reset, reload UI (/reload) to apply.")
    end
end

function LoreBuddyTestChamber:toggle()
    if not self.frame then
        return
    end
    if self.frame:IsShown() then
        self.frame:Hide()
    else
        self.frame:Show()
    end
end

LoreBuddyCore.Addon.LoreBuddyTestChamber = LoreBuddyTestChamber
