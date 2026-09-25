-- DETOX
-- E-7 Tire Model

local TireModel = {}

TireModel.VERSION = "E-7"

local DEFAULT = {
  referenceLoad = 3500.0,

  peakLongitudinal = 1.0,
  peakLateral = 1.0,

  slipRatioScale = 8.0,
  slipAngleScale = 8.0,

  combinedLimit = 1.0,

  carcassDeflectionGain = 0.08,
  carcassEnergyGain = 0.00001,

  minimumThermalGrip = 0.55,
  maximumThermalGrip = 1.05
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

function TireModel.create(definition)
  local model = copyDefaults()

  if definition then
    for key, value in pairs(definition) do
      model[key] = value
    end
  end

  return model
end

function TireModel.solve(model, input)
  local load =
      math.max(input.load or 0.0, 0.0)

  local slipRatio =
      input.slipRatio or 0.0

  local slipAngle =
      input.slipAngle or 0.0

  local thermalGrip =
      clamp(
        input.thermalGrip or 1.0,
        model.minimumThermalGrip,
        model.maximumThermalGrip
      )

  local carcassDeflection =
      math.max(
        input.carcassDeflection or 0.0,
        0.0
      )

  local carcassEnergy =
      math.max(
        input.carcassEnergy or 0.0,
        0.0
      )

  local loadRatio =
      load / math.max(model.referenceLoad, 1.0)

  local loadFactor =
      math.sqrt(
        math.max(loadRatio, 0.0)
      )

  local carcassFactor =
      1.0
      + carcassDeflection
      * model.carcassDeflectionGain

  carcassFactor =
      carcassFactor
      / (
        1.0
        + carcassEnergy
        * model.carcassEnergyGain
      )

  local longitudinalResponse =
      math.tanh(
        slipRatio
        * model.slipRatioScale
      )

  local lateralResponse =
      math.tanh(
        slipAngle
        * model.slipAngleScale
      )

  local fx =
      model.peakLongitudinal
      * load
      * loadFactor
      * thermalGrip
      * carcassFactor
      * longitudinalResponse

  local fy =
      model.peakLateral
      * load
      * loadFactor
      * thermalGrip
      * carcassFactor
      * lateralResponse

  local normalizedFx =
      fx / math.max(load, 1.0)

  local normalizedFy =
      fy / math.max(load, 1.0)

  local combined =
      math.sqrt(
        normalizedFx * normalizedFx
        + normalizedFy * normalizedFy
      )

  if combined > model.combinedLimit then
    local scale =
        model.combinedLimit / combined

    fx = fx * scale
    fy = fy * scale
  end

  return {
    longitudinal = fx,
    lateral = fy,
    vertical = load,

    combinedSlip = combined,

    thermalGrip = thermalGrip,
    carcassDeflection = carcassDeflection,

    valid = true
  }
end

return TireModel
