--============================================================
-- DETOX - Core State
-- E-1 Core State Implementation
--============================================================

local State = {}

local WHEEL_NAMES = { 'FL', 'FR', 'RL', 'RR' }

local function vec3(x, y, z)
    return {
        x = x or 0.0,
        y = y or 0.0,
        z = z or 0.0,
    }
end

local function zeroTorque()
    return {
        drive = 0.0,
        brake = 0.0,
        tire = 0.0,
        loss = 0.0,
    }
end

local function makeWheel()
    return {
        position = vec3(),
        radius = 0.0,
        rotation = 0.0,
        omega = 0.0,
        angularAcceleration = 0.0,
        torque = zeroTorque(),
        contactVelocity = vec3(),
        longitudinalVelocity = 0.0,
        lateralVelocity = 0.0,
        slipRatio = 0.0,
        slipAngle = 0.0,
        load = 0.0,
        force = vec3(),
        suspensionTravel = 0.0,
        suspensionVelocity = 0.0,
        contact = false,
        valid = false,
    }
end

local function makeTire()
    return {
        load = 0.0,
        slipRatio = 0.0,
        slipAngle = 0.0,
        combinedSlip = 0.0,
        surfaceTemperature = 25.0,
        carcassTemperature = 25.0,
        pressure = 0.0,
        wear = 0.0,
        carcassDeflection = 0.0,
        carcassVelocity = 0.0,
        carcassEnergy = 0.0,
        force = {
            longitudinal = 0.0,
            lateral = 0.0,
            vertical = 0.0,
        },
        reactionTorque = 0.0,
        valid = false,
    }
end

local function makeVehicle()
    return {
        valid = false,
        mass = 0.0,
        dt = 0.0,
        time = 0.0,
        speed = 0.0,
        velocity = vec3(),
        acceleration = vec3(),
        position = vec3(),
        heading = 0.0,
    }
end

local function makeBody()
    return {
        force = vec3(),
        moment = vec3(),
        acceleration = vec3(),
        angularAcceleration = vec3(),
        velocity = vec3(),
        angularVelocity = vec3(),
        attitude = {
            roll = 0.0,
            pitch = 0.0,
            yaw = 0.0,
        },
        valid = false,
    }
end

local function makePowertrain()
    return {
        engine = {
            omega = 0.0,
            rpm = 0.0,
            torque = 0.0,
            temperature = 0.0,
        },
        clutch = {
            inputOmega = 0.0,
            outputOmega = 0.0,
            slip = 0.0,
            torque = 0.0,
        },
        gearbox = {
            gear = 0,
            ratio = 1.0,
            omega = 0.0,
        },
        shaft = {
            twist = 0.0,
            omega = 0.0,
            torque = 0.0,
        },
        differential = {
            lockRatio = 0.0,
            lockTorque = 0.0,
            leftTorque = 0.0,
            rightTorque = 0.0,
        },
        valid = false,
    }
end

local function makeState()
    local state = {
        schema = 'DETOX.State.1',
        frame = 0,
        valid = false,
        previous = nil,
        current = nil,
        next = nil,
    }

    local function makeSnapshot()
        local snapshot = {
            vehicle = makeVehicle(),
            body = makeBody(),
            wheels = {},
            tires = {},
            powertrain = makePowertrain(),
            diagnostics = {
                valid = true,
                nan = 0,
                inf = 0,
                errors = 0,
            },
        }

        for i = 1, #WHEEL_NAMES do
            snapshot.wheels[WHEEL_NAMES[i]] = makeWheel()
            snapshot.tires[WHEEL_NAMES[i]] = makeTire()
        end

        return snapshot
    end

    state.previous = makeSnapshot()
    state.current = makeSnapshot()
    state.next = makeSnapshot()

    return state
end

local function copyVec3(dst, src)
    dst.x = src.x
    dst.y = src.y
    dst.z = src.z
end

