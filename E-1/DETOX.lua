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

local Wheel = require('Engine.wheel')
local Tire = require('Engine.tire')
local Suspension = require('Engine.suspension')
local Powertrain = require('Engine.powertrain')
local Differential = require('Engine.differential')

local TireModel = require('Model.tire_model')
local LoadModel = require('Model.load_model')

local PowertrainDefinition =
    require('Definition.powertrain')

local DifferentialDefinition =
    require('Definition.differential')

local runtime = {
    state = nil,
    input = nil,
    scheduler = nil,

    wheel = nil,
    tire = nil,
    suspension = nil,

    powertrain = nil,
    differential = nil,

    tireModel = nil,
    loadModel = nil,

    powertrainDefinition = nil,
    differentialDefinition = nil,

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

    runtime.wheel =
        Wheel.create()

    runtime.tireModel =
        TireModel.create()

    runtime.loadModel =
        LoadModel.create()

    runtime.tire =
        Tire.create(
            runtime.tireModel
        )

    runtime.suspension =
        Suspension.create()

    runtime.powertrainDefinition =
        PowertrainDefinition.create()

    runtime.differentialDefinition =
        DifferentialDefinition.create()

    runtime.powertrain =
        Powertrain.create(
            runtime.powertrainDefinition
        )

    runtime.differential =
        Differential.create(
            runtime.differentialDefinition
        )

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
        State.getNext(
            runtime.state
        )

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
    local nextState =
        State.getNext(
            runtime.state
        )

    Wheel.updateKinematics(
        nextState
    )

    return true
end

local function phaseSlip()
    local nextState =
        State.getNext(
            runtime.state
        )

    Wheel.updateSlip(
        nextState
    )

    return true
end

local function phaseThermalCarcass()
    return true
end

local function phaseTire()
    local nextState =
        State.getNext(
            runtime.state
        )

    Tire.update(
        runtime.tire,
        nextState
    )

    return true
end

local function phasePowertrain()
    local nextState =
        State.getNext(
            runtime.state
        )

    Powertrain.update(
        runtime.powertrain,
        nextState,
        runtime.scheduler.dt
    )

    return true
end

local function phaseDifferential()
    local nextState =
        State.getNext(
            runtime.state
        )

    local definition =
        runtime.powertrainDefinition

    local shaft =
        nextState.powertrain.shaft

    local gearbox =
        nextState.powertrain.gearbox

    local differential =
        nextState.powertrain.differential

    local inputTorque =
        shaft.torque

    local ratio =
        gearbox.ratio or 0

    local finalDrive =
        gearbox.finalDrive or
        definition.gearbox.finalDrive

    inputTorque =
        inputTorque *
        ratio *
        finalDrive

    differential.inputTorque =
        inputTorque

    Differential.update(
        runtime.differential,
        nextState
    )

    return true
end

local function phaseSuspension()
    local nextState =
        State.getNext(
            runtime.state
        )

    Suspension.update(
        runtime.suspension,
        nextState
    )

    return true
end

local function phaseWheel()
    local nextState =
        State.getNext(
            runtime.state
        )

    Wheel.updateDynamics(
        nextState,
        runtime.scheduler.dt
    )

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

    local current =
        State.getCurrent(
            runtime.state
        )

    local powertrain =
        current.powertrain

    local differential =
        powertrain.differential

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
        'State: ' ..
        tostring(
            runtime.state.valid
        )
    )

    ui.text(
        'Speed: ' ..
        string.format(
            '%.2f km/h',
            current.vehicle.speed
        )
    )

    ui.text(
        'RPM: ' ..
        string.format(
            '%.0f',
            powertrain.engine.rpm
        )
    )

    ui.text(
        'Engine Torque: ' ..
        string.format(
            '%.1f Nm',
            powertrain.engine.torque
        )
    )

    ui.text(
        'Clutch Slip: ' ..
        string.format(
            '%.2f rad/s',
            powertrain.clutch.slip
        )
    )

    ui.text(
        'Gear: ' ..
        tostring(
            powertrain.gearbox.gear
        )
    )

    ui.text(
        'Shaft Torque: ' ..
        string.format(
            '%.1f Nm',
            powertrain.shaft.torque
        )
    )

    ui.text(
        'Diff Lock: ' ..
        string.format(
            '%.3f',
            differential.lockRatio
        )
    )

    ui.text(
        'RL Drive: ' ..
        string.format(
            '%.1f Nm',
            differential.leftTorque
        )
    )

    ui.text(
        'RR Drive: ' ..
        string.format(
            '%.1f Nm',
            differential.rightTorque
        )
    )

    ui.text(
        'STATUS: ' ..
        (
            status.error
            and 'ERROR'
            or 'READY'
        )
    )

    if status.error then
        ui.text(
            tostring(status.error)
        )
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
