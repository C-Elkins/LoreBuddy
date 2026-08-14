local LoreBuddyCore = _G.LoreBuddyCore or {}
_G.LoreBuddyCore = LoreBuddyCore

LoreBuddyCore.Addon = LoreBuddyCore.Addon or {}
local Addon = LoreBuddyCore.Addon

-- v0.1 wiring: detect zone / NPC target / quests, ask the engine whether
-- there is something relevant to introduce, and present it via the popup.
-- Selected game objects are approximated through the same target detection
-- (WoW reports many interactable objects through the "target" unit token);
-- a dedicated game-object hook is not yet implemented.

local function resolveEntityFromName(engine, name)
    if not name or name == "" then
        return nil
    end
    local matches = engine.entities:find(name)
    return matches[1] and matches[1].entity or nil
end

local function buildContext(engine, rawContext)
    local context = {}
    if rawContext.targetName then
        local target = resolveEntityFromName(engine, rawContext.targetName)
        if target then
            context.npcId = target.id
        end
    end
    if rawContext.zoneName then
        local zone = resolveEntityFromName(engine, rawContext.zoneName)
        if zone then
            context.zoneId = zone.id
        end
    end
    for _, questName in ipairs(rawContext.questNames or {}) do
        local quest = resolveEntityFromName(engine, questName)
        if quest and quest.type == "quest" then
            context.questId = quest.id
            break
        end
    end
    return context
end

local function connectionEntityFor(engine, suggestion)
    local relationship = suggestion.relationship
    if not relationship then
        return nil
    end
    local otherId = relationship.subjectId == suggestion.entity.id and relationship.objectId or relationship.subjectId
    return engine.entities:get(otherId)
end

-- Combat rule: never pop up mid-fight. Queue the presentation and flush it
-- with a single "while you were fighting" prompt after combat ends.
local CombatQueue = {}
CombatQueue.__index = CombatQueue

function CombatQueue.new(state)
    return setmetatable({ state = state, pending = nil }, CombatQueue)
end

function CombatQueue:inCombat()
    return self.state.suppressInCombat ~= false and InCombatLockdown and InCombatLockdown()
end

function CombatQueue:present(fn)
    if self:inCombat() then
        self.pending = fn
    else
        fn()
    end
end

function CombatQueue:flush()
    local fn = self.pending
    self.pending = nil
    if fn then
        fn()
    end
end

function CombatQueue:simulateQueuedDiscovery()
    self.pending = self.pending or function()
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("LoreBuddy: while you were fighting, Lore Buddy found something interesting.")
        end
    end
    self:flush()
end

local function announceIfRelevant(engine, popup, indicator, combatQueue, personality, context)
    local decision = engine:evaluateContext(context)
    for _, suggestion in ipairs(decision.suggestions) do
        if suggestion.introduction then
            local connectionEntity = connectionEntityFor(engine, suggestion)
            local text = personality:announce(suggestion.entity, suggestion.introduction.text)
            combatQueue:present(function()
                if indicator then indicator:showGlow() end
                popup:show(suggestion.entity, connectionEntity, text)
            end)
            return engine:rememberEntity(suggestion.entity.id)
        end
    end
    return nil
end

function Addon.start()
    local engine, err = Addon.initialize()
    if not engine then
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("LoreBuddy: " .. tostring(err))
        end
        return
    end

    ---@diagnostic disable-next-line: undefined-field
    local state = _G.LoreBuddyCharacterState or {}
    _G.LoreBuddyCharacterState = state

    Addon.personality = Addon.Personality.new(state)
    Addon.settings = Addon.LoreBuddySettings.new(engine, state)
    Addon.settings:registerInterfaceOptions()
    Addon.indicator = Addon.LoreBuddyIndicator.new(state, function()
        Addon.journal:toggle()
    end)
    Addon.journal = Addon.LoreBuddyJournal.new(engine, Addon.personality, state, function()
        Addon.settings:toggle()
    end)
    Addon.collector = Addon.ContextCollector.new()
    Addon.combatQueue = CombatQueue.new(state)
    Addon.popup = Addon.LoreBuddyPopup.new(state,
        function(entity)
            Addon.journal:selectEntity(entity.id)
            Addon.journal:setMode("deepdive")
            Addon.journal:show()
        end,
        function(entity)
            engine.discovery:markHintDismissed("defer_" .. entity.id)
        end
    )
    Addon.testChamber = Addon.LoreBuddyTestChamber.new(engine, Addon.popup, Addon.journal, Addon.indicator, Addon.combatQueue, state)

    if not CreateFrame then
        return -- outside WoW (e.g. Lua tests); nothing left to wire
    end

    Addon.router = Addon.EventRouter.new(CreateFrame("Frame"))

    local function evaluateAndAnnounce()
        local rawContext = Addon.collector:collect()
        announceIfRelevant(engine, Addon.popup, Addon.indicator, Addon.combatQueue, Addon.personality, buildContext(engine, rawContext))
    end

    Addon.router:on("PLAYER_TARGET_CHANGED", evaluateAndAnnounce)
    Addon.router:on("ZONE_CHANGED_NEW_AREA", evaluateAndAnnounce)
    Addon.router:on("QUEST_ACCEPTED", evaluateAndAnnounce)
    Addon.router:on("QUEST_TURNED_IN", evaluateAndAnnounce)
    Addon.router:on("PLAYER_REGEN_ENABLED", function()
        Addon.combatQueue:flush()
    end)

    if SlashCmdList then
        _G.SLASH_LOREBUDDY1 = "/lorebuddy"
        _G.SLASH_LOREBUDDY2 = "/lb"
        ---@diagnostic disable-next-line: duplicate-set-field
        SlashCmdList["LOREBUDDY"] = function(msg)
            if msg == "test" then
                Addon.testChamber:toggle()
            elseif msg == "settings" then
                Addon.settings:toggle()
            else
                Addon.journal:toggle()
            end
        end
    end
end

if CreateFrame then
    local loader = CreateFrame("Frame")
    loader:RegisterEvent("PLAYER_LOGIN")
    loader:SetScript("OnEvent", function()
        Addon.start()
    end)
end
