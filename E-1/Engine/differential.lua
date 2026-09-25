local Differential = {}

Differential.VERSION = 'E-6'

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

function Differential.create(
    definition
)
    return {
        version =
            Differential.VERSION,

        definition =
            definition,

        inputTorque = 0,

        leftTorque = 0,
        rightTorque = 0,

        leftOmega = 0,
        rightOmega = 0,

        omegaDifference = 0,

        lockRatio = 0,
        lockTorque = 0,

        reactionTorque = 0
    }
end

function Differential.update(
    engine,
    state
)
    local diff =
        state.powertrain.differential

    local leftWheel =
        state.wheels.RL

    local rightWheel =
        state.wheels.RR

    local definition =
        engine.definition

    local inputTorque =
        diff.inputTorque

    local leftOmega =
        leftWheel.omega or 0

    local rightOmega =
        rightWheel.omega or 0

    local omegaDifference =
        leftOmega -
        rightOmega

    diff.leftOmega =
        leftOmega

    diff.rightOmega =
        rightOmega

    diff.omegaDifference =
        omegaDifference

    local preload =
        definition.preload or 0

    local powerLock =
        definition.powerLock or 0

    local coastLock =
        definition.coastLock or 0

    local lockTorque =
        preload

    if inputTorque >= 0 then
        lockTorque =
            lockTorque +
            math.abs(
                inputTorque
            ) *
            powerLock
    else
        lockTorque =
            lockTorque +
            math.abs(
                inputTorque
            ) *
            coastLock
    end

    local normalizedDifference =
        clamp(
            math.abs(
                omegaDifference
            ) / 10,
            0,
            1
        )

    local effectiveLock =
        lockTorque *
        normalizedDifference

    local baseTorque =
        inputTorque * 0.5

    local transfer =
        effectiveLock

    if omegaDifference > 0 then
        transfer = -transfer
    elseif omegaDifference < 0 then
        transfer = transfer
    else
        transfer = 0
    end

    local leftTorque =
        baseTorque +
        transfer

    local rightTorque =
        baseTorque -
        transfer

    diff.leftTorque =
        leftTorque

    diff.rightTorque =
        rightTorque

    diff.lockTorque =
        effectiveLock

    diff.lockRatio =
        clamp(
            effectiveLock /
            math.max(
                math.abs(inputTorque),
                1
            ),
            0,
            1
        )

    diff.reactionTorque =
        leftTorque +
        rightTorque

    leftWheel.torque.drive =
        leftTorque

    rightWheel.torque.drive =
        rightTorque
end

return Differential
