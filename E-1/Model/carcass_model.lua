-- DETOX
-- E-7 Carcass Model

local CarcassModel = {}

CarcassModel.VERSION = "E-7"

local DEFAULT = {
  stiffness = 180000.0,
  damping = 1200.0,

  referenceLoad = 3500.0,
  referenceDeflection = 0.030,

  hysteresisGain = 0.12,
  energyRecoveryTau = 0.80,

  minimumDeflection = 0.0,
  maximumDeflection = 0.120
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

local function copyDefaults()
  local result = {}

  for key, value in pairs(DEFAULT) do
    result[key] = value
  end

  return result
end

function CarcassModel.create(definition)
  local model = copyDefaults()

  if definition then
    for key, value in pairs(definition) do
      model[key] = value
    end
  end

  return model
end

function CarcassModel.initialState()
  return {
    deflection = 0.0,
    velocity = 0.0,
    energy = 0.0,
    hysteresis = 0.0,
    valid = true
  }
end

function CarcassModel.solve(model, state, input)
  local dt = input.dt or (1.0 / 333.0)

  if dt <= 0 then
    dt = 1.0 / 333.0
  end

  local load =
      math.max(input.load or 0.0, 0.0)

  local previousDeflection =
      state.deflection or 0.0

  local loadRatio =
      load / math.max(model.referenceLoad, 1.0)

  local targetDeflection =
      model.referenceDeflection *
      math.sqrt(math.max(loadRatio, 0.0))

  targetDeflection =
      clamp(
        targetDeflection,
        model.minimumDeflection,
        model.maximumDeflection
      )

  local velocity =
      (targetDeflection - previousDeflection) / dt

  local dampingForce =
      velocity * model.damping

  local elasticForce =
      targetDeflection * model.stiffness

  local deformationPower =
      math.abs(dampingForce * velocity)

  local hysteresisTarget =
      deformationPower *
      model.hysteresisGain

  local hysteresisAlpha =
      clamp(
        dt / math.max(model.energyRecoveryTau, dt),
        0.0,
        1.0
      )

  state.hysteresis =
      state.hysteresis
      + (hysteresisTarget - state.hysteresis)
      * hysteresisAlpha

  local energyRate =
      math.abs(elasticForce * velocity)
      + state.hysteresis

  state.energy =
      state.energy
      + energyRate * dt

  local recovery =
      state.energy /
      math.max(model.energyRecoveryTau, 0.001)

  state.energy =
      math.max(
        0.0,
        state.energy - recovery * dt
      )

  state.deflection = targetDeflection
  state.velocity = velocity

  state.valid = true

  return state
end

return CarcassModel
