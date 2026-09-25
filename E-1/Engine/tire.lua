local Tire = {}

Tire.VERSION = 'E-5'

local WHEELS = {
    'FL',
    'FR',
    'RL',
    'RR'
}

function Tire.create(model)
    return {
        version = Tire.VERSION,
        model = model
    }
end

function Tire.update(
    engine,
    state
)
    for _, name in ipairs(WHEELS) do

        local wheel =
            state.wheels[name]

        local tire =
            state.tires[name]

        if wheel and tire then

            local load =
                wheel.load or 0

            local slipRatio =
                wheel.slipRatio or 0

            local slipAngle =
                wheel.slipAngle or 0

            local result =
                engine.model.solve(
                    engine.model,
                    load,
                    slipRatio,
                    slipAngle
                )

            tire.load =
                load

            tire.slipRatio =
                slipRatio

            tire.slipAngle =
                slipAngle

            tire.combinedSlip =
                result.combined

            tire.force.longitudinal =
                result.longitudinal

            tire.force.lateral =
                result.lateral

            tire.force.vertical =
                load

            tire.valid = true

            wheel.torque.tire =
                -result.longitudinal *
                math.max(
                    wheel.radius,
                    0.01
                )
        end
    end
end

return Tire
