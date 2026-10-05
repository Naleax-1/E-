-- CSP shared layout: identical in the Lua app and its Physics Worker.
-- Based on CSP internal CspDebug.lua / CarDebugWorker.lua (ac.connect).
local T={}
local Safety=require('Safety.injection_safety')
T.CODE={PING=1,ARM_FX_TEST=2,PULSE=3,DISABLE=4,EMERGENCY=5}
T.STATUS={[0]="WAITING",[1]="READY",[2]="PING_ACK",[3]="ARMED",
  [4]="ADD_FORCE_RETURNED",[5]="FAULT",[6]="EMERGENCY",[7]="STALE",
  [8]="DISABLED",[9]="REJECTED"}
T.API_STAGE={[0]="NOT_REACHED",[1]="VALUE_PREPARED",
  [2]="API_AVAILABLE",[3]="CALL_ATTEMPTED",[4]="CALL_RETURNED"}
T.FAULT={[0]="NONE",[1]="SESSION_MISMATCH",[2]="OUTPUT_INVALID",
  [3]="OUTPUT_SEQUENCE_INVALID",[4]="OUTPUT_NON_FINITE",[5]="OUTPUT_OVERFLOW",
  [6]="HEARTBEAT_TIMEOUT",[7]="PULSE_NOT_ARMED",[8]="PULSE_DISABLED",
  [9]="PHYSICS_API_UNAVAILABLE",[10]="VECTOR_API_UNAVAILABLE",
  [11]="API_CALL_FAILED",[12]="EMERGENCY",[13]="UNKNOWN_COMMAND",
  [14]="VECTOR_CONSTRUCTION_FAILED"}
function T.layout()
  return {key=ac.StructItem.key('DETOX.PhysicsWorker.Day2.v2'),
    session=ac.StructItem.int32(),heartbeat=ac.StructItem.int32(),
    outputSeq=ac.StructItem.int32(),outputValid=ac.StructItem.int32(),
    outputFX=ac.StructItem.double(),commandSeq=ac.StructItem.int32(),
    commandCode=ac.StructItem.int32(),emergency=ac.StructItem.int32(),
    disabled=ac.StructItem.int32(),workerSession=ac.StructItem.int32(),
    workerTick=ac.StructItem.int32(),ackSeq=ac.StructItem.int32(),
    received=ac.StructItem.int32(),accepted=ac.StructItem.int32(),
    status=ac.StructItem.int32(),addForceCalls=ac.StructItem.int32(),
    requestedFX=ac.StructItem.double(),preAddForceZ=ac.StructItem.double(),
    appliedFX=ac.StructItem.double(),lastCommand=ac.StructItem.int32(),
    lastCommandSeq=ac.StructItem.int32(),stateBefore=ac.StructItem.int32(),
    stateAfter=ac.StructItem.int32(),faultReason=ac.StructItem.int32(),
    faultDetail=ac.StructItem.string(128),validationResult=ac.StructItem.int32(),
    safetyResult=ac.StructItem.int32(),apiStage=ac.StructItem.int32()}
end
local function finite(v)
  return type(v)=="number" and v==v and v~=math.huge and v~=-math.huge
end
function T.create()
  return setmetatable({verified=false,status="NO_TRANSPORT",shared=nil,session=0,
    lastWorkerTick=0,workerAge=math.huge,commandSeq=0},{__index=T})
