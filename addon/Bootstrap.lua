local LoreBuddyCore = _G.LoreBuddyCore or {}
_G.LoreBuddyCore = LoreBuddyCore

LoreBuddyCore.Addon = LoreBuddyCore.Addon or {}
local Addon = LoreBuddyCore.Addon

function Addon.getClientContext()
    local version, build, buildDate, interfaceVersion, localizedVersion = GetBuildInfo()
    return {
        client = "wow_classic",
        era = "burning_crusade",
        gameType = "tbc",
        version = version,
        build = build,
        buildDate = buildDate,
        interfaceVersion = interfaceVersion,
        localizedVersion = localizedVersion,
        locale = GetLocale and GetLocale() or nil,
        region = GetCurrentRegion and GetCurrentRegion() or nil
    }
end

function Addon.isSupportedClient(context)
    return context and context.gameType == "tbc"
end

function Addon.initialize(dataset, discoveryState)
    local context = Addon.getClientContext()
    if not Addon.isSupportedClient(context) then
        return nil, "LoreBuddy requires the Burning Crusade Classic Anniversary client"
    end
    if not LoreBuddyCore.LoreEngine then
        return nil, "LoreBuddy core modules are not loaded"
    end
    local engine = LoreBuddyCore.LoreEngine.new(dataset or {}, discoveryState or LoreBuddyCharacterState)
    Addon.clientContext = context
    Addon.engine = engine
    return engine
end
