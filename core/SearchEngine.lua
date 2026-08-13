local LoreBuddyCore = _G.LoreBuddyCore or {}
_G.LoreBuddyCore = LoreBuddyCore

local SearchEngine = {}
SearchEngine.__index = SearchEngine

function SearchEngine.new(entityManager, statements, sourceManager, discoveryManager)
    return setmetatable({
        entityManager = entityManager,
        statements = statements or {},
        sourceManager = sourceManager,
        discoveryManager = discoveryManager
    }, SearchEngine)
end

function SearchEngine:findEntities(query, entityType)
    return self.entityManager:find(query, entityType)
end

function SearchEngine:findStatements(query, options)
    options = options or {}
    local matches = self.entityManager:find(query, options.entityType)
    local entityScores = {}
    for _, match in ipairs(matches) do
        entityScores[match.entity.id] = match.score
    end
    local results = {}
    for _, statement in ipairs(self.statements) do
        local score = entityScores[statement.entityId]
        if score and (not options.detailLevel or statement.detailLevel == options.detailLevel) then
            if not self.discoveryManager or self.discoveryManager:isVisible(statement, options) then
                table.insert(results, {
                    statement = statement,
                    entity = self.entityManager:get(statement.entityId),
                    sources = self.sourceManager and self.sourceManager:forIds(statement.sourceIds) or {},
                    score = score
                })
            end
        end
    end
    table.sort(results, function(left, right)
        return left.score > right.score
    end)
    return results
end

LoreBuddyCore.SearchEngine = SearchEngine