local default = require("apex_apex_state_machine")
local GUN_KICK_TRACK_LINE = default.GUN_KICK_TRACK_LINE

local STATIC_TRACK_LINE = default.STATIC_TRACK_LINE
local BOLT_CAUGHT_TRACK = default.BOLT_CAUGHT_TRACK
local bolt_caught_states = default.bolt_caught_states

local normal_states = setmetatable({}, {__index = bolt_caught_states.normal})
local caught_states = setmetatable({}, {__index = bolt_caught_states.bolt_caught})

local gun_kick_state = setmetatable({
    shooting_barrel = 0
}, {__index = default.gun_kick_state})

function gun_kick_state.transition(this, context, input)
    if (input == INPUT_SHOOT) then
        local track = context:findIdleTrack(GUN_KICK_TRACK_LINE, false)
        if (gun_kick_state.shooting_barrel == 0) then
            context:runAnimation("shoot", track, true, PLAY_ONCE_STOP, 0)
            gun_kick_state.shooting_barrel = 1
        else
            context:runAnimation("shoot_right", track, true, PLAY_ONCE_STOP, 0)
            gun_kick_state.shooting_barrel = 0
        end
    end
    return nil
end

local M = setmetatable({
    gun_kick_state = gun_kick_state
}, {__index = default})

function M:initialize(context)
    default.initialize(self, context)
    gun_kick_state.acceleration_count = 0
end

return M