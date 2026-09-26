---@diagnostic disable: undefined-global

--============================================================
-- DETOX
-- E-1 Core State Implementation
--============================================================

local APP_NAME = 'DETOX'
local VERSION = 'E-1 Core State'

-- DETOX
-- E-9 Main Runtime

local State =
    require("Core.state")

local Input =
    require("Core.input")

local Scheduler =
    require("Core.scheduler")

local CoupledSolver =
    require("Core.coupled_solver")


local Wheel =
    require("Engine.wheel")

local Tire =
    require("Engine.tire")

local Suspension =
    require("Engine.suspension")

local Powertrain =
    require("Engine.powertrain")

local Differential =
    require("Engine.differential")

local Thermal =
    require("Engine.thermal")

local Carcass =
    require("Engine.carcass")

local Body =
    require("Engine.body")


local TireModel =
    require("Model.tire_model")

local LoadModel =
    require("Model.load_model")

local ThermalModel =
    require("Model.thermal_model")

local CarcassModel =
    require("Model.carcass_model")

local BodyModel =
    require("Model.body_model")

local CoupledModel =
    require("Model.coupled_model")


local PowertrainDefinition =
    require("Definition.powertrain")

local DifferentialDefinition =
    require("Definition.differential")


local app = {
  initialized = false,

  state = nil,
  input = nil,
  scheduler = nil,
  coupledSolver = nil,

  tireModel = nil,
  loadModel = nil,
  thermalModel = nil,
  carcassModel = nil,
  bodyModel = nil,
  coupledModel = nil,

  powertrainDefinition = nil,
  differentialDefinition = nil,

  wheel = nil,
  tire = nil,
  suspension = nil,

  powertrain = nil,
  differential = nil,

  thermal = nil,
  carcass = nil,

  body = nil,

  error = nil
}


local function initialize()
  app.state =
      State.create()

  app.input =
      Input.create()

  app.scheduler =
      Scheduler.create()


  app.tireModel =
      TireModel.create()

  app.loadModel =
      LoadModel.create()

  app.thermalModel =
      ThermalModel.create()

  app.carcassModel =
      CarcassModel.create()

  app.bodyModel =
      BodyModel.create()

  app.coupledModel =
      CoupledModel.create()


  app.powertrainDefinition =
      PowertrainDefinition.create()

  app.differentialDefinition =
      DifferentialDefinition.create()


  app.wheel =
      Wheel.create()

  app.tire =
      Tire.create(
        app.tireModel
      )

  app.suspension =
      Suspension.create(
        app.loadModel
      )

  app.powertrain =
      Powertrain.create(
        app.powertrainDefinition
      )

  app.differential =
      Differential.create(
        app.differentialDefinition
      )

  app.thermal =
      Thermal.create(
        app.thermalModel
      )

  app.carcass =
      Carcass.create(
        app.carcassModel
      )

  app.body =
      Body.create(
        app.bodyModel
      )


  app.coupledSolver =
      CoupledSolver.create(
        app.coupledModel
      )


  app.initialized = true
end


local function phaseInput()
  Input.update(
    app.input,
    app.state
  )
end


local function phaseSnapshot()
  app.state:beginTick()
end


local function phaseKinematics()
  Wheel.updateKinematics(
    app.state
  )
end


local function phaseSlip()
  Wheel.updateSlip(
    app.state
  )
end


local function phasePowertrain()
  Powertrain.update(
    app.state,
    app.powertrainDefinition
  )
end


local function phaseDifferential()
  local shaft =
      app.state.next.powertrain.shaft

  local gearbox =
      app.state.next.powertrain.gearbox

  local finalDrive =
      app.powertrainDefinition
        .gearbox.finalDrive

  app.state.next.powertrain
      .differential.inputTorque =
      shaft.torque
      * gearbox.ratio
      * finalDrive

  Differential.update(
    app.state,
    app.differentialDefinition
  )
end


local function phaseSuspension()
  Suspension.update(
    app.state,
    app.loadModel
  )
end


local function phaseInitialTire()
  Carcass.update(
    app.state,
    app.carcassModel
  )

  Thermal.update(
    app.state,
    app.thermalModel
  )

  Tire.update(
    app.state,
    app.tireModel
  )
end


local function phaseCoupledIteration()
  local modules = {
    wheel = Wheel,
    tire = Tire,

    tireModel = app.tireModel,

    thermal = Thermal,
    thermalModel = app.thermalModel,

    carcass = Carcass,
    carcassModel = app.carcassModel,

    differential = Differential,
    differentialDefinition =
        app.differentialDefinition
  }

  app.coupledSolver:update(
    app.state,
    modules
  )

  app.state.next.coupled.iterations =
      app.coupledSolver.iterations

  app.state.next.coupled.converged =
      app.coupledSolver.converged

  app.state.next.coupled.residual.force =
      app.coupledSolver.residual.force

  app.state.next.coupled.residual.torque =
      app.coupledSolver.residual.torque

  app.state.next.coupled.residual.velocity =
      app.coupledSolver.residual.velocity
end


local function phaseBody()
  Body.update(
    app.state,
    app.bodyModel
  )
end


local function phaseWheelFinal()
  Wheel.update(
    app.state
  )
end


