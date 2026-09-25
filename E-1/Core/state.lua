--============================================================
-- DETOX - Core State
-- E-1 Core State Implementation
--============================================================

local State = {}

State.VERSION = 'DETOX.State.1'

State.WHEEL_NAMES = {
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

local function makeWheel()
    return {
        valid = false,

        position = vec3(),

        radius = 0,
        rotation = 0,
        omega = 0,
        angularAcceleration = 0,

        torque = {
            drive = 0,
            brake = 0,
            tire = 0,
            loss = 0
        },

        contactVelocity = vec3(),

        longitudinalVelocity = 0,
        lateralVelocity = 0,

        slipRatio = 0,
        slipAngle = 0,

        load = 0,

        force = vec3(),

        suspensionTravel = 0,
        suspensionVelocity = 0,

        suspensionForce = 0,
        springForce = 0,
        damperForce = 0,

        contact = false
    }
end

local function makeTire()
    return {
        valid = false,

        load = 0,

        slipRatio = 0,
        slipAngle = 0,
        combinedSlip = 0,

        surfaceTemperature = 0,
        carcassTemperature = 0,

        pressure = 0,
        wear = 0,

        carcassDeflection = 0,
        carcassVelocity = 0,
        carcassEnergy = 0,

        force = {
            longitudinal = 0,
            lateral = 0,
            vertical = 0
        },

        reactionTorque = 0
    }
end

local function makeVehicle()
    return {
        valid = false,

        mass = 0,

        dt = 0,
        time = 0,

        speed = 0,

        velocity = vec3(),
        acceleration = vec3(),

        position = vec3(),

        heading = 0,

        steer = 0,
        gas = 0,
        brake = 0,
        clutch = 0,
        handbrake = 0,

        rpm = 0,
        gear = 0
    }
end

local function makeBody()
    return {
        valid = false,

        force = vec3(),
        moment = vec3(),

        acceleration = vec3(),
        angularAcceleration = vec3(),

        velocity = vec3(),
        angularVelocity = vec3(),

        attitude = {
            roll = 0,
            pitch = 0,
            yaw = 0
        }
    }
end

local function makePowertrain()
    return {
        valid = false,

        engine = {
            omega = 0,
            rpm = 0,
            torque = 0,
            temperature = 0
        },

        clutch = {
            inputOmega = 0,
            outputOmega = 0,
            slip = 0,
            torque = 0
        },

        gearbox = {
            gear = 0,
            ratio = 0,
            omega = 0
        },

        shaft = {
            twist = 0,
            omega = 0,
            torque = 0
        },

        differential = {
            lockRatio = 0,
            lockTorque = 0,
            leftTorque = 0,
            rightTorque = 0
        }
    }
end

local function makeSnapshot()
    local snapshot = {
        vehicle = makeVehicle(),
        body = makeBody(),

        wheels = {},
        tires = {},

        powertrain =
            makePowertrain(),

        diagnostics = {
            valid = false,

            nanCount = 0,
            infCount = 0,

            errorCount = 0
        }
    }

    for _, name in
        ipairs(State.WHEEL_NAMES) do

        snapshot.wheels[name] =
            makeWheel()

        snapshot.tires[name] =
            makeTire()
    end

    return snapshot
end

local function makeState()
    return {
        schema =
            State.VERSION,

        frame = 0,

        valid = false,

        previous =
            makeSnapshot(),

        current =
            makeSnapshot(),

        next =
            makeSnapshot()
    }
end

function State.create()
    return makeState()
end

function State.reset(state)
    local fresh =
        makeState()

    state.schema =
        fresh.schema

    state.frame =
        fresh.frame

    state.valid =
        fresh.valid

    state.previous =
        fresh.previous

    state.current =
        fresh.current

    state.next =
        fresh.next
end

function State.copySnapshot(
    dst,
    src
)
    for key, value in
        pairs(src) do

        if type(value) ==
            'table' then

            if type(dst[key]) ~=
                'table' then

                dst[key] = {}
            end

            State.copySnapshot(
                dst[key],
                value
            )

        else

            dst[key] =
                value

        end
    end
end

function State.beginTick(
    state,
    dt
)
    state.frame =
        state.frame + 1

    state.previous =
        state.current

    state.next =
        makeSnapshot()

    State.copySnapshot(
        state.next,
        state.current
    )

    state.next.vehicle.dt =
        dt or 0

    state.next.vehicle.time =
        state.current.vehicle.time +
        (dt or 0)

    state.valid = false
end

function State.commit(state)
    local diagnostics =
        state.next.diagnostics

    if diagnostics.nanCount > 0 then
        state.valid = false
        return false
    end

    if diagnostics.infCount > 0 then
        state.valid = false
        return false
    end

    state.current =
        state.next

    state.next =
        state.previous

    state.valid = true

    return true
end

function State.getCurrent(state)
    return state.current
end

function State.getPrevious(state)
    return state.previous
end

function State.getNext(state)
    return state.next
end

function State.getWheelNames()
    return State.WHEEL_NAMES
end

return State
