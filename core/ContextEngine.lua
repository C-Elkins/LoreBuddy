local LoreBuddyCore = _G.LoreBuddyCore or {}
_G.LoreBuddyCore = LoreBuddyCore

local ContextEngine = {}
ContextEngine.__index = ContextEngine

function ContextEngine.new(entityManager, statements, sourceManager, discoveryManager)
    return setmetatable({
        entityManager = entityManager,
        statements = statements or {},
        sourceManager = sourceManager,
        discoveryManager = discoveryManager
    }, ContextEngine)
end

function ContextEngine:relevant(context)
    context = context or {}
    local contextIds = {}
    for _, entityId in ipairs(context.entityIds or {}) do
        contextIds[entityId] = true
    end
    for _, field in ipairs({ "zoneId", "npcId", "questId", "eventId", "locationId" }) do
        if context[field] then
            contextIds[context[field]] = true
        end
    end
    local results = {}
    for _, statement in ipairs(self.statements) do
        local matches = contextIds[statement.entityId]
        for _, tag in ipairs(statement.tags or {}) do
            if context[tag] then
                matches = true
            end
        end
        if matches and (not self.discoveryManager or self.discoveryManager:isVisible(statement, context)) then
            table.insert(results, {
                statement = statement,
                entity = self.entityManager:get(statement.entityId),
                sources = self.sourceManager and self.sourceManager:forIds(statement.sourceIds) or {}
            })
        end
    end
    return results
end

LoreBuddyCore.ContextEngine = ContextEngine