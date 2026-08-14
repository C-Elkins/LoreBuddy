local LoreBuddyCore = _G.LoreBuddyCore or {}
_G.LoreBuddyCore = LoreBuddyCore

local RelationshipManager = {}
RelationshipManager.__index = RelationshipManager

-- Fallback only: real symmetry data comes from GeneratedVocabulary (built
-- from database/relationship-vocabulary.json's "directional" flag).
local fallbackSymmetricPredicates = {
    related_to = true,
    allied_with = true,
    enemy_of = true,
    associated_with = true,
    sibling_of = true,
    loved = true,
    opposes = true
}

local function isSymmetric(predicate)
    local vocabulary = LoreBuddyCore.GeneratedVocabulary
    if vocabulary and vocabulary[predicate] then
        return vocabulary[predicate].directional == false
    end
    return fallbackSymmetricPredicates[predicate] == true
end

function RelationshipManager.new(relationships, entityManager)
    local manager = setmetatable({ relationships = relationships or {}, entityManager = entityManager }, RelationshipManager)
    return manager
end

function RelationshipManager:connections(entityId, predicate)
    local results = {}
    for _, relationship in ipairs(self.relationships) do
        local isSubject = relationship.subjectId == entityId
        local isObject = relationship.objectId == entityId
        local matchesPredicate = not predicate or relationship.predicate == predicate
        if matchesPredicate and (isSubject or (isObject and isSymmetric(relationship.predicate))) then
            local otherId = isSubject and relationship.objectId or relationship.subjectId
            table.insert(results, {
                relationship = relationship,
                entity = self.entityManager and self.entityManager:get(otherId),
                entityId = otherId,
                direction = isSubject and "outgoing" or "incoming"
            })
        end
    end
    return results
end

function RelationshipManager:between(subjectId, objectId, predicate)
    for _, relationship in ipairs(self.relationships) do
        local direct = relationship.subjectId == subjectId and relationship.objectId == objectId
        local reverse = isSymmetric(relationship.predicate)
            and relationship.subjectId == objectId
            and relationship.objectId == subjectId
        if (direct or reverse) and (not predicate or relationship.predicate == predicate) then
            return relationship
        end
    end
    return nil
end

-- Unlike connections(), this returns relationships in either direction
-- regardless of symmetry. Used for context relevance, where a zone or event
-- is usually only ever the object of a directional predicate (located_at,
-- contains, participated_in) but should still surface connected entities.
function RelationshipManager:touching(entityId, predicate)
    local results = {}
    for _, relationship in ipairs(self.relationships) do
        local isSubject = relationship.subjectId == entityId
        local isObject = relationship.objectId == entityId
        local matchesPredicate = not predicate or relationship.predicate == predicate
        if matchesPredicate and (isSubject or isObject) then
            local otherId = isSubject and relationship.objectId or relationship.subjectId
            table.insert(results, {
                relationship = relationship,
                entity = self.entityManager and self.entityManager:get(otherId),
                entityId = otherId,
                direction = isSubject and "outgoing" or "incoming"
            })
        end
    end
    return results
end


LoreBuddyCore.RelationshipManager = RelationshipManager