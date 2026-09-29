-- E-14/15: independent fail-closed gate; no AC calls or physics calculations.
local S = {}
local N = {"FL","FR","RL","RR"}
local LIMITS = {FX=150, FY=150, FZ=150, TX=30, TY=30, TZ=30}
local function finite(v)
  return type(v)=="number" and v==v and v~=math.huge and v~=-math.huge
end
S.finite = finite
function S.create()
  return {limits=LIMITS, hardMultiplier=4, maxAge=0.25}
end
function S.check(self, output, state, target, lastSequence)
  local result={ok=false, reason="NO_OUTPUT", requested=0, limit=self.limits[target] or 0,
    clamped=false, safeValue=0, fresh=false, stale=true}
  if not output or not state or not state.current then return result end
  local frame=state.frame
  local age=(state.current.vehicle and state.current.vehicle.time or 0)-(output.time or 0)
  result.fresh=output.fresh==true and output.stale==false and
    finite(frame) and frame==output.sequence and output.sequence>lastSequence and
    finite(age) and age>=0 and age<=self.maxAge
  result.stale=not result.fresh
  if not result.fresh then result.reason="STALE"; return result end
  local d=state.current.diagnostics
  if not d or d.valid~=true or d.errors~=0 or state.current.vehicle.valid~=true then
    result.reason="VALIDATION_ERROR"; return result
  end
  if output.valid~=true then result.reason="INVALID_OUTPUT"; return result end
  local input=state.current.vehicle.input or {}
  for _,key in ipairs({"speedKmh","rpm","gas","brake","steer"}) do
    if not finite(input[key]) then result.reason="NON_FINITE_INPUT";return result end
  end
  local vectors={output.force,output.torque}
  for _,v in ipairs(vectors) do
    if not v then result.reason="INVALID_OUTPUT";return result end
    for _,axis in ipairs({"x","y","z"}) do
      if not finite(v[axis]) then result.reason="NON_FINITE";return result end
    end
  end
  for _,name in ipairs(N) do
    local wheel=output.wheels and output.wheels[name]
    if not wheel then result.reason="INVALID_OUTPUT";return result end
    for _,key in ipairs({"load","omega","slipRatio","fx","fy"}) do
      if not finite(wheel[key]) then result.reason="NON_FINITE_WHEEL";return result end
    end
  end
  local values={FX=output.force.x,FY=output.force.y,FZ=output.force.z,
    TX=output.torque.x,TY=output.torque.y,TZ=output.torque.z}
  local value=values[target]
  if not finite(value) or not result.limit or result.limit<=0 then
    result.reason="UNSUPPORTED_TARGET";return result
  end
  result.requested=value
  if math.abs(value)>result.limit*self.hardMultiplier then
    result.reason="MAGNITUDE_OVERFLOW";return result
  end
  result.safeValue=math.max(-result.limit,math.min(result.limit,value))
  result.clamped=result.safeValue~=value
  result.ok=true
  result.reason=result.clamped and "CLAMPED" or "SAFE"
  return result
end
function S.getObserverData(self)
  return {status="OK", maxAge=self.maxAge, hardMultiplier=self.hardMultiplier}
end
return S
