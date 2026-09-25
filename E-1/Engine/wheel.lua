local Wheel = {}

Wheel.VERSION = 'E-4'

Wheel.WHEEL_INERTIA = 1.8
Wheel.DEFAULT_RADIUS = 0.33

Wheel.TORQUE_LOSS = 0.0

local WHEELS = {
    'FL',
    'FR',
    'RL',
    'RR'
}

local function vec3(x, y, z)
    return {
        x = x or 0,
        y = y or 0,
        z = z or 0
    }
end

local function cross(a, b)
    return {
        x = a.y * b.z - a.z * b.y,
        y = a.z * b.x - a.x * b.z,
        z = a.x * b.y - a.y * b.x
    }
end

local function length(v)
    return math.sqrt(
        v.x * v.x +
        v.y * v.y +
        v.z * v.z
    )
end

local function clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end

    if value > maxValue then
        return maxValue
    end

    return value
end

local function wheelPosition(wheel)
    if wheel.position then
        return wheel.position
    end

    return vec3()
end

function Wheel.create()
    return {
        version = Wheel.VERSION,

        inertia = Wheel.WHEEL_INERTIA,

        wheels = {
            FL = {},
            FR = {},
            RL = {},
            RR = {}
        }
    }
end

function Wheel.reset(engine)
    for _, name in ipairs(WHEELS) do
        engine.wheels[name] = {}
    end
end

function Wheel.updateKinematics(
    state
)
    local body = state.body

    local bodyVelocity =
        body.velocity or vec3()

    local bodyAngularVelocity =
        body.angularVelocity or vec3()

    for _, name in ipairs(WHEELS) do

        local wheel =
            state.wheels[name]

        if wheel then
            local position =
                wheelPosition(wheel)

            local rotationalVelocity =
                cross(
                    bodyAngularVelocity,
                    position
                )

            local contactVelocity = {
                x =
                    bodyVelocity.x +
                    rotationalVelocity.x,

                y =
                    bodyVelocity.y +
                    rotationalVelocity.y,

                z =
                    bodyVelocity.z +
                    rotationalVelocity.z
            }

            wheel.contactVelocity =
                contactVelocity

            wheel.longitudinalVelocity =
                contactVelocity.z

            wheel.lateralVelocity =
                contactVelocity.x
        end
    end
end

function Wheel.updateDynamics(
    state,
    dt
)
    if dt <= 0 then
        return
    end

    for _, name in ipairs(WHEELS) do

        local wheel =
            state.wheels[name]

        if wheel then

            local radius =
                wheel.radius

            if radius <= 0 then
                radius =
                    Wheel.DEFAULT_RADIUS

                wheel.radius =
                    radius
            end

            local inertia =
                Wheel.WHEEL_INERTIA

            if inertia <= 0 then
                inertia = 1.0
            end

            local driveTorque =
                wheel.torque.drive or 0

            local brakeTorque =
                wheel.torque.brake or 0

            local tireTorque =
                wheel.torque.tire or 0

            local lossTorque =
                wheel.torque.loss or 0

            local totalTorque =
                driveTorque
                - brakeTorque
                - tireTorque
                - lossTorque

            local angularAcceleration =
                totalTorque / inertia

            local omega =
                wheel.omega or 0

            omega =
                omega +
                angularAcceleration * dt

            wheel.angularAcceleration =
                angularAcceleration

            wheel.omega =
                omega

            wheel.rotation =
                (wheel.rotation or 0)
                + omega * dt
        end
    end
end

function Wheel.updateSlip(
    state
)
    for _, name in ipairs(WHEELS) do

        local wheel =
            state.wheels[name]

        if wheel then

            local radius =
                wheel.radius

            if radius <= 0 then
                radius =
                    Wheel.DEFAULT_RADIUS

                wheel.radius =
                    radius
            end

            local wheelVelocity =
                wheel.omega * radius

            local referenceVelocity =
                wheel.longitudinalVelocity or 0

            local denominator =
                math.max(
                    math.abs(referenceVelocity),
                    0.5
                )

            local slip =
                (
                    wheelVelocity -
                    referenceVelocity
                ) / denominator

            wheel.slipRatio =
                clamp(
                    slip,
                    -5.0,
                    5.0
                )

            local lateralVelocity =
                wheel.lateralVelocity or 0

            local longitudinalVelocity =
                math.abs(
                    referenceVelocity
                )

            if longitudinalVelocity > 0.5 then
                wheel.slipAngle =
                    math.atan(
                        lateralVelocity /
                        longitudinalVelocity
                    )
            else
                wheel.slipAngle = 0
            end
        end
    end
end

function Wheel.update(
    state,
    dt
)
    Wheel.updateKinematics(state)

    Wheel.updateDynamics(
        state,
        dt
    )

    Wheel.updateSlip(state)
end

return Wheel
