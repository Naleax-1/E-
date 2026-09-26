-- DETOX
-- E-9 Core State

local State = {}

State.VERSION = "E-9"

local WHEEL_NAMES = {
  "FL",
  "FR",
  "RL",
  "RR"
}

local function vec3()
  return {
    x = 0.0,
    y = 0.0,
    z = 0.0
  }
end

local function zeroTorque()
  return {
    drive = 0.0,
    brake = 0.0,
    tire = 0.0,
    loss = 0.0
  }
end

local function makeWheel()
  return {
    position = vec3(),

    radius = 0.33,
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

    force = {
      longitudinal = 0.0,
      lateral = 0.0,
      vertical = 0.0
    },

    suspensionTravel = 0.0,
    suspensionVelocity = 0.0,

    contact = false,
    valid = false
  }
end

local function makeTire()
  return {
    load = 0.0,

    slipRatio = 0.0,
    slipAngle = 0.0,
    combinedSlip = 0.0,

    surfaceTemperature = 30.0,
    carcassTemperature = 30.0,

    pressure = 0.0,
    wear = 0.0,

    carcassDeflection = 0.0,
    carcassVelocity = 0.0,
    carcassEnergy = 0.0,
    carcassHysteresis = 0.0,

    heatInput = 0.0,
    cooling = 0.0,
    slipEnergy = 0.0,

    thermalGrip = 1.0,

    force = {
      longitudinal = 0.0,
      lateral = 0.0,
      vertical = 0.0
    },

    reactionTorque = 0.0,

    valid = false
  }
end

local function makeVehicle()
  return {
    valid = false,

    mass = 1300.0,

    dt = 1.0 / 333.0,
    time = 0.0,

    speed = 0.0,

    velocity = vec3(),
    acceleration = vec3(),

    position = vec3(),

    heading = 0.0
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

    position = vec3(),

    attitude = {
      roll = 0.0,
      pitch = 0.0,
      yaw = 0.0
    },

    valid = false
  }
end

local function makePowertrain()
  return {
    engine = {
      omega = 0.0,
      rpm = 0.0,
      torque = 0.0,
      temperature = 0.0
    },

    clutch = {
      inputOmega = 0.0,
      outputOmega = 0.0,
      slip = 0.0,
      torque = 0.0
    },

    gearbox = {
      gear = 0,
      ratio = 0.0,
      omega = 0.0
    },

    shaft = {
      twist = 0.0,
      omega = 0.0,
      torque = 0.0
    },

    differential = {
      inputTorque = 0.0,
      lockRatio = 0.0,
      lockTorque = 0.0,
      leftTorque = 0.0,
      rightTorque = 0.0,
      reactionTorque = 0.0
    }
  }
end

local function makeSnapshot()
  local snapshot = {
    vehicle = makeVehicle(),
    body = makeBody(),

    wheels = {},
    tires = {},

    powertrain = makePowertrain(),

    coupled = {
      iterations = 0,
      converged = false,

      residual = {
        force = 0.0,
        torque = 0.0,
        velocity = 0.0
      }
    },

    diagnostics = {
      valid = true,
      errors = 0,
      lastError = ""
    }
  }

  for _, name in ipairs(WHEEL_NAMES) do
    snapshot.wheels[name] =
        makeWheel()

    snapshot.tires[name] =
        makeTire()
  end

  return snapshot
end

local function deepCopy(value)
  if type(value) ~= "table" then
    return value
  end

  local result = {}

  for key, child in pairs(value) do
    result[key] =
        deepCopy(child)
  end

  return result
end

function State.create()
  return {
    schema = "DETOX.State.1",

    frame = 0,
    valid = false,

    previous = makeSnapshot(),
    current = makeSnapshot(),
    next = makeSnapshot()
  }
end

function State.reset(state)
  state.frame = 0
  state.valid = false

  state.previous =
      makeSnapshot()

  state.current =
      makeSnapshot()

  state.next =
      makeSnapshot()
end

function State.beginTick(state)
  state.previous =
      deepCopy(
        state.current
      )

  state.next =
      deepCopy(
        state.current
      )

  state.frame =
      state.frame + 1
end

function State.commit(state)
  local oldCurrent =
      state.current

  state.current =
      state.next

  state.next =
      oldCurrent

  state.valid =
      state.current.diagnostics.valid
end

function State.getWheelNames()
  return WHEEL_NAMES
end

function State.copySnapshot(snapshot)
  return deepCopy(snapshot)
end

return State
