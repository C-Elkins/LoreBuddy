local LoreBuddyCore = _G.LoreBuddyCore or {}
_G.LoreBuddyCore = LoreBuddyCore

local EntityManager = {}
EntityManager.__index = EntityManager

local function normalize(value)
    return string.lower(tostring(value or "")):gsub("^%s+", ""):gsub("%s+$", "")
end

function EntityManager.new(entities)
    local manager = setmetatable({ byId = {}, entities = {} }, EntityManager)
    for _, entity in ipairs(entities or {}) do
        manager:add(entity)
    end
    return manager
end

function EntityManager:add(entity)
    assert(entity and entity.id, "entity id is required")
    assert(not self.byId[entity.id], "duplicate entity id: " .. entity.id)
    self.byId[entity.id] = entity
    table.insert(self.entities, entity)
    return entity
end

function EntityManager:get(id)
    return self.byId[id]
end

function EntityManager:all(entityType)
    if not entityType then
        return self.entities
    end
    local results = {}
    for _, entity in ipairs(self.entities) do
        if entity.type == entityType then
            table.insert(results, entity)
        end
    end
    return results
end

function EntityManager:find(query, entityType)
    local needle = normalize(query)
    local results = {}
    if needle == "" then
        return results
    end
    for _, entity in ipairs(self.entities) do
        if not entityType or entity.type == entityType then
            local score = 0
            local name = normalize(entity.name)
            if name == needle then
                score = 100
            elseif name:find(needle, 1, true) then
                score = 70
            end
            for _, alias in ipairs(entity.aliases or {}) do
                local normalizedAlias = normalize(alias)
                if normalizedAlias == needle then
                    score = math.max(score, 90)
                elseif normalizedAlias:find(needle, 1, true) then
                    score = math.max(score, 60)
                end
            end
            if score > 0 then
                table.insert(results, { entity = entity, score = score })
            end
        end
    end
    table.sort(results, function(left, right)
        if left.score == right.score then
            return left.entity.name < right.entity.name
        end
        return left.score > right.score
    end)
    return results
end

LoreBuddyCore.EntityManager = EntityManager