local Suspension = {}

Suspension.VERSION = 'E-5'

local WHEELS = {
    'FL',
    'FR',
    'RL',
    'RR'
}

local DEFAULTS = {
    FL = {
        spring = 35000,
        damper = 600,
        staticLoad = 3500
    },

    FR = {
        spring = 35000,
        damper = 600,
        staticLoad = 3500
    },

    RL = {
        spring = 45000,
        damper = 900,
        staticLoad = 3500
    },

    RR = {
        spring = 45000,
        damper = 900,
        staticLoad = 3500
    }
}

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

function Suspension.create(definition)
    return {
        version =
            Suspension.VERSION,

        wheels =
            definition or DEFAULTS
    }
end

function Suspension.update(
    engine,
    state
)
    for _, name in
        ipairs(WHEELS) do

        local wheel =
            state.wheels[name]

        if wheel then

            local definition =
                engine.wheels[name] or
                DEFAULTS[name]

            local travel =
                wheel.suspensionTravel or 0

            local velocity =
                wheel.suspensionVelocity or 0

            local springForce =
                -definition.spring *
                travel

            local damperForce =
                -definition.damper *
                velocity

            local dynamicForce =
                springForce +
                damperForce

            local load =
                definition.staticLoad +
                dynamicForce

            load =
                clamp(
                    load,
                    0,
                    30000
                )

            wheel.load =
                load
        end
    end
end

return Suspension
