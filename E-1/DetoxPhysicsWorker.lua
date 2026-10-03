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
  shared.status=code
  shared.workerSession=session
end
local function reject(code)
  armed=false;shared.disabled=1;shared.appliedFX=0
  status(code)
end
function script.update(dt)
  if shared.session~=session then
    reject(8)
    worker.terminate()
    return
  end
  shared.workerTick=shared.workerTick+1
  if shared.heartbeat~=heartbeat then heartbeat=shared.heartbeat;idle=0
  else idle=idle+(finite(dt) and math.max(dt,0) or 1) end
  if shared.emergency==1 then reject(6)
  elseif idle>0.25 then reject(7)
  elseif shared.workerTick==1 then status(1) end
  if shared.commandSeq<=lastCommand then return end
  local seq,command=shared.commandSeq,shared.commandCode
  lastCommand=seq
  shared.received=shared.received+1
  shared.ackSeq=seq
  -- Emergency always wins, including if received in the same frame as a pulse.
  if shared.emergency==1 or command==Channel.CODE.EMERGENCY then
    shared.emergency=1;reject(6);shared.accepted=shared.accepted+1;return
  end
  if command==Channel.CODE.DISABLE then
    reject(8);shared.accepted=shared.accepted+1;return
  end
  if idle>0.25 then reject(7);return end
  if command==Channel.CODE.PING then
    status(2);shared.accepted=shared.accepted+1;return
  end
  if command==Channel.CODE.ARM_FX_TEST then
    if shared.outputValid~=1 or shared.outputSeq<=0 or not finite(shared.outputFX)
      or math.abs(shared.outputFX)>600 then reject(9);return end
    armed=true;shared.disabled=0;shared.appliedFX=0
    status(3);shared.accepted=shared.accepted+1;return
  end
  if command~=Channel.CODE.PULSE or not armed or shared.disabled~=0 then reject(9);return end
  -- Consume the arm and mark DISABLED before attempting the single API call.
  armed=false;shared.disabled=1;shared.appliedFX=0
  local fx=shared.outputFX
  if shared.outputValid~=1 or shared.outputSeq<=0 or not finite(fx)
    or math.abs(fx)>600 or idle>0.25 then reject(5);return end
  shared.requestedFX=fx
  shared.preAddForceZ=0.01
  -- Official Physics Worker API: physics.addForce(carIndex, pos, posLocal, force, forceLocal).
  if not physics or type(physics.addForce)~='function' or type(vec3)~='function' then
    reject(5);return
  end
  local ok=pcall(physics.addForce,0,vec3(0,0,0),true,vec3(0,0,0.01),true)
  if not ok then reject(5);return end
  calls=calls+1;shared.addForceCalls=calls;shared.appliedFX=0.01
  shared.accepted=shared.accepted+1
  status(4) -- API return, NOT proof of changed vehicle motion.
end
