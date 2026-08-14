local LoreBuddyCore = _G.LoreBuddyCore or {}
_G.LoreBuddyCore = LoreBuddyCore

LoreBuddyCore.Addon = LoreBuddyCore.Addon or {}
local Theme = LoreBuddyCore.Addon.Theme
local LoreBuddyJournal = {}
LoreBuddyJournal.__index = LoreBuddyJournal

local MAX_RESULTS = 8
local DETAIL_LEVEL_ORDER = { quick = 1, story = 2, deep = 3 }

-- Encyclopedia Mode: quick-level summary for the selected entity.
-- Deep Dive Mode: every currently unlocked statement (quick/story/deep),
-- still respecting discovery gates -- never a spoiler shortcut.
-- Long-form text lives in a real ScrollFrame, not a fixed FontString, so it
-- can grow past the visible window instead of clipping.
function LoreBuddyJournal.new(engine, personality, state, onOpenSettings)
    local self = setmetatable({ engine = engine, personality = personality, mode = "encyclopedia", rows = {} }, LoreBuddyJournal)
    if not CreateFrame then
        return self -- outside WoW (e.g. Lua tests); UI stays inert
    end

    local frame = CreateFrame("Frame", "LoreBuddyJournalFrame", UIParent, "BackdropTemplate")
    frame:SetSize(380, 500)
    frame:SetFrameStrata("DIALOG")
    Theme.applyPanelBackdrop(frame)
    Theme.makeDraggable(frame, state, "journal", { point = "CENTER", relativePoint = "CENTER", x = 0, y = 0 })
    frame:Hide()

    local title = frame:CreateFontString(nil, "OVERLAY", Theme.fonts.title)
    title:SetPoint("TOP", 0, -14)
    title:SetText("Lore Buddy")
    Theme.styleHeading(title)

    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", -4, -4)
    closeButton:SetScript("OnClick", function()
        Theme.fadeOut(frame, 0.15)
    end)

    local settingsButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    settingsButton:SetSize(22, 22)
    settingsButton:SetPoint("TOPLEFT", 6, -6)
    settingsButton:SetText("*")
    settingsButton:SetScript("OnClick", function()
        if onOpenSettings then onOpenSettings() end
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
    local buddyLabel = frame:CreateFontString(nil, "OVERLAY", Theme.fonts.body)
    buddyLabel:SetPoint("LEFT", buddyCheck, "RIGHT", 2, 0)
    buddyLabel:SetText("Buddy Mode")
    Theme.styleBody(buddyLabel)

    local anchor = buddyCheck
    for i = 1, MAX_RESULTS do
        local row = CreateFrame("Button", nil, frame)
        row:SetSize(340, 16)
        row:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, i == 1 and -10 or -2)
        local label = row:CreateFontString(nil, "OVERLAY", Theme.fonts.body)
        label:SetPoint("LEFT", 0, 0)
        label:SetJustifyH("LEFT")
        Theme.styleBody(label)
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

    local resultLabel = frame:CreateFontString(nil, "OVERLAY", Theme.fonts.heading)
    resultLabel:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -12)
    resultLabel:SetJustifyH("LEFT")
    Theme.styleHeading(resultLabel)

    -- Real ScrollFrame for long-form lore text (Deep Dive can be long).
    local scrollFrame = CreateFrame("ScrollFrame", "LoreBuddyJournalScroll", frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", resultLabel, "BOTTOMLEFT", 0, -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 16)

    local detail = CreateFrame("Frame", nil, scrollFrame)
    detail:SetSize(1, 1)
    scrollFrame:SetScrollChild(detail)

    local detailText = detail:CreateFontString(nil, "OVERLAY", Theme.fonts.body)
    detailText:SetPoint("TOPLEFT", 0, 0)
    detailText:SetWidth(300)
    detailText:SetJustifyH("LEFT")
    detailText:SetJustifyV("TOP")
    if detailText.SetWordWrap then
        detailText:SetWordWrap(true)
    end
    Theme.styleBody(detailText)

    searchBox:SetScript("OnEnterPressed", function(box)
        self:search(box:GetText())
        box:ClearFocus()
    end)

    self.frame = frame
    self.searchBox = searchBox
    self.resultLabel = resultLabel
    self.scrollFrame = scrollFrame
    self.detailFrame = detail
    self.detailText = detailText
    return self
end

function LoreBuddyJournal:setDetailText(text)
    self.detailText:SetText(text or "")
    if self.detailFrame and self.detailText.GetStringHeight then
        self.detailFrame:SetHeight(self.detailText:GetStringHeight())
    end
end

function LoreBuddyJournal:renderResultRows()
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
        self:setDetailText("")
    end
end

function LoreBuddyJournal:search(query)
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
function LoreBuddyJournal:showLoreBook()
    if not self.engine then
        return
    end
    self.searchBox:SetText("")
    self.results = {}
    local seen = {}
    local memoryState = self.engine.memory.state
    for _, category in ipairs(self.engine.memory.categories and self.engine.memory.categories() or {
        "discoveredCharacters", "discoveredLocations", "discoveredEvents", "discoveredFactions"
    }) do
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

function LoreBuddyJournal:selectEntity(entityId)
    local entity = self.engine.entities:get(entityId)
    if not entity then
        return
    end
    self.selectedEntityId = entityId
    self.resultLabel:SetText(entity.name)
    self:renderDetail()
end

function LoreBuddyJournal:setMode(mode)
    self.mode = mode
    self:renderDetail()
end

function LoreBuddyJournal:renderDetail()
    if not self.selectedEntityId then
        self:setDetailText("")
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
            self:setDetailText("(Nothing unlocked yet about " .. entity.name .. ".)")
            return
        end
        local parts = {}
        for _, statement in ipairs(visible) do
            table.insert(parts, "[" .. string.upper(statement.detailLevel) .. "] " .. statement.text)
        end
        self:setDetailText(table.concat(parts, "\n\n"))
    else
        local lore = self.engine:findLoreAbout(entity.name, { detailLevel = "quick" })
        self:setDetailText(lore[1] and lore[1].statement.text or "")
    end
end

function LoreBuddyJournal:show()
    if self.frame then
        Theme.fadeIn(self.frame, 0.2)
    end
end

function LoreBuddyJournal:toggle()
    if not self.frame then
        return
    end
    if self.frame:IsShown() then
        Theme.fadeOut(self.frame, 0.15)
    else
        self:show()
    end
end

LoreBuddyCore.Addon.LoreBuddyJournal = LoreBuddyJournal
