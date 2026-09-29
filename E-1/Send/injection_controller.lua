-- E-14/15/16: explicit, latched, single-axis controller.
-- Only FX has a verified CSP addForce adapter. All other output channels remain observe-only.
local C={}
local Safety=require("Safety.injection_safety")
function C.create()
  return {mode="DISABLED", emergency=false, fault=false, stage=1, target="FX",
    requested=0, applied=0, limit=150, clamped=false, safety="DISABLED",
    reason="DEFAULT_OFF", lastSequence=0, calls=0, enabledInPhysics=false,
    gate=Safety.create()}
end
function C.disable(self)
  self.mode="DISABLED"; self.applied=0; self.safety="DISABLED"
  self.reason="MANUAL_OFF";return true
end
function C.emergencyDisable(self)
  self.emergency=true;self.mode="DISABLED";self.applied=0
  self.safety="EMERGENCY";self.reason="EMERGENCY_DISABLE"
end
function C.faultOff(self,reason)
  self.fault=true;self.mode="FAULT";self.applied=0
  self.safety="FAULT";self.reason=reason or "UNKNOWN_FAULT"
end
function C.resetFault(self)
  if self.emergency then return false,"EMERGENCY_LATCHED" end
  self.fault=false;self.mode="DISABLED";self.applied=0
  self.safety="SAFE";self.reason="RESET_TO_SAFE"
  return true
end
function C.clearEmergency(self)
  self.emergency=false
  return C.resetFault(self)
end
local function supported(self)
  return self.enabledInPhysics and ac and type(ac.addForce)=="function"
    and type(vec3)=="function" and self.stage==1 and self.target=="FX"
end
function C.armTest(self)
  if self.emergency or self.fault then return false,"LATCHED" end
  if not supported(self) then return false,"PHYSICS_CONTEXT_OR_TARGET_UNAVAILABLE" end
  self.mode="TEST";self.reason="TEST_ARMED";return true
end
function C.enable(self)
  if self.mode~="TEST" then return false,"TEST_REQUIRED" end
  if not supported(self) then return false,"PHYSICS_CONTEXT_OR_TARGET_UNAVAILABLE" end
  self.mode="ENABLED";self.reason="ENABLED";return true
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
  -- Never attempt any AC API call before complete validation.
  local result=Safety.check(self.gate,output,state,self.target,self.lastSequence)
  self.limit=result.limit;self.clamped=result.clamped
  self.safety=result.ok and "OK" or "FAULT"
  self.reason=result.reason
  if not result.ok then C.faultOff(self,result.reason);return end
  if not supported(self) then C.faultOff(self,"PHYSICS_CONTEXT_OR_TARGET_UNAVAILABLE");return end
  local value=result.safeValue*(self.mode=="TEST" and 0.1 or 1)
  -- AC local forward axis is +Z (DETOX longitudinal axis is +X).
  -- CSP car physics API: ac.addForce(position, positionLocal, force, forceLocal).
  local ok,err=pcall(ac.addForce,vec3(0,0,0),true,vec3(0,0,value),true)
  if not ok then C.faultOff(self,"AC_APPLY_FAILED: "..tostring(err));return end
  self.applied=value;self.calls=self.calls+1;self.lastSequence=output.sequence
  self.reason=result.reason
end
function C.getObserverData(self)
  return {injection=self.mode,target=self.target,stage=self.stage,
    requested=self.requested,applied=self.applied,limit=self.limit,
    clamped=self.clamped,safety=self.safety,reason=self.reason,
    emergency=self.emergency,fault=self.fault,calls=self.calls,
    context=self.enabledInPhysics and "CAR_PHYSICS" or "APP_READ_ONLY"}
end
return C
