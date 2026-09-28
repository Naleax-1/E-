---@diagnostic disable: undefined-global
-- DETOX E-10 Physics Integration
local State=require("Core.state")
local Input=require("Core.input")
local Scheduler=require("Core.scheduler")
local Validation=require("Core.validation")
local CoupledSolver=require("Core.coupled_solver")

local Body=require("Engine.body")
local Wheel=require("Engine.wheel")
local Tire=require("Engine.tire")
local Suspension=require("Engine.suspension")
local Powertrain=require("Engine.powertrain")
local Differential=require("Engine.differential")
local Thermal=require("Engine.thermal")
local Carcass=require("Engine.carcass")

local BodyModel=require("Model.body_model")
local TireModel=require("Model.tire_model")
local LoadModel=require("Model.load_model")
local ThermalModel=require("Model.thermal_model")
local CarcassModel=require("Model.carcass_model")
local CoupledModel=require("Model.coupled_model")
local PowertrainDefinition=require("Definition.powertrain")
local DifferentialDefinition=require("Definition.differential")
local VehicleDefinition=require("Definition.vehicle")
local TireDefinition=require("Definition.tire")
local SuspensionDefinition=require("Definition.suspension")

local Observer=require("Observer.observer")
local PhysicsOutput=require("Send.physics_output")

local app={initialized=false,error=nil}

local function initialize()
  app.state=State.create()
  app.input=Input.create()
  app.scheduler=Scheduler.create()
  app.bodyModel=BodyModel.create()
  app.tireModel=TireModel.create()
  app.loadModel=LoadModel.create()
  app.thermalModel=ThermalModel.create()
  app.carcassModel=CarcassModel.create()
  app.coupledModel=CoupledModel.create()
  app.powertrainDefinition=PowertrainDefinition.create()
  app.differentialDefinition=DifferentialDefinition.create()
  app.vehicleDefinition=VehicleDefinition.create()
  app.tireDefinition=TireDefinition.create()
  app.suspensionDefinition=SuspensionDefinition.create()

  app.body=Body.create(app.bodyModel)
  app.wheel=Wheel.create()
  app.tire=Tire.create(app.tireModel)
  app.suspension=Suspension.create(app.loadModel)
  app.powertrain=Powertrain.create(app.powertrainDefinition)
  app.differential=Differential.create(app.differentialDefinition)
  app.thermal=Thermal.create(app.thermalModel)
  app.carcass=Carcass.create(app.carcassModel)
  app.coupledSolver=CoupledSolver.create(app.coupledModel)
  app.physicsOutput=PhysicsOutput.create()
  Observer.init()
  VehicleDefinition.apply(app.state,app.vehicleDefinition)
  State.commit(app.state)
  app.initialized=true
end

function script.update(dt)
  if not app.initialized then
    local initOK, initErr = pcall(initialize)
    if not initOK then
      app.error=tostring(initErr)
      return
    end
  end
  local ok,err=pcall(function()
    -- Begin the tick before reading AC input. beginTick() clones current -> next,
    -- so calling Input.update() before it would silently discard all new inputs.
    State.beginTick(app.state,dt)
    Input.update(app.input,app.state)
    Scheduler.update(app.scheduler,app.state,dt)

    -- Seed body from current state; integration occurs exactly once at the end.
    app.state.next.body.mass=app.state.next.vehicle.mass
    Wheel.updateKinematics(app.state)
    Wheel.updateSlip(app.state)
    Powertrain.update(app.state,app.powertrainDefinition)

    CoupledSolver.update(app.coupledSolver,app.state,{
      wheel=Wheel,tire=Tire,tireInstance=app.tire,suspension=Suspension,
      suspensionDefinition=app.suspensionDefinition,
      powertrain=Powertrain,differential=Differential,
      carcass=Carcass,carcassInstance=app.carcass,
      thermal=Thermal,thermalInstance=app.thermal,body=Body,
      tireModel=TireModel,loadModel=LoadModel,
      carcassModel=CarcassModel,thermalModel=ThermalModel,
      bodyModel=BodyModel,powertrainDefinition=app.powertrainDefinition,
      differentialDefinition=app.differentialDefinition
    })

    app.state.next.coupled.iterations=app.coupledSolver.iterations
    app.state.next.coupled.converged=app.coupledSolver.converged
    app.state.next.coupled.residual=app.coupledSolver.residual

    -- Final integration: Body once, Wheel omega has already been solved in the loop.
    Wheel.commitRotation(app.state,app.state.next.vehicle.dt)
    Body.integrate(app.state)
    app.state.next.vehicle.speed=math.sqrt(
      app.state.next.body.velocity.x^2+
      app.state.next.body.velocity.y^2+
      app.state.next.body.velocity.z^2)

    Validation.validate(app.state)
    State.commit(app.state)
    Observer.update(dt,app.state.current,app.input,{
      core={
        State={api=State,arg=app.state},
        Input={api=Input,arg=app.input},
        Scheduler={api=Scheduler,arg=app.scheduler},
        CoupledSolver={api=CoupledSolver,arg=app.coupledSolver},
        Validation={api=Validation,arg=app.state}
      },
      engine={
        Body={api=Body},Wheel={api=Wheel},Tire={api=Tire},Suspension={api=Suspension},
        Powertrain={api=Powertrain},Differential={api=Differential},Thermal={api=Thermal},Carcass={api=Carcass}
      },
      model={
        BodyModel={api=BodyModel,arg=app.bodyModel},TireModel={api=TireModel,arg=app.tireModel},
        LoadModel={api=LoadModel,arg=app.loadModel},ThermalModel={api=ThermalModel,arg=app.thermalModel},
        CarcassModel={api=CarcassModel,arg=app.carcassModel},CoupledModel={api=CoupledModel,arg=app.coupledModel}
      },
      definition={
        Vehicle={api=VehicleDefinition,arg=app.vehicleDefinition},Powertrain={api=PowertrainDefinition,arg=app.powertrainDefinition},
        Differential={api=DifferentialDefinition,arg=app.differentialDefinition},Suspension={api=SuspensionDefinition,arg=app.suspensionDefinition},
        Tire={api=TireDefinition,arg=app.tireDefinition}
      },
      send={PhysicsOutput={api=PhysicsOutput}}
    })
  end)
  if not ok then
    app.error=tostring(err)
    app.state.current.diagnostics.valid=false
    app.state.current.diagnostics.errors=(app.state.current.diagnostics.errors or 0)+1
    app.state.current.diagnostics.lastError=app.error
  else
    app.error=nil
  end
end

function script.windowMain()
  if not app.initialized then
    ui.text(app.error and ("DETOX INITIALIZATION ERROR: "..app.error) or "DETOX OBSERVER: INITIALIZING")
    return
  end
  local ok,err=pcall(function()
    Observer.windowMain(app.state.current, app.input)
  end)
  if not ok then ui.text("DETOX OBSERVER ERROR"); ui.text(tostring(err)) end
end
