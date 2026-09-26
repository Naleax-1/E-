-- DETOX
-- E-8 Body Dynamics Model

local BodyModel = {}

BodyModel.VERSION = "E-8"

local DEFAULT = {
  mass = 1300.0,

  inertia = {
    x = 650.0,
    y = 1500.0,
    z = 1700.0
  },

  gravity = 9.80665,

  linearDamping = 0.0,
  angularDamping = 0.0
}

local function copyTable(source)
  local result = {}

  for key, value in pairs(source) do
    if type(value) == "table" then
      result[key] = copyTable(value)
    else
      result[key] = value
    end
  end

  return result
end

function BodyModel.create(definition)
  local model = copyTable(DEFAULT)

  if definition then
    for key, value in pairs(definition) do
      if type(value) == "table"
        and type(model[key]) == "table" then

        for childKey, childValue in pairs(value) do
          model[key][childKey] = childValue
        end
      else
        model[key] = value
      end
    end
  end

  return model
end

function BodyModel.acceleration(model, force)
  local mass =
      math.max(model.mass, 1.0)

  return {
    x = force.x / mass,
    y = force.y / mass,
    z = force.z / mass
  }
end

function BodyModel.angularAcceleration(model, moment)
  return {
    x = moment.x /
        math.max(model.inertia.x, 1.0),

    y = moment.y /
        math.max(model.inertia.y, 1.0),

    z = moment.z /
        math.max(model.inertia.z, 1.0)
  }
end

function BodyModel.integrate(
    model,
    body,
    dt
)
  if dt <= 0 then
    return
  end

  -- Semi-Implicit Euler
  body.velocity.x =
      body.velocity.x
      + body.acceleration.x * dt

  body.velocity.y =
      body.velocity.y
      + body.acceleration.y * dt

  body.velocity.z =
      body.velocity.z
      + body.acceleration.z * dt

  body.position.x =
      body.position.x
      + body.velocity.x * dt

  body.position.y =
      body.position.y
      + body.velocity.y * dt

  body.position.z =
      body.position.z
      + body.velocity.z * dt

  body.angularVelocity.x =
      body.angularVelocity.x
      + body.angularAcceleration.x * dt

  body.angularVelocity.y =
      body.angularVelocity.y
      + body.angularAcceleration.y * dt

  body.angularVelocity.z =
      body.angularVelocity.z
      + body.angularAcceleration.z * dt

  body.attitude.roll =
      body.attitude.roll
      + body.angularVelocity.x * dt

  body.attitude.pitch =
      body.attitude.pitch
      + body.angularVelocity.y * dt

  body.attitude.yaw =
      body.attitude.yaw
      + body.angularVelocity.z * dt
end

return BodyModel
