local LoreBuddyCore = _G.LoreBuddyCore or {}
_G.LoreBuddyCore = LoreBuddyCore

-- Tracks per-character memory of previously encountered lore so the addon can
-- say "You've encountered this character before." Shares the same
-- SavedVariablesPerCharacter table as DiscoveryManager, under its own keys.

local PlayerMemory = {}
PlayerMemory.__index = PlayerMemory

local categoryByType = {
    character = "discoveredCharacters",
    creature = "discoveredCharacters",
    location = "discoveredLocations",
    zone = "discoveredLocations",
    event = "discoveredEvents",
    faction = "discoveredFactions",
    organization = "discoveredFactions",
    dungeon = "discoveredDungeons",
    raid = "discoveredRaids",
    book = "discoveredBooks",
    item = "discoveredItems"
}

local labelByCategory = {
    discoveredCharacters = "character",
    discoveredLocations = "location",
    discoveredEvents = "event",
    discoveredFactions = "faction",
    discoveredDungeons = "dungeon",
    discoveredRaids = "raid",
    discoveredBooks = "book",
    discoveredItems = "item"
}

local function contains(list, value)
    for _, item in ipairs(list or {}) do
        if item == value then
            return true
        end
    end
    return false
end

function PlayerMemory.new(state)
    state = state or {}
    state.discoveredCharacters = state.discoveredCharacters or {}
    state.discoveredLocations = state.discoveredLocations or {}
    state.discoveredEvents = state.discoveredEvents or {}
    state.discoveredFactions = state.discoveredFactions or {}
    state.discoveredDungeons = state.discoveredDungeons or {}
    state.discoveredRaids = state.discoveredRaids or {}
    state.discoveredBooks = state.discoveredBooks or {}
    state.discoveredItems = state.discoveredItems or {}
    state.completedQuestChainIds = state.completedQuestChainIds or {}
    state.seenLore = state.seenLore or {}
    return setmetatable({ state = state }, PlayerMemory)
end

-- All discovery category keys, e.g. for a "lore book" view that lists
-- everything the player has encountered across every category.
function PlayerMemory.categories()
    local list = {}
    for category in pairs(labelByCategory) do
        table.insert(list, category)
    end
    return list
end

function PlayerMemory:categoryFor(entityType)
    return categoryByType[entityType]
end

function PlayerMemory:labelFor(entityType)
    return labelByCategory[self:categoryFor(entityType)]
end

function PlayerMemory:hasEncountered(entityId)
    for _, category in pairs(categoryByType) do
        if contains(self.state[category], entityId) then
            return true
        end
    end
    return false
end

-- Records the entity as discovered. Returns (recorded, alreadyKnown); the
-- alreadyKnown flag reflects whether the entity was known *before* this call.
function PlayerMemory:remember(entity)
    assert(entity and entity.id, "entity with id is required")
    local category = self:categoryFor(entity.type)
    if not category then
        return false, false
    end
    local alreadyKnown = self:hasEncountered(entity.id)
    if not alreadyKnown then
        table.insert(self.state[category], entity.id)
    end
    return true, alreadyKnown
end

function PlayerMemory:hasSeenLore(statementId)
    return contains(self.state.seenLore, statementId)
end

function PlayerMemory:markLoreSeen(statementId)
    if self:hasSeenLore(statementId) then
        return false
    end
    table.insert(self.state.seenLore, statementId)
    return true
end

function PlayerMemory:hasCompletedQuestChain(questChainId)
    return contains(self.state.completedQuestChainIds, questChainId)
end

function PlayerMemory:markQuestChainCompleted(questChainId)
    if self:hasCompletedQuestChain(questChainId) then
        return false
    end
    table.insert(self.state.completedQuestChainIds, questChainId)
    return true
end

LoreBuddyCore.PlayerMemory = PlayerMemory
