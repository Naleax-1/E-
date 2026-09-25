---@diagnostic disable: undefined-global

--============================================================
-- DETOX
-- E-1 Core State Implementation
--============================================================

local APP_NAME = 'DETOX'
local VERSION = 'E-1 Core State'

-- DETOX
-- E-7 Main Runtime

local State = require("Core.state")
local Input = require("Core.input")
local Scheduler = require("Core.scheduler")

local Wheel = require("Engine.wheel")
local Tire = require("Engine.tire")
local Suspension = require("Engine.suspension")

local Powertrain = require("Engine.powertrain")
local Differential = require("Engine.differential")

local Thermal = require("Engine.thermal")
local Carcass = require("Engine.carcass")

local TireModel = require("Model.tire_model")
local LoadModel = require("Model.load_model")
local ThermalModel = require("Model.thermal_model")
local CarcassModel = require("Model.carcass_model")

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

  powertrainDefinition = nil,
  differentialDefinition = nil,

  wheel = nil,
  tire = nil,
  suspension = nil,

  powertrain = nil,
  differential = nil,

  thermal = nil,
  carcass = nil,

  error = nil
}


local function safeRequire(moduleName)
  local ok, result =
      pcall(require, moduleName)

  if not ok then
    return nil, tostring(result)
  end

  return result, nil
end


local function initialize()
  app.state = State.create()

  app.input = Input.create()
  app.scheduler = Scheduler.create()

  app.tireModel =
      TireModel.create()

  app.loadModel =
      LoadModel.create()

  app.thermalModel =
      ThermalModel.create()

  app.carcassModel =
      CarcassModel.create()

  app.powertrainDefinition =
      PowertrainDefinition.create()

  app.differentialDefinition =
      DifferentialDefinition.create()

  app.wheel =
      Wheel.create()

  app.tire =
      Tire.create(app.tireModel)

  app.suspension =
      Suspension.create(app.loadModel)

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
  if app.wheel
      and app.wheel.updateKinematics then

    app.wheel.updateKinematics(
      app.state
    )
  end
end


local function phaseSlip()
  if app.wheel
      and app.wheel.updateSlip then

    app.wheel.updateSlip(
      app.state
    )
  end
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
  local shaftTorque =
      app.state.next.powertrain.shaft.torque

  local ratio =
      app.state.next.powertrain.gearbox.ratio

  local finalDrive =
      app.powertrainDefinition
          .gearbox.finalDrive

  app.state.next.powertrain.differential.inputTorque =
      shaftTorque
      * ratio
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
  if app.wheel
      and app.wheel.update then

    app.wheel.update(
      app.state
    )
  end
end


local function phaseCoupledIteration()
  -- E-7:
  -- Full wheel/tire/body coupled solving
  -- is intentionally reserved for E-9.
  --
  -- Current path:
  -- State -> Tire -> Thermal/Carcass
  -- -> next Tick feedback.
end


local function phaseBody()
  -- Body Dynamics is introduced
  -- in the later integration phase.
end


local function phaseValidation()
  local diagnostics =
      app.state.next.diagnostics

  diagnostics.valid = true
  diagnostics.errors = 0
  diagnostics.lastError = ""

  for _, name in ipairs(
      State.getWheelNames()) do

    local wheel =
        app.state.next.wheels[name]

    local tire =
        app.state.next.tires[name]

    if not wheel
        or not tire then

      diagnostics.valid = false
      diagnostics.errors =
          diagnostics.errors + 1

      diagnostics.lastError =
          "Missing wheel/tire state: "
          .. name
    end
  end
end


local function phaseCommit()
  app.state:commit()
end


local function phaseOutput()
  -- Output boundary remains read-only.
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
    app.error = tostring(err)

    if app.state
        and app.state.current
        and app.state.current.diagnostics then

      app.state.current.diagnostics.valid = false

      app.state.current.diagnostics.errors =
          (app.state.current.diagnostics.errors or 0)
          + 1

      app.state.current.diagnostics.lastError =
          app.error
    end
  end
end


function script.windowMain()
  if not app.initialized then
    ui.text("DETOX E-7: INITIALIZING")
    return
  end

  local state =
      app.state.current

  local vehicle =
      state.vehicle

  local powertrain =
      state.powertrain

  ui.text("DETOX E-7")
  ui.separator()

  ui.text(
    string.format(
      "Frame: %d",
      app.state.frame
    )
  )

  ui.text(
    string.format(
      "Speed: %.1f km/h",
      vehicle.speed * 3.6
    )
  )

  ui.text(
    string.format(
      "RPM: %.0f",
      powertrain.engine.rpm
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
        "%s  Load %.0f N  Fx %.0f  Fy %.0f",
        name,
        wheel.load,
        tire.force.longitudinal,
        tire.force.lateral
      )
    )

    ui.text(
      string.format(
        "    Slip %.4f  Temp %.1f / %.1f C",
        tire.slipRatio,
        tire.surfaceTemperature,
        tire.carcassTemperature
      )
    )

    ui.text(
      string.format(
        "    Grip %.3f  Carcass %.4f m",
        tire.thermalGrip,
        tire.carcassDeflection
      )
    )
  end

  ui.separator()

  ui.text(
    string.format(
      "E-7 Thermal / Carcass ACTIVE"
    )
  )

  ui.text(
    string.format(
      "State Valid: %s",
      tostring(state.diagnostics.valid)
    )
  )

  if app.error then
    ui.text(
      "ERROR: " .. app.error
    )
  end
end
