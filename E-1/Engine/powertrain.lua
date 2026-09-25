local Powertrain = {}

Powertrain.VERSION = 'E-6'

local function clamp(
    value,
    minimum,
    maximum
)
    if value < minimum then
        return minimum
    end

    if value > maximum then
        return maximum
    end

    return value
end

local function interpolateTorque(
    curve,
    rpm
)
    if not curve or #curve == 0 then
        return 0
    end

    if rpm <= curve[1].rpm then
        return curve[1].torque
    end

    for i = 1, #curve - 1 do
        local a = curve[i]
        local b = curve[i + 1]

        if rpm <= b.rpm then
            local span =
                b.rpm - a.rpm

            if span <= 0 then
                return a.torque
            end

            local t =
                (rpm - a.rpm) / span

            return
                a.torque +
                (b.torque - a.torque) * t
        end
    end

    return curve[#curve].torque
end

function Powertrain.create(
    definition
)
    return {
        version =
            Powertrain.VERSION,

        definition =
            definition,

        engineOmega = 0,
        engineTorque = 0,

        clutchOmegaInput = 0,
        clutchOmegaOutput = 0,

        clutchSlip = 0,
        clutchTorque = 0,

        gearboxOmega = 0,
        gearboxTorque = 0,

        shaftOmega = 0,
        shaftTorque = 0,

        shaftTwist = 0
    }
end

function Powertrain.engineTorque(
    engine,
    rpm,
    throttle
)
    local definition =
        engine.definition.engine

    local base =
        interpolateTorque(
            definition.torqueCurve,
            rpm
        )

    local throttleInput =
        clamp(
            throttle or 0,
            0,
            1
        )

    return base * throttleInput
end

function Powertrain.updateEngine(
    engine,
    state,
    dt
)
    local vehicle =
        state.vehicle

    local powertrain =
        state.powertrain

    local definition =
        engine.definition.engine

    local throttle =
        vehicle.gas or 0

    local rpm =
        powertrain.engine.rpm

    if rpm <= 0 then
        rpm =
            definition.idleRPM
    end

    local torque =
        Powertrain.engineTorque(
            engine,
            rpm,
            throttle
        )

    local omega =
        powertrain.engine.omega

    if omega <= 0 then
        omega =
            rpm *
            math.pi /
            30
    end

    local loadTorque =
        powertrain.clutch.torque

    local angularAcceleration =
        (
            torque -
            loadTorque
        ) /
        math.max(
            definition.inertia,
            0.001
        )

    omega =
        omega +
        angularAcceleration * dt

    local minimumOmega =
        definition.idleRPM *
        math.pi /
        30

    omega =
        math.max(
            omega,
            minimumOmega
        )

    powertrain.engine.omega =
        omega

    powertrain.engine.rpm =
        omega *
        30 /
        math.pi

    powertrain.engine.torque =
        torque
end

function Powertrain.updateClutch(
    engine,
    state,
    dt
)
    local powertrain =
        state.powertrain

    local clutch =
        powertrain.clutch

    local definition =
        engine.definition.clutch

    local engineOmega =
        powertrain.engine.omega

    local outputOmega =
        powertrain.gearbox.omega

    clutch.inputOmega =
        engineOmega

    clutch.outputOmega =
        outputOmega

    clutch.slip =
        engineOmega -
        outputOmega

    local targetTorque =
        clutch.slip *
        definition.engagementRate

    local availableTorque =
        definition.capacity

    clutch.torque =
        clamp(
            targetTorque,
            -availableTorque,
            availableTorque
        )
end

function Powertrain.updateGearbox(
    engine,
    state
)
    local powertrain =
        state.powertrain

    local vehicle =
        state.vehicle

    local definition =
        engine.definition.gearbox

    local gear =
        vehicle.gear or 0

    local ratio =
        definition.ratios[gear] or 0

    local engineOmega =
        powertrain.clutch.inputOmega

    local gearboxOmega = 0

    if math.abs(ratio) > 0.001 then
        gearboxOmega =
            engineOmega / ratio
    end

    powertrain.gearbox.gear =
        gear

    powertrain.gearbox.ratio =
        ratio

    powertrain.gearbox.omega =
        gearboxOmega

    powertrain.gearbox.finalDrive =
        definition.finalDrive
end

function Powertrain.updateShaft(
    engine,
    state,
    dt
)
    local powertrain =
        state.powertrain

    local definition =
        engine.definition

    local gearbox =
        definition.gearbox

    local shaft =
        definition.shaft

    local gearboxOmega =
        powertrain.gearbox.omega

    local differentialOmega =
        state.powertrain.differential.leftTorque +
        state.powertrain.differential.rightTorque

    local shaftOmega =
        powertrain.shaft.omega

    if shaftOmega == 0 then
        shaftOmega =
            gearboxOmega
    end

    local deltaOmega =
        gearboxOmega -
        shaftOmega

    local shaftTorque =
        shaft.stiffness *
        powertrain.shaft.twist +
        shaft.damping *
        deltaOmega

    local ratio =
        powertrain.gearbox.ratio

    local finalDrive =
        gearbox.finalDrive or 1

    if math.abs(ratio) > 0.001 then
        shaftTorque =
            shaftTorque *
            ratio *
            finalDrive
    end

    local torqueDemand =
        differentialOmega

    shaftTorque =
        shaftTorque -
        torqueDemand

    shaftOmega =
        shaftOmega +
        deltaOmega *
        dt

    powertrain.shaft.omega =
        shaftOmega

    powertrain.shaft.torque =
        shaftTorque

    powertrain.shaft.twist =
        powertrain.shaft.twist +
        deltaOmega * dt
end

function Powertrain.update(
    engine,
    state,
    dt
)
    Powertrain.updateEngine(
        engine,
        state,
        dt
    )

    Powertrain.updateClutch(
        engine,
        state,
        dt
    )

    Powertrain.updateGearbox(
        engine,
        state
    )

    Powertrain.updateShaft(
        engine,
        state,
        dt
    )
end

return Powertrain
