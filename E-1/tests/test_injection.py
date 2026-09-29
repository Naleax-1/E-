"""Boundary regression suite; mock CSP API acceptance is NOT on-car proof."""
from test_runtime import execute


if __name__ == "__main__":
    execute(r'''
package.path="./E-1/?.lua;"..package.path
local State=require("Core.state")
local Output=require("Send.physics_output")
local Safety=require("Safety.injection_safety")
local Controller=require("Send.injection_controller")
local Dynamic=require("Verification.dynamic")
local state=State.create()
state.frame=1;state.current.vehicle.valid=true;state.current.vehicle.time=.01
state.current.vehicle.input={speedKmh=12,rpm=2000,gas=.4,brake=0,steer=0}
state.current.body.force.x=40
local output=Output.create()
assert(Output.update(output,state))
assert(output.sequence==1 and output.transferCount==1 and output.fresh and not output.stale)
assert(Output.getObserverData(output).force.x==40)
assert(Output.update(output,state)==false and output.stale)
state.frame=2;state.current.vehicle.time=.02
assert(Output.update(output,state) and output.transferCount==2)
local calls={}
vec3=function(x,y,z)return {x=x,y=y,z=z} end
ac={addForce=function(p,pl,f,fl)
  assert(pl==true and fl==true and p.z==0 and f.x==0 and f.y==0)
  calls[#calls+1]=f.z
end}
local c=Controller.create()
assert(c.mode=="DISABLED" and c.applied==0)
Controller.update(c,output,state)
assert(#calls==0)
assert(Controller.armTest(c)==false,"app context must not be armable")
c.enabledInPhysics=true
assert(Controller.setStage(c,2)==false,"unsupported wheel/torque stages must be locked")
assert(Controller.armTest(c))
Controller.update(c,output,state)
assert(c.mode=="TEST" and c.applied==4 and calls[1]==4)
Controller.update(c,output,state)
assert(c.mode=="FAULT" and c.applied==0 and c.reason=="STALE")
assert(Controller.armTest(c)==false,"fault must latch")
assert(Controller.resetFault(c))
assert(c.mode=="DISABLED" and c.safety=="SAFE")
local function nextOutput(fx)
  state.frame=state.frame+1
  state.current.vehicle.time=state.current.vehicle.time+.01
  state.current.body.force.x=fx
  assert(Output.update(output,state))
end
nextOutput(200)
assert(Controller.armTest(c));Controller.update(c,output,state)
assert(c.clamped and c.requested==200 and c.applied==15 and c.limit==150)
assert(Controller.enable(c))
nextOutput(-25);Controller.update(c,output,state)
assert(c.mode=="ENABLED" and c.applied==-25 and calls[#calls]==-25)
nextOutput(601);Controller.update(c,output,state)
assert(c.mode=="FAULT" and c.applied==0 and c.reason=="MAGNITUDE_OVERFLOW")
assert(Controller.resetFault(c))
nextOutput(40);output.force.x=0/0
assert(Controller.armTest(c));Controller.update(c,output,state)
assert(c.mode=="FAULT" and c.applied==0 and c.reason=="NON_FINITE")
assert(Controller.resetFault(c))
nextOutput(40);output.force.x=math.huge
assert(Controller.armTest(c));Controller.update(c,output,state)
assert(c.mode=="FAULT" and c.applied==0)
assert(Controller.resetFault(c))
nextOutput(40);state.current.diagnostics.errors=1
assert(Controller.armTest(c));Controller.update(c,output,state)
assert(c.mode=="FAULT" and c.reason=="VALIDATION_ERROR")
state.current.diagnostics.errors=0;assert(Controller.resetFault(c))
nextOutput(40);state.current.vehicle.input.speedKmh=0/0
assert(Controller.armTest(c));Controller.update(c,output,state)
assert(c.mode=="FAULT" and c.applied==0 and c.reason=="NON_FINITE_INPUT")
state.current.vehicle.input.speedKmh=12;assert(Controller.resetFault(c))
nextOutput(40);assert(Controller.armTest(c))
Controller.emergencyDisable(c);Controller.update(c,output,state)
assert(c.mode=="DISABLED" and c.applied==0 and c.reason=="EMERGENCY_DISABLE")
assert(Controller.armTest(c)==false and Controller.resetFault(c)==false)
assert(Controller.clearEmergency(c))
assert(Controller.armTest(c));Controller.update(c,output,state)
assert(c.applied==4,"safe reset must allow explicit TEST")
nextOutput(40)
ac.addForce=function()error("mock CSP failure")end
Controller.update(c,output,state)
assert(c.mode=="FAULT" and c.applied==0 and c.reason:find("AC_APPLY_FAILED",1,true))
local count=#calls
nextOutput(40);Controller.update(c,output,state)
assert(#calls==count,"fault must prevent subsequent calls")
local d=Dynamic.create()
local conditions={vehicle="GT500",track="Okayama",weather="Clear",surface="Dry",setup="S1",
  fuel="25",tyre="Soft",temperature="22",inputMethod="Wheel"}
assert(Dynamic.setConditions(d,conditions))
assert(not Dynamic.addStandard(d,{speed=0,rpm=900,time=0,tests={Launch=true}},
  {vehicle="wrong"}))
assert(Dynamic.addStandard(d,{speed=0,rpm=900,time=0,tests={Launch=true}},conditions))
assert(Controller.resetFault(c))
nextOutput(40)
assert(Dynamic.record(d,state,output,c))
assert(d.count.B==1 and d.count.C==0 and d.runs.B[1].acceleration==0)
ac.addForce=function() end
assert(Controller.armTest(c));Controller.update(c,output,state)
assert(Dynamic.record(d,state,output,c))
assert(d.count.B==1 and d.count.C==1 and d.runs.C[1].applied==4)
assert(Dynamic.getObserverData(d).productionGate=="PENDING_REAL_AC_EVIDENCE")
''')
    print("DETOX safety/injection mock tests passed (not AC hardware validation)")