end
function T.start(self)
  if not ac or type(ac.connect)~="function" or not ac.StructItem or not physics
    or type(physics.startPhysicsWorker)~="function" then
    self.status="CSP_WORKER_API_UNAVAILABLE";return false,self.status
  end
  local ok,shared=pcall(ac.connect,T.layout())
  if not ok or not shared then self.status="CONNECT_FAILED";return false,tostring(shared) end
  self.shared=shared
  self.session=math.random(1,1000000000)
  shared.session=self.session;shared.heartbeat=0;shared.outputSeq=0
  shared.outputValid=0;shared.outputFX=0;shared.commandSeq=0
  shared.commandCode=0;shared.emergency=0;shared.disabled=1
  shared.workerSession=0;shared.workerTick=0;shared.ackSeq=0
  shared.received=0;shared.accepted=0;shared.status=0
  shared.addForceCalls=0;shared.requestedFX=0
  shared.preAddForceZ=0;shared.appliedFX=0
  shared.lastCommand=0;shared.lastCommandSeq=0
  shared.stateBefore=0;shared.stateAfter=0;shared.faultReason=0
  shared.faultDetail="";shared.validationResult=0;shared.safetyResult=0
  shared.apiStage=0
  local started,err=pcall(physics.startPhysicsWorker,'DetoxPhysicsWorker',self.session,
    function(reason) self.status="WORKER_STOPPED: "..tostring(reason);self.verified=false end)
  if not started or err==false then self.status="WORKER_START_FAILED";return false,tostring(err) end
  self.status="WORKER_STARTING";return true
end
function T.refresh(self,dt)
  local s=self.shared
  if not s then self.verified=false;return false end
  if s.workerSession~=self.session or s.workerTick==0 then
    self.status="WAITING_FOR_WORKER";self.verified=false;return false
  end
  if s.workerTick~=self.lastWorkerTick then
    self.lastWorkerTick=s.workerTick;self.workerAge=0
  else
    self.workerAge=self.workerAge+(finite(dt) and math.max(dt,0) or 0)
  end
  self.verified=self.workerAge<=0.25
  self.status=self.verified and "ACTIVE" or "WORKER_TIMEOUT"
  return self.verified
end
function T.publish(self,output,state,gate)
  local s=self.shared
  if not s then return false end
  local fx=output and output.force and output.force.x
  local checked=gate and state and Safety.check(gate,output,state,'FX',0)
  local valid=checked and checked.ok==true and finite(fx)
  s.outputValid=valid and 1 or 0
  s.outputFX=valid and fx or 0
  s.outputSeq=valid and output.sequence or 0
  s.heartbeat=s.heartbeat+1
  return valid
end
function T.send(self,message)
  local s=self.shared
  local code=message and T.CODE[message.command]
  if not self.verified or not s or not code then return false end
  self.commandSeq=self.commandSeq+1
  if code==T.CODE.EMERGENCY then s.emergency=1;s.disabled=1 end
  if code==T.CODE.DISABLE then s.disabled=1 end
  if code==T.CODE.ARM_FX_TEST and s.emergency==0 then s.disabled=0 end
  s.commandCode=code
  s.commandSeq=self.commandSeq
  return true
end
function T.clearEmergency(self)
  if not self.shared then return false end
  self.shared.disabled=1
  self.shared.emergency=0
  return true
end
function T.getStatus(self)
  local s=self.shared
  if not s then return nil end
  return {status=self.status,physicsContext=s.workerSession==self.session and "PHYSICS_WORKER" or "NONE",
    received=s.received,accepted=s.accepted,ackSeq=s.ackSeq,sentSeq=self.commandSeq,
    workerStatus=T.STATUS[s.status] or "UNKNOWN",calls=s.addForceCalls,
    requestedFX=s.requestedFX,preAddForceZ=s.preAddForceZ,appliedFX=s.appliedFX,
    emergency=s.emergency==1,outputSeq=s.outputSeq,outputValid=s.outputValid==1,
    lastCommand=s.lastCommand,lastCommandSeq=s.lastCommandSeq,
    stateBefore=T.STATUS[s.stateBefore] or "UNKNOWN",
    stateAfter=T.STATUS[s.stateAfter] or "UNKNOWN",
    faultReason=T.FAULT[s.faultReason] or "UNKNOWN",
    faultDetail=tostring(s.faultDetail or ''),validationResult=s.validationResult==1,
    safetyResult=s.safetyResult==1,
    apiStage=T.API_STAGE[s.apiStage] or "UNKNOWN"}
end
return T
