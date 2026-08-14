local LoreBuddyCore = _G.LoreBuddyCore or {}
_G.LoreBuddyCore = LoreBuddyCore

LoreBuddyCore.Addon = LoreBuddyCore.Addon or {}
local LoreWindow = {}
LoreWindow.__index = LoreWindow

local MAX_RESULTS = 8
local DETAIL_LEVEL_ORDER = { quick = 1, story = 2, deep = 3 }

-- Encyclopedia Mode: quick-level summary for the selected entity.
-- Deep Dive Mode: every currently unlocked statement (quick/story/deep),
-- still respecting discovery gates -- never a spoiler shortcut.
function LoreWindow.new(engine, personality)
    local self = setmetatable({ engine = engine, personality = personality, mode = "encyclopedia", rows = {} }, LoreWindow)
    if not CreateFrame then
        return self -- outside WoW (e.g. Lua tests); UI stays inert
    end

    local frame = CreateFrame("Frame", "LoreBuddyWindowFrame", UIParent, "BackdropTemplate")
    frame:SetSize(360, 480)
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

    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", -4, -4)
    closeButton:SetScript("OnClick", function()
        frame:Hide()
    end)

    local searchBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    searchBox:SetSize(300, 20)
    searchBox:SetPoint("TOP", title, "BOTTOM", 0, -14)
    if searchBox.SetAutoFocus then
        searchBox:SetAutoFocus(false)
    end

    local encyclopediaButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    encyclopediaButton:SetSize(120, 22)
    encyclopediaButton:SetPoint("TOP", searchBox, "BOTTOM", -65, -10)
    encyclopediaButton:SetText("Encyclopedia")
    encyclopediaButton:SetScript("OnClick", function()
        self:setMode("encyclopedia")
    end)

    local deepDiveButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    deepDiveButton:SetSize(100, 22)
    deepDiveButton:SetPoint("LEFT", encyclopediaButton, "RIGHT", 6, 0)
    deepDiveButton:SetText("Deep Dive")
    deepDiveButton:SetScript("OnClick", function()
        self:setMode("deepdive")
    end)

    local loreBookButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    loreBookButton:SetSize(110, 22)
    loreBookButton:SetPoint("TOP", encyclopediaButton, "BOTTOM", 30, -6)
    loreBookButton:SetText("My Lore Book")
    loreBookButton:SetScript("OnClick", function()
        self:showLoreBook()
    end)

    local buddyCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    buddyCheck:SetPoint("TOPLEFT", loreBookButton, "BOTTOMLEFT", 0, -6)
    buddyCheck:SetChecked(personality and personality:getMode() == "buddy")
    buddyCheck:SetScript("OnClick", function(checkbox)
        if personality then
            personality:setMode(checkbox:GetChecked() and "buddy" or "quiet")
        end
    end)
    local buddyLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    buddyLabel:SetPoint("LEFT", buddyCheck, "RIGHT", 2, 0)
    buddyLabel:SetText("Buddy Mode")

    local anchor = buddyCheck
    for i = 1, MAX_RESULTS do
        local row = CreateFrame("Button", nil, frame)
        row:SetSize(320, 16)
        row:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, i == 1 and -10 or -2)
        local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint("LEFT", 0, 0)
        label:SetJustifyH("LEFT")
        row.label = label
        row:SetScript("OnClick", function()
            if row.entityId then
                self:selectEntity(row.entityId)
            end
        end)
        row:Hide()
        self.rows[i] = row
        anchor = row
    end

    local resultLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    resultLabel:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -12)
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

function LoreWindow:renderResultRows()
    for i, row in ipairs(self.rows) do
        local entity = self.results[i]
        if entity then
            row.label:SetText(string.format("%s (%s)", entity.name, entity.type))
            row.entityId = entity.id
            row:Show()
        else
            row.label:SetText("")
            row.entityId = nil
            row:Hide()
        end
    end
    if self.results[1] then
        self:selectEntity(self.results[1].id)
    else
        self.selectedEntityId = nil
        self.resultLabel:SetText(self.emptyMessage or "")
        self.detail:SetText("")
    end
end

function LoreWindow:search(query)
    if not self.engine then
        return
    end
    self.results = {}
    if query and query ~= "" then
        local matches = self.engine.entities:find(query)
        for i, match in ipairs(matches) do
            if i > MAX_RESULTS then
                break
            end
            table.insert(self.results, match.entity)
        end
    end
    self.emptyMessage = query and query ~= "" and ('No matches for "' .. query .. '"') or ""
    self:renderResultRows()
end

-- "Your personal lore book grows": lists only entities this character has
-- actually encountered (PlayerMemory), independent of any search text.
function LoreWindow:showLoreBook()
    if not self.engine then
        return
    end
    self.searchBox:SetText("")
    self.results = {}
    local seen = {}
    local memoryState = self.engine.memory.state
    for _, category in ipairs({ "discoveredCharacters", "discoveredLocations", "discoveredEvents", "discoveredFactions" }) do
        for _, entityId in ipairs(memoryState[category] or {}) do
            if not seen[entityId] then
                seen[entityId] = true
                local entity = self.engine.entities:get(entityId)
                if entity then
                    table.insert(self.results, entity)
                end
            end
        end
    end
    table.sort(self.results, function(a, b) return a.name < b.name end)
    self.emptyMessage = "Your lore book is empty. Go explore!"
    self:renderResultRows()
end

function LoreWindow:selectEntity(entityId)
    local entity = self.engine.entities:get(entityId)
    if not entity then
        return
    end
    self.selectedEntityId = entityId
    self.resultLabel:SetText(entity.name)
    self:renderDetail()
end

function LoreWindow:setMode(mode)
    self.mode = mode
    self:renderDetail()
end

function LoreWindow:renderDetail()
    if not self.selectedEntityId then
        self.detail:SetText("")
        return
    end
    local entity = self.engine.entities:get(self.selectedEntityId)
    if self.mode == "deepdive" then
        local visible = {}
        for _, statement in ipairs(self.engine.dataset.statements or {}) do
            if statement.entityId == self.selectedEntityId and self.engine.discovery:isVisible(statement) then
                table.insert(visible, statement)
            end
        end
        table.sort(visible, function(a, b)
            return (DETAIL_LEVEL_ORDER[a.detailLevel] or 4) < (DETAIL_LEVEL_ORDER[b.detailLevel] or 4)
        end)
        if #visible == 0 then
            self.detail:SetText("(Nothing unlocked yet about " .. entity.name .. ".)")
            return
        end
        local parts = {}
        for _, statement in ipairs(visible) do
            table.insert(parts, "[" .. string.upper(statement.detailLevel) .. "] " .. statement.text)
        end
        self.detail:SetText(table.concat(parts, "\n\n"))
    else
        local lore = self.engine:findLoreAbout(entity.name, { detailLevel = "quick" })
        self.detail:SetText(lore[1] and lore[1].statement.text or "")
    end
end

function LoreWindow:show()
    if self.frame then
        self.frame:Show()
    end
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
