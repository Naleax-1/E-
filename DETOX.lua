---@diagnostic disable: undefined-global

--============================================================
-- DETOX
-- E-1 Core State Implementation
--============================================================

local APP_NAME = 'DETOX'
local VERSION = 'E-1 Core State'

local State = require('Core.state')

local runtime = {
    initialized = false,
    state = nil,
    error = '',
}

local function log(message)
    if ac and ac.log then
        pcall(ac.log, '[' .. APP_NAME .. '] ' .. tostring(message))
    end
end

local function initialize()
    if runtime.initialized then
        return true
    end

    runtime.state = State.create()
    runtime.initialized = runtime.state ~= nil

    if runtime.initialized then
        log(VERSION .. ' initialized')
    else
        runtime.error = 'State initialization failed'
        log(runtime.error)
    end

    return runtime.initialized
end

function script.update(dt)
    if not initialize() then
        return
    end

    if not State.beginTick(runtime.state, dt) then
        runtime.error = 'State tick initialization failed'
        return
    end

    -- E-1 intentionally contains no physics solver.
    -- E-2 will own the scheduler and tick ordering.
    State.commit(runtime.state)
end

function script.windowMain()
    if ui and ui.text then
        ui.text(APP_NAME .. ' - ' .. VERSION)
        ui.text('State: ' .. (runtime.initialized and 'READY' or 'WAITING'))

        if runtime.state then
            ui.text('Frame: ' .. tostring(runtime.state.frame))
            ui.text('Schema: ' .. tostring(runtime.state.schema))
            ui.text('Vehicle Valid: ' .. tostring(runtime.state.current.vehicle.valid))
        end

        if runtime.error ~= '' then
            ui.text('Error: ' .. runtime.error)
        end
    end
end

function script.windowMainMenu()
    return script.windowMain()
end
