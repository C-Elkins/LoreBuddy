local LoreBuddyCore = _G.LoreBuddyCore or {}
_G.LoreBuddyCore = LoreBuddyCore

local LoreEngine = {}
LoreEngine.__index = LoreEngine

function LoreEngine.new(dataset, discoveryState)
    local valid, errors = LoreBuddyCore.ValidationEngine.validate(dataset)
    assert(valid, table.concat(errors, "; "))
    local engine = setmetatable({ dataset = dataset }, LoreEngine)
    engine.entities = LoreBuddyCore.EntityManager.new(dataset.entities)
    engine.discovery = LoreBuddyCore.DiscoveryManager.new(dataset.discoveryGates, discoveryState)
    engine.sources = LoreBuddyCore.SourceManager.new(dataset.sources)
    engine.relationships = LoreBuddyCore.RelationshipManager.new(dataset.relationships, engine.entities)
    engine.search = LoreBuddyCore.SearchEngine.new(engine.entities, dataset.statements, engine.sources, engine.discovery)
    engine.context = LoreBuddyCore.ContextEngine.new(engine.entities, dataset.statements, engine.sources, engine.discovery)
    return engine
end

function LoreEngine:findCharacter(name)
    return self.entities:find(name, "character")
end

function LoreEngine:findLoreAbout(query, options)
    return self.search:findStatements(query, options)
end

function LoreEngine:findConnections(query, predicate)
    local matches = self.entities:find(query)
    local results = {}
    for _, match in ipairs(matches) do
        for _, connection in ipairs(self.relationships:connections(match.entity.id, predicate)) do
            connection.sourceEntity = match.entity
            table.insert(results, connection)
        end
    end
    return results
end

function LoreEngine:findRelevantLore(context)
    return self.context:relevant(context)
end

function LoreEngine:hasPlayerDiscovered(query)
    local matches = self.entities:find(query)
    for _, match in ipairs(matches) do
        if self.discovery:hasDiscovered(match.entity.id, self.dataset.statements) then
            return true
        end
    end
    return false
end

LoreBuddyCore.LoreEngine = LoreEngine