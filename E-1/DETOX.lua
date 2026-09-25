---@diagnostic disable: undefined-global

--============================================================
-- DETOX
-- E-1 Core State Implementation
--============================================================

local APP_NAME = 'DETOX'
local VERSION = 'E-1 Core State'

local State = require('Core.state')
local Input = require('Core.input')
local Scheduler = require('Core.scheduler')

local runtime = {
    state = nil,
    input = nil,
    scheduler = nil,

    initialized = false,
    error = nil
}

local function initialize()
    runtime.state =
        State.create()

    runtime.input =
        Input.create()

    runtime.scheduler =
        Scheduler.create()

    runtime.initialized =
        true

    runtime.error = nil
end

local function phaseInput()
    return Input.read(
        runtime.input,
        runtime.scheduler.dt
    )
end

local function phaseSnapshot()
    local input =
        runtime.input

    local nextState =
        State.getNext(runtime.state)

    nextState.vehicle.valid =
        input.vehicle.valid

    nextState.vehicle.speed =
        input.vehicle.speed

    nextState.vehicle.rpm =
        input.vehicle.rpm

    nextState.vehicle.gear =
        input.vehicle.gear

    nextState.vehicle.steer =
        input.vehicle.steer

    nextState.vehicle.gas =
        input.vehicle.gas

    nextState.vehicle.brake =
        input.vehicle.brake

    nextState.vehicle.clutch =
        input.vehicle.clutch

    nextState.vehicle.handbrake =
        input.vehicle.handbrake

    for _, name in
        ipairs(Input.getWheelNames()) do

        local source =
            input.wheels[name]

        local wheel =
            nextState.wheels[name]

        if source then
            wheel.valid =
                source.valid

            wheel.omega =
                source.omega

            wheel.load =
                source.load

            wheel.suspensionTravel =
                source.suspensionTravel

            wheel.suspensionVelocity =
                source.suspensionVelocity

            wheel.contact =
                source.contact
        end
    end

    return true
end

local function phaseKinematics()
    return true
end

local function phaseSlip()
    return true
end

local function phaseThermalCarcass()
    return true
end

local function phaseTire()
    return true
end

local function phasePowertrain()
    return true
end

local function phaseDifferential()
    return true
end

local function phaseSuspension()
    return true
end

local function phaseWheel()
    return true
end

local function phaseCoupledIteration()
    return true
end

local function phaseBody()
    return true
end

local function phaseValidation()
    return true
end

local function phaseCommit()
    return State.commit(
        runtime.state
    )
end

local function phaseOutput()
    return true
end

local function update(dt)
    if not runtime.initialized then
        initialize()
    end

    if not runtime.state or
       not runtime.scheduler then
        return
    end

    Scheduler.beginTick(
        runtime,
        dt
    )

    State.beginTick(
        runtime.state,
        dt
    )

    local success =
        Scheduler.execute(
            runtime,
            {
                Input =
                    phaseInput,

                Snapshot =
                    phaseSnapshot,

                Kinematics =
                    phaseKinematics,

                Slip =
                    phaseSlip,

                ThermalCarcass =
                    phaseThermalCarcass,

                Tire =
                    phaseTire,

                Powertrain =
                    phasePowertrain,

                Differential =
                    phaseDifferential,

                Suspension =
                    phaseSuspension,

                Wheel =
                    phaseWheel,

                CoupledIteration =
                    phaseCoupledIteration,

                Body =
                    phaseBody,

                Validation =
                    phaseValidation,

                Commit =
                    phaseCommit,

                Output =
                    phaseOutput
            }
        )

    if not success then
        runtime.error =
            runtime.scheduler.error
    else
        runtime.error = nil
    end

    Scheduler.endTick(
        runtime
    )
end

local function windowMain()
    if not runtime.initialized then
        initialize()
    end

    local status =
        Scheduler.getStatus(
            runtime
        )

    ui.text('DETOX')
    ui.text(
        'Scheduler: ' ..
        tostring(status.version)
    )

    ui.text(
        'Tick: ' ..
        tostring(status.tick)
    )

    ui.text(
        'Phase: ' ..
        tostring(status.currentPhase)
    )

    ui.text(
        'Completed: ' ..
        tostring(status.completedPhase)
    )

    ui.text(
        'State: ' ..
        tostring(runtime.state.valid)
    )

    ui.text(
        'Input: ' ..
        tostring(runtime.input.valid)
    )

    ui.text(
        'Coupled Iterations: ' ..
        tostring(status.coupledIterations)
    )

    if status.error then
        ui.text('ERROR')
        ui.text(
            tostring(status.error)
        )
    else
        ui.text('STATUS: READY')
    end
end

local function windowMainMenu()
    windowMain()
end

script.update =
    update

script.windowMain =
    windowMain

script.windowMainMenu =
    windowMainMenu
