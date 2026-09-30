-- FX-only diagnostic state machine. TEST is dry-run unless a single 0.01 N pulse
-- is explicitly requested in the car physics context. ENABLED is locked.
local C={}
local Safety=require("Safety.injection_safety")
local function trace(self,event,from,to,reason)
  self.eventId=self.eventId+1
  local row={id=self.eventId,event=event,from=from,to=to,reason=reason,
    context=self.enabledInPhysics and "CAR_PHYSICS" or "APP_READ_ONLY"}
  local rows=self.transitions
  rows[#rows+1]=row
  if #rows>32 then table.remove(rows,1) end
  self.lastEvent=row
end
function C.create()
  local self={mode="DISABLED",emergency=false,fault=false,stage=1,target="FX",
    requested=0,applied=0,limit=150,clamped=false,safety="DISABLED",
    reason="DEFAULT_OFF",lastSequence=0,calls=0,enabledInPhysics=false,
    gate=Safety.create(),eventId=0,transitions={},lastEvent=nil,
    microPulseArmed=false,microPulseCount=0,preAddForce=nil,
    adapter={received=0,accepted=0,skipped=0,request=0,reason="DEFAULT_OFF"}}
  trace(self,"CREATE","NONE","DISABLED","DEFAULT_OFF")
  return self
end
local function reject(self,event,reason)
  self.reason=reason
  trace(self,event,self.mode,self.mode,reason)
  return false,reason
end
function C.disable(self,origin)
  local old=self.mode
  self.mode="DISABLED";self.applied=0;self.microPulseArmed=false
  self.safety=self.emergency and "EMERGENCY" or "DISABLED"
  self.reason=self.emergency and "EMERGENCY_DISABLE" or "MANUAL_OFF"
  trace(self,"DISABLE",old,self.mode,origin or self.reason)
  return true
end
function C.emergencyDisable(self,origin)
  local old=self.mode
  self.emergency=true;self.mode="DISABLED";self.applied=0
  self.microPulseArmed=false;self.safety="EMERGENCY";self.reason="EMERGENCY_DISABLE"
  trace(self,"EMERGENCY",old,self.mode,origin or "EXPLICIT_EMERGENCY_COMMAND")
  return true
end
function C.faultOff(self,reason)
  local old=self.mode
  self.fault=true;self.mode="FAULT";self.applied=0
  self.microPulseArmed=false;self.safety="FAULT";self.reason=reason or "UNKNOWN_FAULT"
  trace(self,"FAULT",old,self.mode,self.reason)
end
function C.resetFault(self)
  if self.emergency then return reject(self,"RESET_REJECTED","EMERGENCY_LATCHED") end
  local old=self.mode
  self.fault=false;self.mode="DISABLED";self.applied=0
  self.microPulseArmed=false;self.safety="SAFE";self.reason="RESET_TO_SAFE"
  trace(self,"RESET",old,self.mode,self.reason)
  return true
end
function C.clearEmergency(self)
  local old=self.mode
  self.emergency=false;self.fault=false;self.mode="DISABLED";self.applied=0
  self.microPulseArmed=false;self.safety="SAFE";self.reason="RESET_TO_SAFE"
  trace(self,"CLEAR_EMERGENCY",old,self.mode,"EXPLICIT_CLEAR")
  return true
end
local function supported(self)
  return self.enabledInPhysics and ac and type(ac.addForce)=="function"
    and type(vec3)=="function" and self.stage==1 and self.target=="FX"
end
function C.armTest(self,origin)
  if self.emergency or self.fault then return reject(self,"ARM_REJECTED","LATCHED") end
  if not supported(self) then return reject(self,"ARM_REJECTED","PHYSICS_CONTEXT_OR_TARGET_UNAVAILABLE") end
  local old=self.mode
  self.mode="TEST";self.reason="TEST_ARMED_DRY_RUN"
  trace(self,"ARM",old,self.mode,origin or "EXPLICIT_ARM_TEST")
  return true
end
function C.enable(self)
  -- Never allow full-strength output in a diagnostic build.
  return reject(self,"ENABLE_REJECTED","ENABLE_LOCKED_DIAGNOSTIC_ONLY")
end
function C.requestMicroPulse(self)
  if self.mode~="TEST" or self.emergency or self.fault or not supported(self) then
    return reject(self,"PULSE_REJECTED","TEST_PHYSICS_CONTEXT_REQUIRED")
  end
  self.microPulseArmed=true
  trace(self,"PULSE_ARMED",self.mode,self.mode,"ONE_SHOT_0.01_N")
  return true
end
function C.setStage(self,stage)
  if self.mode~="DISABLED" or self.emergency or self.fault then return false,"DISABLE_FIRST" end
  if stage~=1 then return false,"NO_VERIFIED_AC_ADAPTER_FOR_STAGE" end
  self.stage=stage;return true
end
function C.update(self,output,state)
  self.applied=0;self.requested=output and output.force and output.force.x or 0
  self.clamped=false
  if self.emergency then self.mode="DISABLED";self.safety="EMERGENCY";self.reason="EMERGENCY_DISABLE";return end
  if self.fault then self.mode="FAULT";self.safety="FAULT";return end
  if self.mode=="DISABLED" then self.safety="DISABLED";return end
  local result=Safety.check(self.gate,output,state,self.target,self.lastSequence)
  self.limit=result.limit;self.clamped=result.clamped
  self.safety=result.ok and "OK" or "FAULT";self.reason=result.reason
  if not result.ok then C.faultOff(self,result.reason);return end
  if not supported(self) then C.faultOff(self,"PHYSICS_CONTEXT_OR_TARGET_UNAVAILABLE");return end
  self.adapter.accepted=self.adapter.accepted+1
  if not self.microPulseArmed then
    self.adapter.skipped=self.adapter.skipped+1
    self.adapter.reason="TEST_DRY_RUN_ADD_FORCE_SKIPPED"
    self.reason=self.adapter.reason
    return
  end
  -- Consume BEFORE attempting the API: a failed call cannot cause a repeat.
  self.microPulseArmed=false
  local value=0.01 -- fixed diagnostic pulse, unrelated to calculated FX magnitude
  self.preAddForce={sequence=output.sequence,requestedFX=self.requested,
    safeFX=result.safeValue,localX=0,localY=0,localZ=value,mode=self.mode}
  self.adapter.request=self.adapter.request+1
  self.adapter.reason="ADD_FORCE_REQUESTED"
  trace(self,"ADD_FORCE_REQUEST",self.mode,self.mode,"ONE_SHOT_0.01_N")
  local ok,err=pcall(ac.addForce,vec3(0,0,0),true,vec3(0,0,value),true)
  if not ok then C.faultOff(self,"AC_APPLY_FAILED: "..tostring(err));return end
  self.applied=value;self.calls=self.calls+1;self.microPulseCount=self.microPulseCount+1
  self.lastSequence=output.sequence;self.reason="API_CALL_RETURNED_NOT_PHYSICAL_PROOF"
  self.adapter.reason=self.reason
  trace(self,"ADD_FORCE_RETURNED",self.mode,self.mode,self.reason)
end
function C.getObserverData(self)
  local rows={}
  for i,row in ipairs(self.transitions) do
    rows[i]={id=row.id,event=row.event,from=row.from,to=row.to,
      reason=row.reason,context=row.context}
  end
  local p=self.preAddForce
  return {injection=self.mode,target=self.target,stage=self.stage,
    requested=self.requested,applied=self.applied,limit=self.limit,
    clamped=self.clamped,safety=self.safety,reason=self.reason,
    emergency=self.emergency,fault=self.fault,calls=self.calls,
    context=self.enabledInPhysics and "CAR_PHYSICS" or "APP_READ_ONLY",
    microPulseArmed=self.microPulseArmed,microPulseCount=self.microPulseCount,
    preAddForce=p and {sequence=p.sequence,requestedFX=p.requestedFX,
      safeFX=p.safeFX,localX=p.localX,localY=p.localY,localZ=p.localZ,mode=p.mode} or nil,
    adapter={received=self.adapter.received,accepted=self.adapter.accepted,
      skipped=self.adapter.skipped,request=self.adapter.request,reason=self.adapter.reason},
    lastEvent=self.lastEvent,transitions=rows}
end
return C