local function copySnapshot(dst, src)
    local dv, sv = dst.vehicle, src.vehicle
    dv.valid = sv.valid
    dv.mass = sv.mass
    dv.dt = sv.dt
    dv.time = sv.time
    dv.speed = sv.speed
    copyVec3(dv.velocity, sv.velocity)
    copyVec3(dv.acceleration, sv.acceleration)
    copyVec3(dv.position, sv.position)
    dv.heading = sv.heading

    local db, sb = dst.body, src.body
    db.valid = sb.valid
    copyVec3(db.force, sb.force)
    copyVec3(db.moment, sb.moment)
    copyVec3(db.acceleration, sb.acceleration)
    copyVec3(db.angularAcceleration, sb.angularAcceleration)
    copyVec3(db.velocity, sb.velocity)
    copyVec3(db.angularVelocity, sb.angularVelocity)
    db.attitude.roll = sb.attitude.roll
    db.attitude.pitch = sb.attitude.pitch
    db.attitude.yaw = sb.attitude.yaw

    for i = 1, #WHEEL_NAMES do
        local name = WHEEL_NAMES[i]
        local dw, sw = dst.wheels[name], src.wheels[name]
        dw.valid = sw.valid
        dw.radius = sw.radius
        dw.rotation = sw.rotation
        dw.omega = sw.omega
        dw.angularAcceleration = sw.angularAcceleration
        dw.contact = sw.contact
        dw.load = sw.load
        dw.longitudinalVelocity = sw.longitudinalVelocity
        dw.lateralVelocity = sw.lateralVelocity
        dw.slipRatio = sw.slipRatio
        dw.slipAngle = sw.slipAngle
        dw.suspensionTravel = sw.suspensionTravel
        dw.suspensionVelocity = sw.suspensionVelocity
        copyVec3(dw.position, sw.position)
        copyVec3(dw.contactVelocity, sw.contactVelocity)
        copyVec3(dw.force, sw.force)
        dw.torque.drive = sw.torque.drive
        dw.torque.brake = sw.torque.brake
        dw.torque.tire = sw.torque.tire
        dw.torque.loss = sw.torque.loss

        local dt, st = dst.tires[name], src.tires[name]
        dt.valid = st.valid
        dt.load = st.load
        dt.slipRatio = st.slipRatio
        dt.slipAngle = st.slipAngle
        dt.combinedSlip = st.combinedSlip
        dt.surfaceTemperature = st.surfaceTemperature
        dt.carcassTemperature = st.carcassTemperature
        dt.pressure = st.pressure
        dt.wear = st.wear
        dt.carcassDeflection = st.carcassDeflection
        dt.carcassVelocity = st.carcassVelocity
        dt.carcassEnergy = st.carcassEnergy
        dt.force.longitudinal = st.force.longitudinal
        dt.force.lateral = st.force.lateral
        dt.force.vertical = st.force.vertical
        dt.reactionTorque = st.reactionTorque
    end

    local dp, sp = dst.powertrain, src.powertrain
    dp.valid = sp.valid
    dp.engine.omega = sp.engine.omega
    dp.engine.rpm = sp.engine.rpm
    dp.engine.torque = sp.engine.torque
    dp.engine.temperature = sp.engine.temperature
    dp.clutch.inputOmega = sp.clutch.inputOmega
    dp.clutch.outputOmega = sp.clutch.outputOmega
    dp.clutch.slip = sp.clutch.slip
    dp.clutch.torque = sp.clutch.torque
    dp.gearbox.gear = sp.gearbox.gear
    dp.gearbox.ratio = sp.gearbox.ratio
    dp.gearbox.omega = sp.gearbox.omega
    dp.shaft.twist = sp.shaft.twist
    dp.shaft.omega = sp.shaft.omega
    dp.shaft.torque = sp.shaft.torque
    dp.differential.lockRatio = sp.differential.lockRatio
    dp.differential.lockTorque = sp.differential.lockTorque
    dp.differential.leftTorque = sp.differential.leftTorque
    dp.differential.rightTorque = sp.differential.rightTorque

    dst.diagnostics.valid = src.diagnostics.valid
    dst.diagnostics.nan = src.diagnostics.nan
    dst.diagnostics.inf = src.diagnostics.inf
    dst.diagnostics.errors = src.diagnostics.errors
end

function State.create()
    return makeState()
end

function State.reset(state)
    if not state then
        return false
    end

    local fresh = makeState()
    state.schema = fresh.schema
    state.frame = 0
    state.valid = false
    state.previous = fresh.previous
    state.current = fresh.current
    state.next = fresh.next
    return true
end

function State.beginTick(state, dt)
    if not state or not state.current or not state.next then
        return false
    end

    state.frame = state.frame + 1
    state.previous, state.current = state.current, state.next
    copySnapshot(state.next, state.current)

    state.next.vehicle.dt = tonumber(dt) or 0.0
    state.next.vehicle.time = state.current.vehicle.time + state.next.vehicle.dt
    state.next.diagnostics.valid = true
    state.next.diagnostics.nan = 0
    state.next.diagnostics.inf = 0
    state.next.diagnostics.errors = 0

    return true
end

function State.commit(state)
    if not state or not state.next then
        return false
    end

    state.valid = state.next.diagnostics.valid ~= false
    if not state.valid then
        return false
    end

    return true
end

function State.getWheelNames()
    return WHEEL_NAMES
end

function State.copySnapshot(dst, src)
    if not dst or not src then
        return false
    end
    copySnapshot(dst, src)
    return true
end

return State
