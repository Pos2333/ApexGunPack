local default = require("apex_apex_state_machine")
local GUN_KICK_TRACK_LINE = default.GUN_KICK_TRACK_LINE

local gun_kick_state = setmetatable({}, {__index = default.gun_kick_state})

function gun_kick_state.transition(this, context, input)
    if (input == INPUT_SHOOT) then
        local track = context:findIdleTrack(GUN_KICK_TRACK_LINE, false)
            if(context:getAttachment("SCOPE") == "tacz:empty") then
                context:runAnimation("shoot", track, true, PLAY_ONCE_STOP, 0)
            else
                context:runAnimation("shoot2", track, true, PLAY_ONCE_STOP, 0)
            end
    end
    return nil
end

local M = setmetatable({
    gun_kick_state = gun_kick_state
}, {__index = default})

function M:initialize(context)
    default.initialize(self, context)
end

return M