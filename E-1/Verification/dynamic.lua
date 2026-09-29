-- E-17: bounded AC telemetry collection. No solver, injection or AC writes.
local D={}
local N={"FL","FR","RL","RR"}
local REQUIRED={"vehicle","track","weather","surface","setup","fuel","tyre","temperature","inputMethod"}
local CASES={"Launch","Acceleration","Braking","Cornering","LoadTransfer"}
local function finite(v) return type(v)=="number" and v==v and v~=math.huge and v~=-math.huge end
function D.create()
  return {conditions=nil, runs={A={},B={},C={}}, count={A=0,B=0,C=0},
    maxRecords=3000, status="PENDING_AC_TEST", reason="NO_MATCHED_A_B_C_RUNS"}
end
function D.setConditions(self,conditions)
  if type(conditions)~="table" then return false,"MISSING_CONDITIONS" end
  for _,key in ipairs(REQUIRED) do
    if conditions[key]==nil or tostring(conditions[key])=="" then
      return false,"MISSING_"..key
    end
  end
  -- Conditions are immutable for the duration of the comparison.
  self.conditions={}
  for _,key in ipairs(REQUIRED) do self.conditions[key]=tostring(conditions[key]) end
  self.runs={A={},B={},C={}};self.count={A=0,B=0,C=0}
  self.status="PENDING_AC_TEST";self.reason="NO_MATCHED_A_B_C_RUNS"
  return true
end
local function append(self,mode,sample)
  if not self.conditions or self.count[mode]>=self.maxRecords then return false end
  self.count[mode]=self.count[mode]+1
  self.runs[mode][self.count[mode]]=sample
  return true
end
function D.record(self,state,output,controller)
  if not self.conditions or not output or not output.valid then return false end
  local s=state.current;local v=s.vehicle or {};local i=v.input or {}
  local mode=(controller.mode=="TEST" or controller.mode=="ENABLED") and "C" or "B"
  if controller.mode=="FAULT" or controller.emergency then return false end
  local wheels={}; local maxSlip=0;local maxAngle=0
  for _,name in ipairs(N) do
    local w=s.wheels[name]
    if not w then return false end
    local acWheel=(i.acWheels or {})[name] or {}
    wheels[name]={omega=w.omega,slip=w.slipRatio,angle=w.slipAngle,load=w.load,
      temperature=s.tires[name].surfaceTemperature,
      acOmega=acWheel.omega,acSlip=acWheel.slip,acLoad=acWheel.load}
    maxSlip=math.max(maxSlip,math.abs(w.slipRatio))
    maxAngle=math.max(maxAngle,math.abs(w.slipAngle))
  end
  local previous=self.runs[mode][self.count[mode]]
  -- Measured AC speed difference, not DETOX's internally integrated body acceleration.
  local elapsed=previous and v.time-previous.time or 0
  local acAcceleration=previous and elapsed>0 and
    (i.speedKmh-previous.speed)/(3.6*elapsed) or 0
  local sample={time=v.time,frame=state.frame,speed=i.speedKmh,rpm=i.rpm,
    throttle=i.gas,brake=i.brake,steer=i.steer,
    acceleration=acAcceleration, deceleration=-acAcceleration,
    force=output.force.x,fy=output.force.y,torque=output.torque.z,
    applied=controller.applied,wheels=wheels,maxSlip=maxSlip,maxAngle=maxAngle}
  for _,key in ipairs({"time","speed","rpm","throttle","brake","steer","acceleration","force","applied"}) do
    if not finite(sample[key]) then self.reason="NON_FINITE_SAMPLE";return false end
  end
  sample.tests={
    Launch=sample.speed<10 and sample.throttle>0.1,
    Acceleration=sample.speed>=10 and sample.throttle>0.1 and sample.brake<0.1,
    Braking=sample.brake>0.1,
    Cornering=math.abs(sample.steer)>0.1,
    LoadTransfer=math.abs(sample.acceleration)>0.2 or math.abs(sample.steer)>0.1}
  return append(self,mode,sample)
end
-- A cannot be fabricated from B: this accepts independently captured AC-standard samples.
function D.addStandard(self,sample,conditions)
  if not self.conditions or type(sample)~="table" or type(conditions)~="table" then return false end
  for _,key in ipairs(REQUIRED) do
    if tostring(conditions[key])~=self.conditions[key] then return false end
  end
  if not finite(sample.speed) or not finite(sample.rpm) or
     not finite(sample.time) or type(sample.tests)~="table" then return false end
  return append(self,"A",sample)
end
function D.getObserverData(self)
  local cases={}
  for _,test in ipairs(CASES) do
    local counts={A=0,B=0,C=0}
    local means={}
    for _,mode in ipairs({"A","B","C"}) do
      local total=0
      for _,sample in ipairs(self.runs[mode]) do
        if sample.tests[test] and finite(sample.speed) then
          counts[mode]=counts[mode]+1;total=total+sample.speed
        end
      end
      means[mode]=counts[mode]>0 and total/counts[mode] or nil
    end
    cases[test]={counts=counts,means=means,
      deltaCB=means.C and means.B and (means.C-means.B) or nil,
      status=(counts.A>0 and counts.B>0 and counts.C>0) and "MEASUREMENT_AVAILABLE" or "PENDING"}
  end
  -- API acceptance is NOT proof of a changed AC vehicle state. Only real
  -- matched on-car measurements can promote this gate, never mock tests.
  return {status=self.status,reason=self.reason,count={A=self.count.A,B=self.count.B,C=self.count.C},
    conditions=self.conditions,cases=cases,productionGate="PENDING_REAL_AC_EVIDENCE"}
end
return D
