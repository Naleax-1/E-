---@diagnostic disable: undefined-global

--============================================================
-- DETOX
-- E-1 Core State Implementation
--============================================================

local APP_NAME = 'DETOX'
local VERSION = 'E-1 Core State'
-- DETOX
-- E-8 Main Runtime

local State =
    require("Core.state")

local Input =
    require("Core.input")

local Scheduler =
    require("Core.scheduler")


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


local PowertrainDefinition =
    require("Definition.powertrain")

local DifferentialDefinition =
    require("Definition.differential")


local app = {
  initialized = false,

  state = nil,
  input = nil,
  scheduler = nil,

  tireModel = nil,
  loadModel = nil,
  thermalModel = nil,
  carcassModel = nil,
  bodyModel = nil,

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


local function phaseThermalCarcass()
  Carcass.update(
    app.state,
    app.carcassModel
  )

  Thermal.update(
    app.state,
    app.thermalModel
  )
end


local function phaseTire()
  Tire.update(
    app.state,
    app.tireModel
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


local function phaseWheel()
  Wheel.update(
    app.state
  )
end


local function phaseCoupledIteration()
  -- Full coupled solver is E-9.
  --
  -- E-8 intentionally performs
  -- one directional body integration.
end


local function phaseBody()
  Body.update(
    app.state,
    app.bodyModel
  )
end


local function phaseValidation()
  local diagnostics =
      app.state.next.diagnostics

  diagnostics.valid = true
  diagnostics.errors = 0
  diagnostics.lastError = ""


  local body =
      app.state.next.body

  if not body.valid then
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
          "Missing wheel state: "
          .. name
    end

    if not tire then
      diagnostics.valid = false

      diagnostics.errors =
          diagnostics.errors + 1

      diagnostics.lastError =
          "Missing tire state: "
          .. name
    end
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


  if dt and dt > 0 then
    app.state.next.vehicle.dt =
        dt
  end


  local ok, err =
      pcall(function()

        phaseInput()
        phaseSnapshot()

        phaseKinematics()
        phaseSlip()

        phaseThermalCarcass()
        phaseTire()

        phasePowertrain()
        phaseDifferential()

        phaseSuspension()
        phaseWheel()

        phaseCoupledIteration()
        phaseBody()

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
      "DETOX E-8: INITIALIZING"
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


  ui.text("DETOX E-8")
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

  ui.text(
    string.format(
      "Body V: %.2f / %.2f / %.2f",
      body.velocity.x,
      body.velocity.y,
      body.velocity.z
    )
  )

  ui.text(
    string.format(
      "Body A: %.2f / %.2f / %.2f",
      body.acceleration.x,
      body.acceleration.y,
      body.acceleration.z
    )
  )

  ui.text(
    string.format(
      "Angular V: %.3f / %.3f / %.3f",
      body.angularVelocity.x,
      body.angularVelocity.y,
      body.angularVelocity.z
    )
  )

  ui.text(
    string.format(
      "Attitude: R %.3f  P %.3f  Y %.3f",
      body.attitude.roll,
      body.attitude.pitch,
      body.attitude.yaw
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


  ui.separator()


  for _, name in ipairs(
      State.getWheelNames()) do

    local wheel =
        state.wheels[name]

    local tire =
        state.tires[name]

    ui.text(
      string.format(
        "%s  Fz %.0f  Fx %.0f  Fy %.0f",
        name,
        wheel.load,
        tire.force.longitudinal,
        tire.force.lateral
      )
    )

    ui.text(
      string.format(
        "    Omega %.2f  Slip %.4f",
        wheel.omega,
        wheel.slipRatio
      )
    )

    ui.text(
      string.format(
        "    Temp %.1f / %.1f  Grip %.3f",
        tire.surfaceTemperature,
        tire.carcassTemperature,
        tire.thermalGrip
      )
    )
  }


  ui.separator()

  ui.text(
    "E-8 BODY / WHEEL DYNAMICS ACTIVE"
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