local function phaseValidation()
  local diagnostics =
      app.state.next.diagnostics

  diagnostics.valid = true
  diagnostics.errors = 0
  diagnostics.lastError = ""


  if not app.state.next.body.valid then
    diagnostics.valid = false

    diagnostics.errors =
        diagnostics.errors + 1

    diagnostics.lastError =
        "Body state invalid"
  end


  for _, name in ipairs(
      State.getWheelNames()) do

    local wheel =
        app.state.next.wheels[name]

    local tire =
        app.state.next.tires[name]

    if not wheel then
      diagnostics.valid = false

      diagnostics.errors =
          diagnostics.errors + 1

      diagnostics.lastError =
          "Missing wheel: "
          .. name
    end

    if not tire then
      diagnostics.valid = false

      diagnostics.errors =
          diagnostics.errors + 1

      diagnostics.lastError =
          "Missing tire: "
          .. name
    end
  end


  if app.state.next.coupled.iterations
      <= 0 then

    diagnostics.valid = false

    diagnostics.errors =
        diagnostics.errors + 1

    diagnostics.lastError =
        "Coupled solver did not execute"
  end
end


local function phaseCommit()
  app.state:commit()
end


local function phaseOutput()
  -- Output remains read-only.
end


function script.update(dt)
  if not app.initialized then
    initialize()
  end

  if not app.initialized then
    return
  end


  local ok, err =
      pcall(function()

        if dt and dt > 0 then
          app.state.current.vehicle.dt =
              dt
        end


        phaseInput()

        phaseSnapshot()

        if dt and dt > 0 then
          app.state.next.vehicle.dt =
              dt
        end


        phaseKinematics()
        phaseSlip()

        phasePowertrain()
        phaseDifferential()

        phaseSuspension()

        phaseInitialTire()

        phaseCoupledIteration()

        phaseBody()

        phaseWheelFinal()

        phaseValidation()

        phaseCommit()

        phaseOutput()
      end)


  if not ok then
    app.error =
        tostring(err)

    if app.state
        and app.state.current
        and app.state.current.diagnostics then

      app.state.current.diagnostics.valid =
          false

      app.state.current.diagnostics.errors =
          (
            app.state.current.diagnostics.errors
            or 0
          ) + 1

      app.state.current.diagnostics.lastError =
          app.error
    end
  end
end


function script.windowMain()
  if not app.initialized then
    ui.text(
      "DETOX E-9: INITIALIZING"
    )

    return
  end


  local state =
      app.state.current

  local vehicle =
      state.vehicle

  local body =
      state.body

  local powertrain =
      state.powertrain

  local coupled =
      state.coupled


  ui.text("DETOX E-9")
  ui.separator()


  ui.text(
    string.format(
      "Frame: %d",
      app.state.frame
    )
  )

  ui.text(
    string.format(
      "Speed: %.2f km/h",
      vehicle.speed * 3.6
    )
  )


  ui.separator()


  ui.text(
    string.format(
      "Body Velocity: %.2f / %.2f / %.2f",
      body.velocity.x,
      body.velocity.y,
      body.velocity.z
    )
  )

  ui.text(
    string.format(
      "Body Accel: %.2f / %.2f / %.2f",
      body.acceleration.x,
      body.acceleration.y,
      body.acceleration.z
    )
  )

  ui.text(
    string.format(
      "Angular Velocity: %.3f / %.3f / %.3f",
      body.angularVelocity.x,
      body.angularVelocity.y,
      body.angularVelocity.z
    )
  )


  ui.separator()


  ui.text(
    string.format(
      "RPM: %.0f",
      powertrain.engine.rpm
    )
  )

  ui.text(
    string.format(
      "Shaft Torque: %.1f",
      powertrain.shaft.torque
    )
  )

  ui.text(
    string.format(
      "Diff L/R: %.1f / %.1f",
      powertrain.differential.leftTorque,
      powertrain.differential.rightTorque
    )
  )


  ui.separator()


  ui.text(
    string.format(
      "Coupled Iterations: %d / %d",
      coupled.iterations,
      app.coupledModel.maxIterations
    )
  )

  ui.text(
    string.format(
      "Converged: %s",
      tostring(
        coupled.converged
      )
    )
  )

  ui.text(
    string.format(
      "Residual F/T/V: %.3f / %.3f / %.5f",
      coupled.residual.force,
      coupled.residual.torque,
      coupled.residual.velocity
    )
  )


  ui.separator()


  for _, name in ipairs(
      State.getWheelNames()) do

    local wheel =
        state.wheels[name]

    local tire =
        state.tires[name]

    ui.text(
      string.format(
        "%s Fz %.0f Fx %.0f Fy %.0f",
        name,
        wheel.load,
        tire.force.longitudinal,
        tire.force.lateral
      )
    )

    ui.text(
      string.format(
        "  Omega %.2f Slip %.4f",
        wheel.omega,
        wheel.slipRatio
      )
    )
  }


  ui.separator()

  ui.text(
    "E-9 COUPLED SOLVER ACTIVE"
  )

  ui.text(
    "State Valid: "
    .. tostring(
      state.diagnostics.valid
    )
  )


  if app.error then
    ui.text(
      "ERROR: "
      .. app.error
    )
  end
end
