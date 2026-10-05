-- CSP Physics Worker, NOT a Lua app and NOT car_physics/script.lua.
-- Official pattern: CspDebug/CarDebugWorker.lua (ac.connect + worker.input).
local Channel=require('Send.worker_channel')
local shared=ac.connect(Channel.layout())
local session=worker.input
local lastCommand=0
local heartbeat=shared.heartbeat
local idle=0
local armed=false
local calls=0
local function finite(v)return type(v)=='number' and v==v and v~=math.huge and v~=-math.huge end
local function status(code)
  shared.status=code;shared.stateAfter=code
  shared.workerSession=session
end
local function reject(code,reason,detail)
  armed=false;shared.disabled=1;shared.appliedFX=0
  shared.safetyResult=0
  shared.faultReason=reason or 0
  shared.faultDetail=string.sub(tostring(detail or ''),1,127)
  status(code)
end
local function outputFault(fx)
  if shared.outputValid~=1 then return 2 end
  if shared.outputSeq<=0 then return 3 end
  if not finite(fx) then return 4 end
  if math.abs(fx)>600 then return 5 end
  if idle>0.25 then return 6 end
  return 0
end
function script.update(dt)
  if shared.session~=session then
    reject(8,1)
    worker.terminate()
    return
  end
  shared.workerTick=shared.workerTick+1
  if shared.heartbeat~=heartbeat then heartbeat=shared.heartbeat;idle=0
  else idle=idle+(finite(dt) and math.max(dt,0) or 1) end
  if shared.emergency==1 then reject(6,12)
  elseif idle>0.25 then reject(7,6)
  elseif shared.workerTick==1 then status(1) end
  if shared.commandSeq<=lastCommand then return end
  local seq,command=shared.commandSeq,shared.commandCode
  lastCommand=seq
  shared.stateBefore=shared.status
  shared.lastCommand=command;shared.lastCommandSeq=seq
  shared.faultReason=0;shared.faultDetail=''
  shared.validationResult=0;shared.safetyResult=0
  shared.apiStage=0;shared.requestedFX=0;shared.preAddForceZ=0
  shared.received=shared.received+1
  shared.ackSeq=seq
  -- Emergency always wins, including if received in the same frame as a pulse.
  if shared.emergency==1 or command==Channel.CODE.EMERGENCY then
    shared.emergency=1;reject(6,12);shared.accepted=shared.accepted+1;return
  end
  if command==Channel.CODE.DISABLE then
    reject(8,0);shared.accepted=shared.accepted+1;return
  end
  if idle>0.25 then reject(7,6);return end
  if command==Channel.CODE.PING then
    shared.validationResult=1;shared.safetyResult=1
    status(2);shared.accepted=shared.accepted+1;return
  end
  if command==Channel.CODE.ARM_FX_TEST then
    local reason=outputFault(shared.outputFX)
    if reason~=0 then reject(9,reason);return end
    shared.validationResult=1;shared.safetyResult=1
    armed=true;shared.disabled=0;shared.appliedFX=0
    status(3);shared.accepted=shared.accepted+1;return
  end
  if command~=Channel.CODE.PULSE then reject(9,13);return end
  if not armed then reject(9,7);return end
  if shared.disabled~=0 then reject(9,8);return end
  -- Consume the arm and mark DISABLED before attempting the single API call.
  armed=false;shared.disabled=1;shared.appliedFX=0
  local fx=shared.outputFX
  local reason=outputFault(fx)
  if reason~=0 then reject(5,reason);return end
  shared.validationResult=1;shared.safetyResult=1
  shared.requestedFX=fx
  shared.preAddForceZ=0.01
  shared.apiStage=1
  -- Official Physics Worker API: physics.addForce(carIndex, pos, posLocal, force, forceLocal).
  if not physics or type(physics.addForce)~='function' then
    reject(5,9);return
  end
  if type(vec3)~='function' then reject(5,10);return end
  shared.apiStage=2
  -- Distinguish vector construction from the native API call without retrying either.
  local vectorsOK,pos,force=pcall(function()
    return vec3(0,0,0),vec3(0,0,0.01)
  end)
  if not vectorsOK then reject(5,14,pos);return end
  shared.apiStage=3
  local ok,err=pcall(physics.addForce,0,pos,true,force,true)
  if not ok then reject(5,11,err);return end
  shared.apiStage=4
  calls=calls+1;shared.addForceCalls=calls;shared.appliedFX=0.01
  shared.accepted=shared.accepted+1
  status(4) -- API return, NOT proof of changed vehicle motion.
end
