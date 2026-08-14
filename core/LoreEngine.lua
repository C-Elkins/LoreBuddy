local LoreBuddyCore = _G.LoreBuddyCore or {}
_G.LoreBuddyCore = LoreBuddyCore

local LoreEngine = {}
LoreEngine.__index = LoreEngine

local contextAnchorFields = { "zoneId", "npcId", "bossId", "questId", "eventId", "locationId" }

local function firstVisibleStatement(engine, entityId, detailLevel)
    for _, statement in ipairs(engine.dataset.statements or {}) do
        if statement.entityId == entityId and statement.detailLevel == detailLevel and engine.discovery:isVisible(statement) then
            return statement
        end
    end
    return nil
end

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
    engine.memory = LoreBuddyCore.PlayerMemory.new(discoveryState)
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

-- Records the entity as encountered and returns an encounter summary,
-- including a "you've encountered this before" message when applicable.
function LoreEngine:rememberEntity(entityId)
    local entity = self.entities:get(entityId)
    if not entity then
        return nil
    end
    local recorded, alreadyKnown = self.memory:remember(entity)
    if not recorded then
        return nil
    end
    local message
    if alreadyKnown then
        message = string.format("You've encountered this %s before.", self.memory:labelFor(entity.type))
    end
    return { entity = entity, alreadyKnown = alreadyKnown, message = message }
end

function LoreEngine:hasPlayerEncountered(entityId)
    return self.memory:hasEncountered(entityId)
end

-- The context engine's core decision: given the player's current situation
-- (zone, NPC, boss, quest, event) and what they already know, decide whether
-- there is something interesting LoreBuddy should introduce right now.
-- Traverses the relationship graph up to options.depth hops (default 2) so
-- entities connected to entities in the current context surface too, not
-- just entities directly linked to the zone/NPC/quest itself.
function LoreEngine:evaluateContext(context, options)
    context = context or {}
    options = options or {}
    local maxDepth = options.depth or 2

    local anchorIds = {}
    for _, entityId in ipairs(context.entityIds or {}) do
        anchorIds[entityId] = true
    end
    for _, field in ipairs(contextAnchorFields) do
        if context[field] then
            anchorIds[context[field]] = true
        end
    end

    local anchors = {}
    for entityId in pairs(anchorIds) do
        local entity = self.entities:get(entityId)
        if entity then
            table.insert(anchors, entity)
        end
    end
    table.sort(anchors, function(a, b) return a.name < b.name end)

    local candidates = {}
    local reasons = {}
    local relatedRelationships = {}
    local frontier = {}
    for _, anchor in ipairs(anchors) do
        candidates[anchor.id] = anchor
        reasons[anchor.id] = "In the current context"
        table.insert(frontier, anchor)
    end

    local depth = 0
    while depth < maxDepth and #frontier > 0 do
        depth = depth + 1
        local nextFrontier = {}
        for _, current in ipairs(frontier) do
            for _, connection in ipairs(self.relationships:touching(current.id)) do
                local candidate = connection.entity
                if candidate and not candidates[candidate.id] then
                    candidates[candidate.id] = candidate
                    reasons[candidate.id] = string.format("Connected to %s via %s", current.name, connection.relationship.predicate)
                    relatedRelationships[candidate.id] = connection.relationship
                    table.insert(nextFrontier, candidate)
                end
            end
        end
        frontier = nextFrontier
    end

    local suggestions = {}
    for entityId, entity in pairs(candidates) do
        if not self.memory:hasEncountered(entityId) then
            table.insert(suggestions, {
                entity = entity,
                reason = reasons[entityId],
                relationship = relatedRelationships[entityId],
                introduction = firstVisibleStatement(self, entityId, "quick"),
                shouldIntroduce = true
            })
        end
    end
    table.sort(suggestions, function(a, b) return a.entity.name < b.entity.name end)

    return {
        anchors = anchors,
        zoneLore = self.context:relevant(context),
        suggestions = suggestions
    }
end


LoreBuddyCore.LoreEngine = LoreEngine