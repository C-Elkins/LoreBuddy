local LoreBuddyCore = _G.LoreBuddyCore or {}
_G.LoreBuddyCore = LoreBuddyCore

LoreBuddyCore.Addon = LoreBuddyCore.Addon or {}
local EventRouter = {}
EventRouter.__index = EventRouter

function EventRouter.new(frame)
    local router = setmetatable({ frame = frame, handlers = {} }, EventRouter)
    frame:SetScript("OnEvent", function(_, event, ...)
        router:dispatch(event, ...)
    end)
    return router
end

function EventRouter:on(event, handler)
    self.handlers[event] = self.handlers[event] or {}
    table.insert(self.handlers[event], handler)
    self.frame:RegisterEvent(event)
end

function EventRouter:dispatch(event, ...)
    for _, handler in ipairs(self.handlers[event] or {}) do
        handler(...)
    end
end

LoreBuddyCore.Addon.EventRouter = EventRouter
