"""Prove UI routing/reset and demonstrate the transport is absent by default."""
from test_runtime import execute


if __name__ == "__main__":
    execute(r'''
package.path="./E-1/?.lua;"..package.path
script={};local pressed=nil;local uiLines={}
ui={text=function(s) uiLines[#uiLines+1]=s end,separator=function()end,
  button=function(label)return label==pressed end}
ac={getCar=function()return {speedKmh=0,rpm=900,gear=1,gas=0,brake=0,steer=0,clutch=1,handbrake=0} end}
dofile("E-1/DETOX.lua")
script.update(.01)
local before=script.detoxDiagnostics()
assert(before.controller.reason=="DEFAULT_OFF" and before.controller.calls==0)
pressed="Arm FX TEST (dry run)";script.windowMain();pressed=nil
local arm=script.detoxDiagnostics()
assert(arm.controller.injection=="DISABLED" and not arm.controller.emergency)
assert(arm.controller.lastEvent.event=="ARM_REJECTED")
assert(arm.bridge.sent==1 and arm.bridge.received==0 and arm.bridge.status=="NO_TRANSPORT")
assert(table.concat(uiLines,"\n"):find("ARM_REJECTED",1,true))
pressed="Enable FX (LOCKED)";script.windowMain();pressed=nil
assert(script.detoxDiagnostics().controller.lastEvent.event=="ENABLE_REJECTED")
assert(script.detoxDiagnostics().controller.reason=="ENABLE_LOCKED_DIAGNOSTIC_ONLY")
pressed="EMERGENCY DISABLE";script.windowMain();pressed=nil
local emergency=script.detoxDiagnostics()
assert(emergency.controller.emergency and emergency.controller.lastEvent.event=="EMERGENCY")
assert(emergency.controller.lastEvent.reason=="APP_UI_EMERGENCY_BUTTON")
pressed="Clear Emergency Latch";script.windowMain();pressed=nil
assert(script.detoxDiagnostics().controller.lastEvent.event=="CLEAR_EMERGENCY")
assert(script.detoxDiagnostics().controller.reason=="RESET_TO_SAFE")
-- Normal and Arm-labelled logging use the same runtime, no race restart.
assert(script.detoxTraceLabel("NORMAL"));script.update(.01)
assert(script.detoxTraceLabel("ARM_ATTEMPT"));script.update(.01)
local samples=script.detoxDiagnostics().samples
assert(samples[#samples].instance==samples[#samples-1].instance)
assert(samples[#samples].label=="ARM_ATTEMPT" and samples[#samples-1].label=="NORMAL")
-- Optional car physics script: its reset is a separate explicit emergency source.
DETOX_PHYSICS_CONTEXT=true
package.loaded.DETOX=nil
script={}
local applied={}
ac.addForce=function(p,pl,f,fl)
  assert(pl and fl and p.z==0 and f.x==0 and f.y==0)
  applied[#applied+1]=f.z
end
local physicsDebug={}
ac.debug=function(key,value) physicsDebug[key]=value end
vec3=function(x,y,z)return {x=x,y=y,z=z}end
require("DETOX")
dofile("E-1/car_physics/script.lua")
script.update(.01)
assert(script.detoxDiagnostics().controller.context=="CAR_PHYSICS")
assert(script.detoxArmTest())
script.update(.01)
assert(script.detoxDiagnostics().controller.injection=="TEST")
assert(script.detoxDiagnostics().controller.calls==0)
assert(script.detoxDiagnostics().controller.adapter.skipped>0)
assert(physicsDebug["DETOX physics addForce calls"]==0)
assert(physicsDebug["DETOX physics bridge received"]==0)
assert(#applied==0,"Arm alone must not touch AC")
assert(script.detoxRequestMicroPulse())
script.update(.01)
assert(#applied==1 and applied[1]==.01)
local pre=script.detoxDiagnostics().controller.preAddForce
assert(pre and pre.localZ==.01 and pre.requestedFX==0)
assert(physicsDebug["DETOX physics addForce calls"]==1)
script.update(.01)
assert(#applied==1,"one-shot must never repeat")
script.reset()
local after=script.detoxDiagnostics()
assert(after.controller.emergency and after.controller.calls==1)
assert(after.controller.lastEvent.reason=="PHYSICS_SCRIPT_RESET")
-- An explicitly supplied in-memory mock transport can prove the contract only.
local Bridge=require("Send.command_bridge")
local Controller=require("Send.injection_controller")
local queue={verified=true}
function queue:send(m)self.message=m;return true end
function queue:receive()local m=self.message;self.message=nil;return m end
local app=Bridge.create("APP_READ_ONLY",queue)
local physics=Bridge.create("CAR_PHYSICS",queue)
local ctrl=Controller.create();ctrl.enabledInPhysics=true
assert(Bridge.send(app,"PING"))
assert(Bridge.poll(physics,ctrl))
assert(physics.received==1 and physics.accepted==1 and ctrl.mode=="DISABLED")
assert(Bridge.send(app,"ARM_FX_TEST"))
assert(Bridge.poll(physics,ctrl)==false and ctrl.mode=="DISABLED")
assert(physics.lastReason=="COMMAND_REJECTED_DIAGNOSTIC_ONLY")
''')
    print("DETOX UI/context/bridge diagnostic tests passed (mock only)")
