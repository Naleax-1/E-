-- DETOX
-- E-7 Carcass Engine

local Carcass = {}

Carcass.VERSION = "E-7"

local WHEEL_NAMES = {
  "FL",
  "FR",
  "RL",
  "RR"
}

function Carcass.create(model)
  return {
    model = model,
    valid = false
  }
end

function Carcass.initializeState(state, model)
  for _, name in ipairs(WHEEL_NAMES) do
    local tire = state.next.tires[name]

    if tire then
      tire.carcassDeflection = 0.0
      tire.carcassVelocity = 0.0
      tire.carcassEnergy = 0.0
      tire.carcassHysteresis = 0.0
    end
  end
end

function Carcass.update(state, model)
  local dt =
      state.next.vehicle.dt or
      (1.0 / 333.0)

  for _, name in ipairs(WHEEL_NAMES) do
    local wheel = state.next.wheels[name]
    local tire = state.next.tires[name]

    if wheel and tire then

      local carcassState = {
        deflection = tire.carcassDeflection or 0.0,
        velocity = tire.carcassVelocity or 0.0,
        energy = tire.carcassEnergy or 0.0,
        hysteresis = tire.carcassHysteresis or 0.0
      }

      CarcassModel.solve(
        model,
        carcassState,
        {
          dt = dt,
          load = wheel.load or 0.0
        }
      )

      tire.carcassDeflection =
          carcassState.deflection

      tire.carcassVelocity =
          carcassState.velocity

      tire.carcassEnergy =
          carcassState.energy

      tire.carcassHysteresis =
          carcassState.hysteresis

      tire.valid = true
    end
  end

  Carcass.valid = true
end

return Carcass
