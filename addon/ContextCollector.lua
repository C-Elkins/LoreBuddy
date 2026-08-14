local LoreBuddyCore = _G.LoreBuddyCore or {}
_G.LoreBuddyCore = LoreBuddyCore

LoreBuddyCore.Addon = LoreBuddyCore.Addon or {}
local ContextCollector = {}
ContextCollector.__index = ContextCollector

function ContextCollector.new()
    return setmetatable({ state = "unknown" }, ContextCollector)
end

function ContextCollector:collect()
    local context = { state = "known" }
    if C_Map and C_Map.GetBestMapForUnit then
        context.uiMapId = C_Map.GetBestMapForUnit("player")
    end
    if GetRealZoneText then
        context.zoneName = GetRealZoneText()
    end
    if GetSubZoneText then
        context.subzoneName = GetSubZoneText()
    end
    if UnitExists and UnitExists("target") then
        context.targetName = UnitName("target")
        context.targetGuid = UnitGUID("target")
    end
    self.state = "known"
    self.lastContext = context
    return context
end

function ContextCollector:markUnavailable()
    self.state = "unavailable"
    return { state = self.state }
end

LoreBuddyCore.Addon.ContextCollector = ContextCollector
