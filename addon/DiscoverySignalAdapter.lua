local LoreBuddyCore = _G.LoreBuddyCore or {}
_G.LoreBuddyCore = LoreBuddyCore

LoreBuddyCore.Addon = LoreBuddyCore.Addon or {}
local DiscoverySignalAdapter = {}
DiscoverySignalAdapter.__index = DiscoverySignalAdapter

function DiscoverySignalAdapter.new(discoveryManager, clientContext)
    return setmetatable({ discoveryManager = discoveryManager, clientContext = clientContext }, DiscoverySignalAdapter)
end

function DiscoverySignalAdapter:signal(signalType, signalId)
    return {
        signalType = signalType,
        signalId = signalId,
        client = self.clientContext.client,
        era = self.clientContext.era,
        interfaceVersion = self.clientContext.interfaceVersion,
        observedAt = GetTime and GetTime() or nil
    }
end

function DiscoverySignalAdapter:handleQuestCompleted(questId, gateId)
    if gateId then
        self.discoveryManager:markGateDiscovered(gateId)
    end
    return self:signal("quest_completed", questId)
end

function DiscoverySignalAdapter:handleZoneChanged(mapId, gateId)
    if gateId then
        self.discoveryManager:markGateDiscovered(gateId)
    end
    return self:signal("zone_changed", mapId)
end

function DiscoverySignalAdapter:handleManualConfirmation(gateId)
    self.discoveryManager:markGateDiscovered(gateId)
    return self:signal("manual_confirmation", gateId)
end

LoreBuddyCore.Addon.DiscoverySignalAdapter = DiscoverySignalAdapter
