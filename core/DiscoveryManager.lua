local LoreBuddyCore = _G.LoreBuddyCore or {}
_G.LoreBuddyCore = LoreBuddyCore

local DiscoveryManager = {}
DiscoveryManager.__index = DiscoveryManager

-- Higher rank = more willing to see spoilers. A statement is visible only if
-- its spoilerLevel rank is <= the player's spoilerPreference rank.
local SPOILER_LEVEL_RANK = { safe = 0, context = 1, reveal = 2, major_reveal = 3, ending = 4 }
local SPOILER_PREFERENCE_RANK = {
    no_spoilers = 0, context_only = 1, moderate = 2, full_lore = 3, show_everything = 4
}
local DEFAULT_SPOILER_PREFERENCE = "moderate"

function DiscoveryManager.new(gates, state)
    state = state or {}
    state.schemaVersion = state.schemaVersion or 1
    state.discoveredGateIds = state.discoveredGateIds or {}
    state.seenStatementIds = state.seenStatementIds or {}
    state.dismissedHintIds = state.dismissedHintIds or {}
    state.spoilerPreference = state.spoilerPreference or DEFAULT_SPOILER_PREFERENCE
    local manager = setmetatable({ gates = {}, state = state }, DiscoveryManager)
    for _, gate in ipairs(gates or {}) do
        manager.gates[gate.id] = gate
    end
    return manager
end

function DiscoveryManager:hasGate(gateId)
    for _, discoveredId in ipairs(self.state.discoveredGateIds or {}) do
        if discoveredId == gateId then
            return true
        end
    end
    return false
end

function DiscoveryManager:markGateDiscovered(gateId)
    if not self.gates[gateId] or self:hasGate(gateId) then
        return false
    end
    table.insert(self.state.discoveredGateIds, gateId)
    return true
end

function DiscoveryManager:markStatementSeen(statementId)
    for _, seenId in ipairs(self.state.seenStatementIds or {}) do
        if seenId == statementId then
            return false
        end
    end
    table.insert(self.state.seenStatementIds, statementId)
    return true
end

function DiscoveryManager:getSpoilerPreference()
    return self.state.spoilerPreference or DEFAULT_SPOILER_PREFERENCE
end

function DiscoveryManager:setSpoilerPreference(preference)
    if not SPOILER_PREFERENCE_RANK[preference] then
        return false
    end
    self.state.spoilerPreference = preference
    return true
end

function DiscoveryManager:isWithinSpoilerPreference(statement)
    local level = statement.spoilerLevel
    if not level then
        return true -- statements with no declared spoiler level carry no spoiler risk
    end
    local levelRank = SPOILER_LEVEL_RANK[level]
    if not levelRank then
        return true -- unknown level: fail open rather than silently hiding content
    end
    return levelRank <= (SPOILER_PREFERENCE_RANK[self:getSpoilerPreference()] or SPOILER_PREFERENCE_RANK[DEFAULT_SPOILER_PREFERENCE])
end

function DiscoveryManager:isVisible(statement, options)
    options = options or {}
    if options.allowSpoilers then
        return true
    end
    if not self:isWithinSpoilerPreference(statement) then
        return false
    end
    for _, gateId in ipairs(statement.discoveryGateIds or {}) do
        if not self:hasGate(gateId) then
            return false
        end
    end
    return true
end

function DiscoveryManager:hasDiscovered(entityId, statements)
    for _, statement in ipairs(statements or {}) do
        if statement.entityId == entityId then
            for _, seenId in ipairs(self.state.seenStatementIds or {}) do
                if seenId == statement.id then
                    return true
                end
            end
        end
    end
    return false
end

-- "Later" support: defer a discovery notification without losing it.
function DiscoveryManager:hasDismissedHint(hintId)
    for _, dismissedId in ipairs(self.state.dismissedHintIds or {}) do
        if dismissedId == hintId then
            return true
        end
    end
    return false
end

function DiscoveryManager:markHintDismissed(hintId)
    if self:hasDismissedHint(hintId) then
        return false
    end
    table.insert(self.state.dismissedHintIds, hintId)
    return true
end

LoreBuddyCore.DiscoveryManager = DiscoveryManager