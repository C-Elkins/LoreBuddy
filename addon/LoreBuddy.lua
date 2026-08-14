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

local function announceIfRelevant(engine, popup, context)
    local decision = engine:evaluateContext(context)
    for _, suggestion in ipairs(decision.suggestions) do
        if suggestion.introduction then
            popup:show(suggestion.entity, suggestion.introduction.text)
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

    Addon.popup = Addon.LorePopup.new()
    Addon.window = Addon.LoreWindow.new(engine)
    Addon.collector = Addon.ContextCollector.new()

    if not CreateFrame then
        return -- outside WoW (e.g. Lua tests); nothing left to wire
    end

    Addon.router = Addon.EventRouter.new(CreateFrame("Frame"))

    local function evaluateAndAnnounce()
        local rawContext = Addon.collector:collect()
        announceIfRelevant(engine, Addon.popup, buildContext(engine, rawContext))
    end

    Addon.router:on("PLAYER_TARGET_CHANGED", evaluateAndAnnounce)
    Addon.router:on("ZONE_CHANGED_NEW_AREA", evaluateAndAnnounce)
    Addon.router:on("QUEST_ACCEPTED", evaluateAndAnnounce)
    Addon.router:on("QUEST_TURNED_IN", evaluateAndAnnounce)

    if SlashCmdList then
        _G.SLASH_LOREBUDDY1 = "/lorebuddy"
        _G.SLASH_LOREBUDDY2 = "/lb"
        SlashCmdList["LOREBUDDY"] = function()
            Addon.window:toggle()
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
