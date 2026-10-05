"""SDK-shaped worker simulation: deliberately NOT an AC/CSP hardware test."""
from test_runtime import execute


if __name__ == "__main__":
    execute(r'''
package.path='./E-1/?.lua;'..package.path
script={};ui={text=function()end,separator=function()end}
local shared={}
ac={getCar=function()return {speedKmh=0,rpm=900,gear=1,gas=0,brake=0,
  steer=0,clutch=1,handbrake=0}end}
ac.StructItem={key=function()return {}end,int32=function()return {}end,
  double=function()return {}end,string=function()return {}end}
ac.connect=function(layout)assert(layout.session and layout.commandSeq);return shared end
local calls={}
physics={startPhysicsWorker=function(name,key,callback)
  assert(name=='DetoxPhysicsWorker' and type(key)=='number')
end,addForce=function(car,pos,posLocal,force,forceLocal)
  assert(car==0 and pos.z==0 and posLocal and forceLocal)
  calls[#calls+1]=force.z
end}
vec3=function(x,y,z)return {x=x,y=y,z=z}end
dofile('E-1/DETOX.lua')
local appScript=script
appScript.update(.01)
assert(appScript.detoxDiagnostics().bridge.status=='WAITING_FOR_WORKER')
assert(not appScript.detoxArmTest()) -- no worker heartbeat means no command
worker={input=shared.session,terminate=function()error('unexpected termination')end}
script={};dofile('E-1/DetoxPhysicsWorker.lua')
local workerScript=script
workerScript.update(.003)
script=appScript;appScript.update(.01)
local bridge=appScript.detoxDiagnostics().bridge
assert(bridge.status=='ACTIVE' and bridge.physicsContext=='PHYSICS_WORKER')
assert(bridge.addForceCalls==0 and bridge.received==0)
assert(appScript.detoxSendPing())
script=workerScript;workerScript.update(.003)
script=appScript;appScript.update(.01)
bridge=appScript.detoxDiagnostics().bridge
assert(bridge.ack and bridge.received==1 and bridge.accepted==1)
assert(bridge.workerStatus=='PING_ACK' and #calls==0)
assert(appScript.detoxArmTest())
script=workerScript;workerScript.update(.003)
script=appScript;appScript.update(.01)
bridge=appScript.detoxDiagnostics().bridge
assert(bridge.ack and bridge.received==2 and bridge.accepted==2)
assert(bridge.workerStatus=='ARMED' and #calls==0)
assert(appScript.detoxRequestMicroPulse())
script=workerScript;workerScript.update(.003)
script=appScript;appScript.update(.01)
bridge=appScript.detoxDiagnostics().bridge
assert(bridge.ack and bridge.workerStatus=='ADD_FORCE_RETURNED')
assert(bridge.addForceCalls==1 and bridge.preAddForceZ==.01)
assert(bridge.appliedFX==.01 and #calls==1 and calls[1]==.01)
script=workerScript;workerScript.update(.003)
assert(#calls==1,'one-shot call must not repeat')
script=appScript;assert(appScript.detoxArmTest())
script=workerScript;workerScript.update(.003)
script=appScript;appScript.update(.01)
assert(appScript.detoxRequestMicroPulse())
shared.outputValid=0 -- invalidated between App publication and worker pulse
script=workerScript;workerScript.update(.003)
assert(#calls==1 and shared.status==5 and shared.disabled==1)
assert(shared.faultReason==2 and shared.stateBefore==3 and shared.stateAfter==5)
assert(shared.apiStage==0 and shared.preAddForceZ==0)
script=appScript;appScript.update(.01)
assert(appScript.detoxArmTest())
script=workerScript;workerScript.update(.003)
script=appScript;appScript.update(.01)
assert(appScript.detoxRequestMicroPulse())
physics.addForce=nil -- the CSP version/API availability case
script=workerScript;workerScript.update(.003)
assert(shared.status==5 and shared.faultReason==9 and shared.apiStage==1)
assert(shared.preAddForceZ==.01 and shared.addForceCalls==1)
script=appScript;appScript.update(.01)
assert(appScript.detoxArmTest())
script=workerScript;workerScript.update(.003)
script=appScript;appScript.update(.01)
assert(appScript.detoxRequestMicroPulse())
physics.addForce=function()error('mock native call failure')end
script=workerScript;workerScript.update(.003)
assert(shared.status==5 and shared.faultReason==11 and shared.apiStage==3)
assert(shared.faultDetail:find('mock native call failure',1,true))
assert(shared.addForceCalls==1)
script=appScript;appScript.update(.01)
assert(appScript.detoxArmTest())
script=workerScript;workerScript.update(.003)
script=appScript;appScript.update(.01)
assert(appScript.detoxRequestMicroPulse())
vec3=function()error('mock vector construction failure')end
script=workerScript;workerScript.update(.003)
assert(shared.status==5 and shared.faultReason==14 and shared.apiStage==2)
assert(shared.faultDetail:find('mock vector construction failure',1,true))
assert(shared.addForceCalls==1)
script=appScript;assert(appScript.detoxArmTest())
assert(appScript.detoxEmergencyDisable('TEST_EMERGENCY'))
script=workerScript;workerScript.update(.003)
assert(#calls==1 and shared.status==6 and shared.emergency==1)
script=appScript;appScript.update(.01)
assert(appScript.detoxDiagnostics().bridge.workerStatus=='EMERGENCY')
assert(appScript.detoxClearEmergency())
assert(shared.disabled==1)
-- Worker watchdog independently disarms when app heartbeat stops.
script=workerScript;workerScript.update(.003)
workerScript.update(.30)
assert(shared.status==7 and shared.disabled==1)
''')
    print('DETOX worker protocol tests passed (SDK-shaped mock only)')
