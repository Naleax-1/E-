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
local InjectionSafety=require("Safety.injection_safety")
local InjectionController=require("Send.injection_controller")
local Dynamic=require("Verification.dynamic")
local Trace=require("Verification.trace")
local Bridge=require("Send.command_bridge")

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
  app.injection=InjectionController.create()
  -- The app manifest is always read-only. Only the optional car physics
  -- bootstrap explicitly opts into the CSP physics-thread API.
  app.injection.enabledInPhysics=DETOX_PHYSICS_CONTEXT==true
  app.context=app.injection.enabledInPhysics and "CAR_PHYSICS" or "APP_READ_ONLY"
  app.instance=tostring(app)
  app.bridge=Bridge.create(app.context)
  app.trace=Trace.create(app.context,app.instance)
  app.verification=Dynamic.create()
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
    PhysicsOutput.update(app.physicsOutput,app.state)
    if app.injection.enabledInPhysics then Bridge.poll(app.bridge,app.injection) end
    InjectionController.update(app.injection,app.physicsOutput,app.state)
    app.physicsOutput.injection=app.injection.mode
    app.physicsOutput.applied=app.injection.applied
    app.physicsOutput.boundary=app.injection.enabledInPhysics and "SAFETY_GATE" or "READ_ONLY"
    Dynamic.record(app.verification,app.state,app.physicsOutput,app.injection)
    Trace.capture(app.trace,app.state,app.physicsOutput,app.injection,app.bridge)
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
      send={PhysicsOutput={api=PhysicsOutput,arg=app.physicsOutput},
        Injection={api=InjectionController,arg=app.injection},
        Bridge={api=Bridge,arg=app.bridge}},
      safety={InjectionSafety={api=InjectionSafety,arg=app.injection.gate}},
      verification={Dynamic={api=Dynamic,arg=app.verification},
        Trace={api=Trace,arg=app.trace}}
    })
  end)
  if not ok then
    app.error=tostring(err)
    PhysicsOutput.invalidate(app.physicsOutput,app.error)
    InjectionController.faultOff(app.injection,"MODULE_ERROR: "..app.error)
    app.state.current.diagnostics.valid=false
    app.state.current.diagnostics.errors=(app.state.current.diagnostics.errors or 0)+1
    app.state.current.diagnostics.lastError=app.error
    app.physicsOutput.injection=app.injection.mode
    app.physicsOutput.applied=0
    Trace.capture(app.trace,app.state,app.physicsOutput,app.injection,app.bridge)
    Observer.update(dt,app.state.current,app.input)
  else
    app.error=nil
  end
end

-- Commands are explicit; no automatic fault reset or injection on startup.
function script.detoxArmTest()
  if not app.initialized then return false,"NOT_INITIALIZED" end
  if not app.injection.enabledInPhysics then Bridge.send(app.bridge,"ARM_FX_TEST") end
  return InjectionController.armTest(app.injection,"LOCAL_ARM_BUTTON")
end
function script.detoxEnableFX() return app.initialized and InjectionController.enable(app.injection) end
function script.detoxDisable() return app.initialized and InjectionController.disable(app.injection) end
function script.detoxEmergencyDisable(origin)
  return app.initialized and InjectionController.emergencyDisable(app.injection,origin)
end
function script.detoxRequestMicroPulse()
  return app.initialized and InjectionController.requestMicroPulse(app.injection)
end
function script.detoxSendPing()
  return app.initialized and Bridge.send(app.bridge,"PING")
end
function script.detoxAttachDiagnosticTransport(transport)
  if not app.initialized or not transport or transport.verified~=true then return false,"UNVERIFIED_TRANSPORT" end
  app.bridge.transport=transport;app.bridge.status="TRANSPORT_ATTACHED_UNPROVEN_ON_CSP"
  return true
end
function script.detoxTraceLabel(label)
  return app.initialized and Trace.setLabel(app.trace,label)
end
function script.detoxDiagnostics()
  if not app.initialized then return nil end
  return {controller=InjectionController.getObserverData(app.injection),
    bridge=Bridge.getObserverData(app.bridge),trace=Trace.getObserverData(app.trace),
    samples=Trace.getRows(app.trace)}
end
function script.detoxResetFault() return app.initialized and InjectionController.resetFault(app.injection) end
function script.detoxClearEmergency() return app.initialized and InjectionController.clearEmergency(app.injection) end
function script.detoxSetConditions(conditions)
  return app.initialized and Dynamic.setConditions(app.verification,conditions)
end
function script.detoxAddStandard(sample,conditions)
  return app.initialized and Dynamic.addStandard(app.verification,sample,conditions)
end
function script.detoxVerification()
  return app.initialized and Dynamic.getObserverData(app.verification)
end

function script.windowMain()
  if not app.initialized then
    ui.text(app.error and ("DETOX INITIALIZATION ERROR: "..app.error) or "DETOX OBSERVER: INITIALIZING")
    return
  end
  local ok,err=pcall(function()
    if ui.button then
      local emergency=ui.button("EMERGENCY DISABLE")
      local disable=ui.button("Disable Injection")
      local reset=ui.button("Reset Fault to SAFE")
      local clear=ui.button("Clear Emergency Latch")
      local arm=ui.button("Arm FX TEST (dry run)")
      local enable=ui.button("Enable FX (LOCKED)")
      if emergency then script.detoxEmergencyDisable("APP_UI_EMERGENCY_BUTTON")
      elseif disable then script.detoxDisable()
      elseif reset then script.detoxResetFault()
      elseif clear then script.detoxClearEmergency()
      elseif arm then script.detoxArmTest()
      elseif enable then script.detoxEnableFX() end
      -- Render the button response in this same UI frame, not one tick late.
      Observer.update(0,app.state.current,app.input)
    end
    Observer.windowMain(app.state.current, app.input)
  end)
  if not ok then ui.text("DETOX OBSERVER ERROR"); ui.text(tostring(err)) end
end
