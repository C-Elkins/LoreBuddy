local LoreBuddyCore = _G.LoreBuddyCore or {}
_G.LoreBuddyCore = LoreBuddyCore

local DiscoveryManager = {}
DiscoveryManager.__index = DiscoveryManager

function DiscoveryManager.new(gates, state)
    local manager = setmetatable({ gates = {}, state = state or {
        schemaVersion = 1,
        discoveredGateIds = {},
        seenStatementIds = {},
        dismissedHintIds = {}
    } }, DiscoveryManager)
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

function DiscoveryManager:isVisible(statement, options)
    options = options or {}
    if options.allowSpoilers then
        return true
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