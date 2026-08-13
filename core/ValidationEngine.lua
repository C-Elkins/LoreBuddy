local LoreBuddyCore = _G.LoreBuddyCore or {}
_G.LoreBuddyCore = LoreBuddyCore

local ValidationEngine = {}

function ValidationEngine.validate(dataset)
    local errors = {}
    local entities, sources, gates = {}, {}, {}
    for _, entity in ipairs(dataset.entities or {}) do
        if entities[entity.id] then table.insert(errors, "duplicate entity: " .. tostring(entity.id)) end
        entities[entity.id] = true
    end
    for _, source in ipairs(dataset.sources or {}) do
        if sources[source.id] then table.insert(errors, "duplicate source: " .. tostring(source.id)) end
        sources[source.id] = true
    end
    for _, gate in ipairs(dataset.discoveryGates or {}) do
        gates[gate.id] = true
    end
    for _, statement in ipairs(dataset.statements or {}) do
        if not entities[statement.entityId] then table.insert(errors, "statement references unknown entity: " .. tostring(statement.entityId)) end
        for _, sourceId in ipairs(statement.sourceIds or {}) do
            if not sources[sourceId] then table.insert(errors, "statement references unknown source: " .. tostring(sourceId)) end
        end
        for _, gateId in ipairs(statement.discoveryGateIds or {}) do
            if not gates[gateId] then table.insert(errors, "statement references unknown gate: " .. tostring(gateId)) end
        end
    end
    for _, relationship in ipairs(dataset.relationships or {}) do
        if not entities[relationship.subjectId] or not entities[relationship.objectId] then
            table.insert(errors, "relationship references unknown entity: " .. tostring(relationship.id))
        end
        for _, sourceId in ipairs(relationship.sourceIds or {}) do
            if not sources[sourceId] then table.insert(errors, "relationship references unknown source: " .. tostring(sourceId)) end
        end
    end
    return #errors == 0, errors
end

LoreBuddyCore.ValidationEngine = ValidationEngine