-- DETOX
-- E-9 Coupled Model

local CoupledModel = {}

CoupledModel.VERSION = "E-9"

local DEFAULT = {
  maxIterations = 3,

  forceTolerance = 5.0,
  torqueTolerance = 0.5,
  velocityTolerance = 0.01,

  relaxation = 0.65
}

local function clamp(value, minValue, maxValue)
  if value < minValue then
    return minValue
  end

  if value > maxValue then
    return maxValue
  end

  return value
end

function CoupledModel.create(definition)
  local model = {}

  for key, value in pairs(DEFAULT) do
    model[key] = value
  end

  if definition then
    for key, value in pairs(definition) do
      model[key] = value
    end
  end

  model.maxIterations =
      math.max(
        1,
        math.floor(model.maxIterations)
      )

  model.relaxation =
      clamp(
        model.relaxation,
        0.0,
        1.0
      )

  return model
end

function CoupledModel.residual(
    previous,
    current
)
  local forceDelta =
      math.abs(
        (current.fx or 0.0)
        - (previous.fx or 0.0)
      )
      +
      math.abs(
        (current.fy or 0.0)
        - (previous.fy or 0.0)
      )

  local torqueDelta =
      math.abs(
        (current.torque or 0.0)
        - (previous.torque or 0.0)
      )

  local velocityDelta =
      math.abs(
        (current.velocity or 0.0)
        - (previous.velocity or 0.0)
      )

  return {
    force = forceDelta,
    torque = torqueDelta,
    velocity = velocityDelta
  }
end

function CoupledModel.converged(
    model,
    residual
)
  return
      residual.force <= model.forceTolerance
      and
      residual.torque <= model.torqueTolerance
      and
      residual.velocity <= model.velocityTolerance
end

return CoupledModel
