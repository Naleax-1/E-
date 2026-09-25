-- DETOX
-- E-7 Thermal Engine

local Thermal = {}

Thermal.VERSION = "E-7"

local WHEEL_NAMES = {
  "FL",
  "FR",
  "RL",
  "RR"
}

function Thermal.create(model)
  return {
    model = model,
    valid = false
  }
end

function Thermal.update(state, model)
  local dt =
      state.next.vehicle.dt or
      (1.0 / 333.0)

  local speed =
      math.abs(state.next.vehicle.speed or 0.0)

  for _, name in ipairs(WHEEL_NAMES) do
    local wheel = state.next.wheels[name]
    local tire = state.next.tires[name]

    if wheel and tire then

      local fx =
          tire.force.longitudinal or 0.0

      local fy =
          tire.force.lateral or 0.0

      local vx =
          wheel.longitudinalVelocity or 0.0

      local vy =
          wheel.lateralVelocity or 0.0

      local slipEnergy =
          math.abs(fx * vx)
          + math.abs(fy * vy)

      local thermalState = {
        surfaceTemperature =
            tire.surfaceTemperature or
            model.surfaceInitial,

        carcassTemperature =
            tire.carcassTemperature or
            model.carcassInitial,

        heatInput = tire.heatInput or 0.0,
        cooling = tire.cooling or 0.0,
        slipEnergy = tire.slipEnergy or 0.0,

        thermalGrip =
            tire.thermalGrip or 1.0,

        valid = true
      }

      model.solve(
        model,
        thermalState,
        {
          dt = dt,
          speed = speed,
          load = wheel.load or 0.0,
          slipEnergy = slipEnergy,
          ambientTemperature =
              model.ambientTemperature
        }
      )

      tire.surfaceTemperature =
          thermalState.surfaceTemperature

      tire.carcassTemperature =
          thermalState.carcassTemperature

      tire.heatInput =
          thermalState.heatInput

      tire.cooling =
          thermalState.cooling

      tire.slipEnergy =
          thermalState.slipEnergy

      tire.thermalGrip =
          thermalState.thermalGrip

      tire.valid = true
    end
  end

  return true
end

return Thermal
