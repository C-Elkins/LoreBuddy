local LoreBuddyCore = _G.LoreBuddyCore or {}
_G.LoreBuddyCore = LoreBuddyCore

local SourceManager = {}
SourceManager.__index = SourceManager

local authorityRank = {
    primary = 4,
    secondary = 3,
    community = 2,
    speculation = 1
}

function SourceManager.new(sources)
    local manager = setmetatable({ byId = {}, sources = sources or {} }, SourceManager)
    for _, source in ipairs(manager.sources) do
        assert(source.id, "source id is required")
        assert(not manager.byId[source.id], "duplicate source id: " .. source.id)
        manager.byId[source.id] = source
    end
    return manager
end

function SourceManager:get(id)
    return self.byId[id]
end

function SourceManager:forIds(ids)
    local results = {}
    for _, id in ipairs(ids or {}) do
        local source = self:get(id)
        if source then
            table.insert(results, source)
        end
    end
    table.sort(results, function(left, right)
        return (authorityRank[left.classification] or 0) > (authorityRank[right.classification] or 0)
    end)
    return results
end

function SourceManager:authorityRank(source)
    return authorityRank[source.classification] or 0
end

function SourceManager:highestAuthority(sources)
    local highest
    for _, source in ipairs(sources or {}) do
        if not highest or self:authorityRank(source) > self:authorityRank(highest) then
            highest = source
        end
    end
    return highest
end

LoreBuddyCore.SourceManager = SourceManager