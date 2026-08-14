local LoreBuddyCore = _G.LoreBuddyCore or {}
_G.LoreBuddyCore = LoreBuddyCore

local ValidationEngine = {}

local entityTypes = {
    character = true, location = true, faction = true, event = true, item = true,
    quest = true, creature = true, organization = true, concept = true, book = true,
    dialogue = true, dungeon = true, raid = true, zone = true
}

local sourceKinds = {
    blizzard_api = true, quest_text = true, npc_dialogue = true, book = true,
    external_reference = true, community_contribution = true
}

local sourceClassifications = { primary = true, secondary = true, community = true, speculation = true }

-- Fallback only: if core/GeneratedVocabulary.lua hasn't been generated yet
-- (e.g. a fresh checkout before running tools/generate_lua_dataset.py), fall
-- back to this superset so validation still works. The vocabulary itself
-- lives in database/relationship-vocabulary.json and is data, not code.
local fallbackRelationshipPredicates = {
    related_to = true, located_at = true, allied_with = true, participated_in = true,
    enemy_of = true, member_of = true, parent_of = true, created = true,
    contains = true, appears_in = true, associated_with = true, sibling_of = true,
    loved = true, rules = true, led_by = true, part_of = true, opposes = true, supports = true
}

local function relationshipPredicates()
    if LoreBuddyCore.GeneratedVocabulary then
        return LoreBuddyCore.GeneratedVocabulary
    end
    return fallbackRelationshipPredicates
end

local function addError(errors, message)
    table.insert(errors, message)
end

local function requireString(value, field, context, errors)
    if type(value) ~= "string" or value == "" then
        addError(errors, context .. " missing required field: " .. field)
        return false
    end
    return true
end

local function indexRecords(records, label, errors, globalIds)
    local ids = {}
    for _, record in ipairs(records or {}) do
        local id = record.id
        if id and ids[id] then addError(errors, "duplicate " .. label .. ": " .. id) end
        if id and globalIds[id] then addError(errors, "duplicate ID across data types: " .. id) end
        if id then
            ids[id] = true
            globalIds[id] = true
        end
    end
    return ids
end

function ValidationEngine.validate(dataset)
    local errors = {}
    local warnings = {}
    local globalIds = {}
    local entityIds = indexRecords(dataset.entities, "entity", errors, globalIds)
    local sourceIds = indexRecords(dataset.sources, "source", errors, globalIds)
    local gateIds = indexRecords(dataset.discoveryGates, "discovery gate", errors, globalIds)
    indexRecords(dataset.statements, "statement", errors, globalIds)
    indexRecords(dataset.relationships, "relationship", errors, globalIds)
    local referencedEntityIds = {}

    for _, entity in ipairs(dataset.entities or {}) do
        local context = "entity " .. tostring(entity.id or "<missing>")
        requireString(entity.id, "id", context, errors)
        requireString(entity.name, "name", context, errors)
        requireString(entity.type, "type", context, errors)
        if not entityTypes[entity.type] then addError(errors, context .. " has invalid entity type") end
    end

    for _, source in ipairs(dataset.sources or {}) do
        local context = "source " .. tostring(source.id or "<missing>")
        for _, field in ipairs({ "id", "publisher", "title", "kind", "classification", "reference", "attribution", "license", "verificationStatus" }) do
            requireString(source[field], field, context, errors)
        end
        if not sourceKinds[source.kind] then addError(errors, context .. " has invalid source type") end
        if not sourceClassifications[source.classification] then addError(errors, context .. " has invalid source classification") end
    end

    for _, statement in ipairs(dataset.statements or {}) do
        local context = "statement " .. tostring(statement.id or "<missing>")
        for _, field in ipairs({ "id", "entityId", "detailLevel", "text", "canonStatus", "epistemicStatus" }) do
            requireString(statement[field], field, context, errors)
        end
        if not entityIds[statement.entityId] then addError(errors, context .. " has broken entity reference") else referencedEntityIds[statement.entityId] = true end
        if not statement.sourceIds or #statement.sourceIds == 0 then addError(errors, context .. " has missing sources") end
        for _, sourceId in ipairs(statement.sourceIds or {}) do
            if not sourceIds[sourceId] then addError(errors, context .. " has broken source reference") end
        end
        for _, gateId in ipairs(statement.discoveryGateIds or {}) do
            if not gateIds[gateId] then addError(errors, context .. " has broken discovery gate reference") end
        end
    end

    for _, relationship in ipairs(dataset.relationships or {}) do
        local context = "relationship " .. tostring(relationship.id or "<missing>")
        for _, field in ipairs({ "id", "subjectId", "predicate", "objectId" }) do
            requireString(relationship[field], field, context, errors)
        end
        if not entityIds[relationship.subjectId] or not entityIds[relationship.objectId] then
            addError(errors, context .. " has broken entity reference")
        else
            referencedEntityIds[relationship.subjectId] = true
            referencedEntityIds[relationship.objectId] = true
        end
        if not relationshipPredicates()[relationship.predicate] then addError(errors, context .. " has invalid relationship") end
        if not relationship.sourceIds or #relationship.sourceIds == 0 then addError(errors, context .. " has missing sources") end
        for _, sourceId in ipairs(relationship.sourceIds or {}) do
            if not sourceIds[sourceId] then addError(errors, context .. " has broken source reference") end
        end
    end

    for _, entity in ipairs(dataset.entities or {}) do
        if entity.id and not referencedEntityIds[entity.id] then
            table.insert(warnings, "orphaned entity: " .. entity.id)
        end
    end

    return #errors == 0, errors, warnings
end

LoreBuddyCore.ValidationEngine = ValidationEngine
