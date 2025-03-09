-- 脚本的位置是 "{命名空间}:{路径}"，那么 require 的格式为 "{命名空间}_{路径}"
-- 注意！require 取得的内容不应该被修改，应仅调用
local default = require("apex_apex_state_machine")
local STATIC_TRACK_LINE = default.STATIC_TRACK_LINE
local MAIN_TRACK = default.MAIN_TRACK
local BOLT_CAUGHT_TRACK = default.BOLT_CAUGHT_TRACK
local main_track_states = default.main_track_states
local bolt_caught_states = default.bolt_caught_states
-- main_track_states.start 和 main_track_states.idle 是我们要重写的状态。
local start_state = setmetatable({}, {__index = main_track_states.start})
local idle_state = setmetatable({}, {__index = main_track_states.idle})
local bolt_normal_states = setmetatable({}, {__index = bolt_caught_states.normal})
local bolt_caught_states = setmetatable({}, {__index = bolt_caught_states.bolt_caught})

local function isNoAmmo(context)
    return (context:getAmmoCount() <= 0)
end

-- reload_state 是定义的新状态，用于执行单发装填
local reload_state = {
    retreat = "reload_retreat",
    need_ammo = 0,
    loaded_ammo = 0
}
function idle_state.transition(this, context, input)
    if (input == INPUT_RELOAD) then
        return this.main_track_states.reload
    end
    return main_track_states.idle.transition(this, context, input)
end
-- 在 entry 函数里，我们根据情况选择播放 'reload_intro_empty' 或 'reload_intro' 动画，
-- 并初始化 需要的弹药数、已装填的弹药数。这决定了后续的 'loop' 动画进行几次循环。
function reload_state.entry(this, context)
    if (context:getAmmoCount() <= 0) then
        context:runAnimation("reload_intro_empty", context:getTrack(STATIC_TRACK_LINE, MAIN_TRACK), false, PLAY_ONCE_HOLD, 0.2)
        reload_state.loaded_ammo = 1
    else
        context:runAnimation("reload_intro", context:getTrack(STATIC_TRACK_LINE, MAIN_TRACK), false, PLAY_ONCE_HOLD, 0.2)
        reload_state.loaded_ammo = 0
    end
    reload_state.need_ammo = context:getMaxAmmoCount() - context:getAmmoCount()
end
-- 在 update 函数里，循环播放 loop，让 loaded_ammo 变量自增。
function reload_state.update(this, context)
    if (reload_state.loaded_ammo > reload_state.need_ammo) then
        context:trigger(reload_state.retreat)
    else
        local track = context:getTrack(STATIC_TRACK_LINE, MAIN_TRACK)
        if (context:isHolding(track)) then
            context:runAnimation("reload_loop", track, false, PLAY_ONCE_HOLD, 0)
            reload_state.loaded_ammo = reload_state.loaded_ammo + 1
        end
    end
end
-- 如果 loop 循环结束或者换弹被打断，退出到 idle 状态。否则由 idle 的 transition 函数决定下一个状态。
function reload_state.transition(this, context, input)
    if (input == reload_state.retreat or input == INPUT_CANCEL_RELOAD) then
        context:runAnimation("reload_end", context:getTrack(STATIC_TRACK_LINE, MAIN_TRACK), false, PLAY_ONCE_STOP, 0.2)
        return idle_state
    end
    return idle_state.transition(this, context, input)
end



function bolt_normal_states.entry(this, context)
    this.bolt_caught_states.normal.update(this, context)
end

function bolt_normal_states.transition(this, context, input)
    if (input == this.INPUT_BOLT_CAUGHT) then
        return this.bolt_caught_states.bolt_caught
    end
end

function bolt_caught_states.entry(this, context)
    context:runAnimation("static_bolt_caught", context:getTrack(STATIC_TRACK_LINE, BOLT_CAUGHT_TRACK), false, PLAY_ONCE_HOLD, 0)
end

function bolt_caught_states.update(this, context)
    if (not isNoAmmo(context)) then
        context:trigger(this.INPUT_BOLT_NORMAL)
    end
    context:setAnimationProgress(context:getTrack(STATIC_TRACK_LINE, BOLT_CAUGHT_TRACK), 0, false)
end

function bolt_normal_states.update(this, context)
    if (isNoAmmo(context)) then
        context:trigger(this.INPUT_BOLT_CAUGHT)
    end
    if(context:getAmmoCount() <= 5) then
        context:runAnimation("static_bolt_caught", context:getTrack(STATIC_TRACK_LINE, BOLT_CAUGHT_TRACK), true, LOOP, 0)
        context:setAnimationProgress(context:getTrack(STATIC_TRACK_LINE, BOLT_CAUGHT_TRACK), 1 - context:getAmmoCount()/10, false)
        context:pauseAnimation(context:getTrack(STATIC_TRACK_LINE, BOLT_CAUGHT_TRACK))
    end
end

function bolt_caught_states.transition(this, context, input)
    if (input == this.INPUT_BOLT_NORMAL) then
        context:stopAnimation(context:getTrack(STATIC_TRACK_LINE, BOLT_CAUGHT_TRACK))
        return this.bolt_caught_states.normal
    end
end

-- 用元表的方式继承默认状态机的属性
local M = setmetatable({
    main_track_states = setmetatable({
        -- 自定义的 idle 状态需要覆盖掉父级状态机的对应状态，新建的 reload 状态也要加进来
        idle = idle_state,
        reload = reload_state
    }, {__index = main_track_states}),
    INPUT_RELOAD_RETREAT = "reload_retreat",
    bolt_caught_states = setmetatable({
        bolt_caught = bolt_caught_states,
        normal = bolt_normal_states
    }, {__index = bolt_caught_states})
}, {__index = default})
-- 先调用父级状态机的初始化函数，然后进行自己的初始化
function M:initialize(context)
    default.initialize(self, context)
    self.main_track_states.reload.need_ammo = 0
    self.main_track_states.reload.loaded_ammo = 0
end
-- 导出状态机
return M