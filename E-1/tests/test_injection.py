"""Boundary regression suite: mock API acceptance is not on-car proof."""
from test_runtime import execute


if __name__ == "__main__":
    execute(r'''
package.path="./E-1/?.lua;"..package.path
local State=require("Core.state")
local Output=require("Send.physics_output")
local Controller=require("Send.injection_controller")
local Bridge=require("Send.command_bridge")
local Dynamic=require("Verification.dynamic")
local state=State.create()
state.frame=1;state.current.vehicle.valid=true;state.current.vehicle.time=.01
state.current.vehicle.input={speedKmh=12,rpm=2000,gas=.4,brake=0,steer=0}
state.current.body.force.x=40
local output=Output.create();assert(Output.update(output,state))
local calls={}
vec3=function(x,y,z)return {x=x,y=y,z=z} end
ac={addForce=function(p,pl,f,fl)
  assert(pl and fl and p.z==0 and f.x==0 and f.y==0)
  calls[#calls+1]=f.z
end}
local app=Controller.create()
local car=Controller.create();car.enabledInPhysics=true
local appBridge=Bridge.create("APP_READ_ONLY")
local physicsBridge=Bridge.create("CAR_PHYSICS")
assert(Controller.armTest(app)==false)
assert(app.mode=="DISABLED" and app.lastEvent.event=="ARM_REJECTED")
assert(Bridge.send(appBridge,"ARM_FX_TEST")==false)
assert(Bridge.poll(physicsBridge,car)==false)
assert(car.mode=="DISABLED" and car.calls==0 and #calls==0)
assert(Controller.setStage(car,2)==false)
assert(Controller.armTest(car))
Controller.update(car,output,state)
assert(car.mode=="TEST" and car.applied==0 and car.calls==0)
assert(car.adapter.skipped==1 and #calls==0)
assert(Controller.enable(car)==false and car.mode=="TEST")
assert(Controller.requestMicroPulse(car))
state.frame=2;state.current.vehicle.time=.02
assert(Output.update(output,state))
Controller.update(car,output,state)
assert(car.calls==1 and car.applied==.01 and calls[1]==.01)
assert(car.preAddForce.requestedFX==40 and car.preAddForce.safeFX==40)
assert(car.preAddForce.localZ==.01 and not car.microPulseArmed)
state.frame=3;state.current.vehicle.time=.03;assert(Output.update(output,state))
Controller.update(car,output,state)
assert(car.calls==1 and car.applied==0 and car.mode=="TEST")
Controller.emergencyDisable(car,"PHYSICS_SCRIPT_RESET")
Controller.update(car,output,state)
assert(car.mode=="DISABLED" and car.emergency and car.applied==0)
assert(car.lastEvent.event=="EMERGENCY" and car.lastEvent.reason=="PHYSICS_SCRIPT_RESET")
assert(Controller.armTest(car)==false and Controller.resetFault(car)==false)
assert(Controller.clearEmergency(car) and car.safety=="SAFE")
assert(Controller.armTest(car))
local function nextOutput(fx)
  state.frame=state.frame+1;state.current.vehicle.time=state.current.vehicle.time+.01
  state.current.body.force.x=fx;assert(Output.update(output,state))
end
nextOutput(40);output.force.x=0/0
Controller.update(car,output,state)
assert(car.mode=="FAULT" and car.applied==0 and #calls==1)
assert(Controller.resetFault(car));assert(Controller.armTest(car))
nextOutput(40);state.current.diagnostics.errors=1
Controller.update(car,output,state)
assert(car.mode=="FAULT" and car.reason=="VALIDATION_ERROR")
state.current.diagnostics.errors=0;assert(Controller.resetFault(car))
-- New controller creation, not enable(), is the path to DEFAULT_OFF.
local recreated=Controller.create()
assert(recreated.reason=="DEFAULT_OFF" and recreated.eventId==1)
assert(Controller.enable(recreated)==false and recreated.mode=="DISABLED")
-- A/B/C buffers never imply real physical success.
local d=Dynamic.create()
local conditions={vehicle="GT500",track="Okayama",weather="Clear",surface="Dry",setup="S1",
  fuel="25",tyre="Soft",temperature="22",inputMethod="Wheel"}
assert(Dynamic.setConditions(d,conditions))
assert(Dynamic.addStandard(d,{speed=0,rpm=900,time=0,tests={Launch=true}},conditions))
assert(Dynamic.getObserverData(d).productionGate=="PENDING_REAL_AC_EVIDENCE")
''')
    print("DETOX FX diagnostic and fault tests passed (mock only)")
