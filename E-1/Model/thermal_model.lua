-- DETOX
-- E-7 Thermal Model

local ThermalModel = {}

ThermalModel.VERSION = "E-7"

local DEFAULT = {
  ambientTemperature = 25.0,

  surfaceInitial = 30.0,
  carcassInitial = 30.0,

  optimumTemperature = 85.0,

  surfaceHeatGain = 0.020,
  carcassHeatTransfer = 0.80,

  surfaceTau = 0.45,
  carcassTau = 4.00,
  coolingTau = 12.0,

  coolingSpeedGain = 0.0025,
  coolingLoadGain = 0.00015,

  minGrip = 0.55,
  maxGrip = 1.05,

  heatEnergyScale = 1.0
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

function ThermalModel.create(definition)
  local model = copyDefaults()

  if definition then
    for key, value in pairs(definition) do
      model[key] = value
    end
  end

  return model
end

function ThermalModel.initialState(model)
  return {
    surfaceTemperature = model.surfaceInitial,
    carcassTemperature = model.carcassInitial,

    heatInput = 0.0,
    cooling = 0.0,
    slipEnergy = 0.0,

    thermalGrip = 1.0,
    valid = true
  }
end

function ThermalModel.grip(model, surfaceTemperature, carcassTemperature)
  local optimum = model.optimumTemperature

  local surfaceDelta = math.abs(surfaceTemperature - optimum)
  local carcassDelta = math.abs(carcassTemperature - optimum)

  local surfaceFactor =
      1.0 - clamp(surfaceDelta / optimum, 0.0, 1.0) * 0.35

  local carcassFactor =
      1.0 - clamp(carcassDelta / optimum, 0.0, 1.0) * 0.20

  local grip = surfaceFactor * carcassFactor

  return clamp(
    grip,
    model.minGrip,
    model.maxGrip
  )
end

function ThermalModel.solve(model, state, input)
  local dt = input.dt or (1.0 / 333.0)

  if dt <= 0 then
    dt = 1.0 / 333.0
  end

  local ambient =
      input.ambientTemperature or model.ambientTemperature

  local speed =
      math.abs(input.speed or 0.0)

  local load =
      math.max(input.load or 0.0, 0.0)

  local slipEnergy =
      math.max(input.slipEnergy or 0.0, 0.0)

  local heatInput =
      slipEnergy *
      model.surfaceHeatGain *
      model.heatEnergyScale

  local surfaceToCarcass =
      (state.surfaceTemperature - state.carcassTemperature)
      / model.surfaceTau

  local carcassToAmbient =
      (state.carcassTemperature - ambient)
      / model.carcassTau

  local speedCooling =
      speed * model.coolingSpeedGain

  local loadCooling =
      load * model.coolingLoadGain

  local totalCooling =
      (state.surfaceTemperature - ambient)
      * (model.coolingTau > 0 and 1.0 / model.coolingTau or 0.0)
      * (1.0 + speedCooling + loadCooling)

  local surfaceRate =
      heatInput
      - surfaceToCarcass
      - totalCooling

  local carcassRate =
      surfaceToCarcass
      - carcassToAmbient

  state.surfaceTemperature =
      state.surfaceTemperature + surfaceRate * dt

  state.carcassTemperature =
      state.carcassTemperature + carcassRate * dt

  state.surfaceTemperature =
      math.max(state.surfaceTemperature, ambient)

  state.carcassTemperature =
      math.max(state.carcassTemperature, ambient)

  state.heatInput = heatInput
  state.cooling = totalCooling
  state.slipEnergy = slipEnergy

  state.thermalGrip =
      ThermalModel.grip(
        model,
        state.surfaceTemperature,
        state.carcassTemperature
      )

  state.valid = true

  return state
end

return ThermalModel
