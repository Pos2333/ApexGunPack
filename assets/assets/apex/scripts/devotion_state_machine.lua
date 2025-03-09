local default = require("apex_apex_state_machine")
local GUN_KICK_TRACK_LINE = default.GUN_KICK_TRACK_LINE

local STATIC_TRACK_LINE = default.STATIC_TRACK_LINE
local BOLT_CAUGHT_TRACK = default.BOLT_CAUGHT_TRACK
local bolt_caught_states = default.bolt_caught_states

local normal_states = setmetatable({}, {__index = bolt_caught_states.normal})
local caught_states = setmetatable({}, {__index = bolt_caught_states.bolt_caught})

local gun_kick_state = setmetatable({
    acceleration_count = 0
}, {__index = default.gun_kick_state})

function gun_kick_state.transition(this, context, input)
    if (input == INPUT_SHOOT) then
        local track = context:findIdleTrack(GUN_KICK_TRACK_LINE, false)
        context:runAnimation("shoot", track, true, PLAY_ONCE_STOP, 0)
        -- 定义最大连射加速数量、每发加速的比例
        local acceleration_max = 7
        local acceleration_ratio = 0.08
        -- 获取上次射击的 timestamp（系统时间，单位毫秒）
        local last_shoot_timestamp = context:getLastShootTimestamp()
        -- 获取当前系统时间
        local current_timestamp = context:getCurrentTimestamp()
        -- 获取枪械的射击间隔，单位毫秒。用于判断是否在连射，也用于调整射击间隔
        local shoot_interval = context:getShootInterval()
        -- 判断是否在连射，给 2 tick 宽容时间
        if (current_timestamp - last_shoot_timestamp < shoot_interval + 100) then
            -- 正在连射，连射次数 +1
            if (gun_kick_state.acceleration_count < acceleration_max) then
                gun_kick_state.acceleration_count = gun_kick_state.acceleration_count + 1
            end
            -- 根据连射次数调整射击间隔
            local total_ratio = gun_kick_state.acceleration_count * acceleration_ratio
            context:adjustClientShootInterval(-total_ratio * shoot_interval)
        else
            -- 没有在连射，需要重置连射次数
            gun_kick_state.acceleration_count = 0
            -- 没有加速，不需要调整射击间隔
        end
    end
    return nil
end

local function isNoAmmo(context)
    return (context:getAmmoCount() <= 0)
end

function normal_states.update(this, context)
    if (isNoAmmo(context)) then
        context:trigger(this.INPUT_BOLT_CAUGHT)
    end
    context:runAnimation("bullet_state", context:getTrack(STATIC_TRACK_LINE, BOLT_CAUGHT_TRACK), false, LOOP, 0)
    context:setAnimationProgress(context:getTrack(STATIC_TRACK_LINE, BOLT_CAUGHT_TRACK), 1 - context:getAmmoCount()/context:getMaxAmmoCount(), false)
    context:pauseAnimation(context:getTrack(STATIC_TRACK_LINE, BOLT_CAUGHT_TRACK))
end

function caught_states.update(this, context)
    if (not isNoAmmo(context)) then
        context:trigger(this.INPUT_BOLT_NORMAL)
    end
    context:runAnimation("static_bolt_caught", context:getTrack(STATIC_TRACK_LINE, BOLT_CAUGHT_TRACK), false, PLAY_ONCE_HOLD, 0)
end

local M = setmetatable({
    gun_kick_state = gun_kick_state,
    bolt_caught_states = setmetatable({
        bolt_caught = caught_states,
        normal = normal_states
    }, {__index = bolt_caught_states})
}, {__index = default})

function M:initialize(context)
    default.initialize(self, context)
    gun_kick_state.acceleration_count = 0
end

return M