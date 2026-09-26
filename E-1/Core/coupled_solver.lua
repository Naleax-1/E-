-- DETOX
-- E-9 Coupled Solver

local CoupledSolver = {}

CoupledSolver.VERSION = "E-9"

local WHEEL_NAMES = {
  "FL",
  "FR",
  "RL",
  "RR"
}

local function copyVector(value)
  return {
    x = value.x or 0.0,
    y = value.y or 0.0,
    z = value.z or 0.0
  }
end

local function calculateResidual(state)
  local force = 0.0
  local torque = 0.0
  local velocity = 0.0

  for _, name in ipairs(WHEEL_NAMES) do
    local wheel =
        state.next.wheels[name]

    local tire =
        state.next.tires[name]

    if wheel and tire then
      force =
          force
          +
          math.abs(
            tire.force.longitudinal
            or 0.0
          )

      force =
          force
          +
          math.abs(
            tire.force.lateral
            or 0.0
          )

      torque =
          torque
          +
          math.abs(
            wheel.torque.tire
            or 0.0
          )

      velocity =
          velocity
          +
          math.abs(
            wheel.contactVelocity.x
            or 0.0
          )
    end
  end

  return {
    force = force,
    torque = torque,
    velocity = velocity
  }
end

function CoupledSolver.create(model)
  return {
    model = model,

    iterations = 0,
    converged = false,

    residual = {
      force = 0.0,
      torque = 0.0,
      velocity = 0.0
    }
  }
end

function CoupledSolver.update(
    solver,
    state,
    modules
)
  local model = solver.model

  solver.iterations = 0
  solver.converged = false

  local previous = {
    fx = 0.0,
    fy = 0.0,
    torque = 0.0,
    velocity = 0.0
  }

  for iteration = 1, model.maxIterations do
    solver.iterations =
        iteration

    /*
      Iteration order:

      1. Wheel kinematics
      2. Slip
      3. Tire
      4. Thermal
      5. Carcass
      6. Differential
      7. Wheel reaction
    */

    modules.wheel.updateKinematics(
      state
    )

    modules.wheel.updateSlip(
      state
    )

    modules.tire.update(
      state,
      modules.tireModel
    )

    modules.thermal.update(
      state,
      modules.thermalModel
    )

    modules.carcass.update(
      state,
      modules.carcassModel
    )

    modules.differential.update(
      state,
      modules.differentialDefinition
    )

    modules.wheel.update(
      state
    )

    local current = {
      fx = 0.0,
      fy = 0.0,
      torque = 0.0,
      velocity = 0.0
    }

    for _, name in ipairs(
        WHEEL_NAMES) do

      local wheel =
          state.next.wheels[name]

      local tire =
          state.next.tires[name]

      if wheel and tire then
        current.fx =
            current.fx
            +
            (
              tire.force.longitudinal
              or 0.0
            )

        current.fy =
            current.fy
            +
            (
              tire.force.lateral
              or 0.0
            )

        current.torque =
            current.torque
            +
            (
              wheel.torque.tire
              or 0.0
            )

        current.velocity =
            current.velocity
            +
            (
              wheel.contactVelocity.x
              or 0.0
            )
      end
    end

    local residual = {
      force =
          math.abs(
            current.fx - previous.fx
          )
          +
          math.abs(
            current.fy - previous.fy
          ),

      torque =
          math.abs(
            current.torque
            - previous.torque
          ),

      velocity =
          math.abs(
            current.velocity
            - previous.velocity
          )
    }

    solver.residual =
        residual

    if
        residual.force
            <= model.forceTolerance
        and
        residual.torque
            <= model.torqueTolerance
        and
        residual.velocity
            <= model.velocityTolerance
    then
      solver.converged = true
      break
    end

    previous = current
  end

  return solver.converged
end

return CoupledSolver
