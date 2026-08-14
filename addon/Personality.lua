local LoreBuddyCore = _G.LoreBuddyCore or {}
_G.LoreBuddyCore = LoreBuddyCore

LoreBuddyCore.Addon = LoreBuddyCore.Addon or {}
local Personality = {}
Personality.__index = Personality

local VALID_MODES = { quiet = true, buddy = true }

-- Rotated deterministically (not random) so behavior stays testable.
local buddyIntros = {
    "Ooh, I know this one!",
    "Let me tell you something...",
    "Here's a bit of lore for you:",
    "You might find this interesting:",
    "Gather 'round, here's the tale:"
}

function Personality.new(state)
    state = state or {}
    state.notificationMode = VALID_MODES[state.notificationMode] and state.notificationMode or "quiet"
    state.buddyLineIndex = state.buddyLineIndex or 0
    return setmetatable({ state = state }, Personality)
end

function Personality:getMode()
    return self.state.notificationMode
end

function Personality:setMode(mode)
    if not VALID_MODES[mode] then
        return false
    end
    self.state.notificationMode = mode
    return true
end

function Personality:nextBuddyIntro()
    self.state.buddyLineIndex = (self.state.buddyLineIndex % #buddyIntros) + 1
    return buddyIntros[self.state.buddyLineIndex]
end

-- Quiet Mode: a plain, short-lived notification.
-- Buddy Mode: Lore Buddy "talks" -- a personality-flavored intro, shown longer.
-- Returns (text, durationSeconds).
function Personality:announce(entity, statementText)
    if self:getMode() == "buddy" then
        return string.format("%s %s", self:nextBuddyIntro(), statementText), 15
    end
    return statementText, 6
end

LoreBuddyCore.Addon.Personality = Personality
