-- DETOX
-- E-8 Body Dynamics Engine

local Body = {}

Body.VERSION = "E-8"

local WHEEL_NAMES = {
  "FL",
  "FR",
  "RL",
  "RR"
}

local function zeroVector()
  return {
    x = 0.0,
    y = 0.0,
    z = 0.0
  }
end

local function addForce(target, source)
  target.x = target.x + (source.x or 0.0)
  target.y = target.y + (source.y or 0.0)
  target.z = target.z + (source.z or 0.0)
end

local function cross(a, b)
  return {
    x = a.y * b.z - a.z * b.y,
    y = a.z * b.x - a.x * b.z,
    z = a.x * b.y - a.y * b.x
  }
end

function Body.create(model)
  return {
    model = model,
    valid = false
  }
end

function Body.update(state, model)
  local body = state.next.body

  local dt =
      state.next.vehicle.dt or
      (1.0 / 333.0)

  local totalForce = zeroVector()
  local totalMoment = zeroVector()

  -- Gravity
  totalForce.z =
      totalForce.z
      - model.mass * model.gravity

  for _, name in ipairs(WHEEL_NAMES) do
    local wheel =
        state.next.wheels[name]

    local tire =
        state.next.tires[name]

    if wheel and tire then

      local force = {
        x = tire.force.longitudinal or 0.0,
        y = tire.force.lateral or 0.0,
        z = wheel.load or 0.0
      }

      addForce(
        totalForce,
        force
      )

      local position = {
        x = wheel.position.x or 0.0,
        y = wheel.position.y or 0.0,
        z = wheel.position.z or 0.0
      }

      local moment =
          cross(
            position,
            force
          )

      addForce(
        totalMoment,
        moment
      )
    end
  end

  body.force.x =
      totalForce.x

  body.force.y =
      totalForce.y

  body.force.z =
      totalForce.z

  body.moment.x =
      totalMoment.x

  body.moment.y =
      totalMoment.y

  body.moment.z =
      totalMoment.z

  local acceleration =
      model.acceleration(
        totalForce
      )

  local angularAcceleration =
      model.angularAcceleration(
        totalMoment
      )

  body.acceleration.x =
      acceleration.x

  body.acceleration.y =
      acceleration.y

  body.acceleration.z =
      acceleration.z

  body.angularAcceleration.x =
      angularAcceleration.x

  body.angularAcceleration.y =
      angularAcceleration.y

  body.angularAcceleration.z =
      angularAcceleration.z

  model.integrate(
    model,
    body,
    dt
  )

  body.valid = true

  return true
end

return Body
