local V={};local N={"FL","FR","RL","RR"}
local function finite(x)return type(x)=="number" and x==x and x~=math.huge and x~=-math.huge end
function V.validate(state)
 local d=state.next.diagnostics;d.valid=true;d.errors=0;d.warnings=0;d.lastError=""
 local function fail(m)d.valid=false;d.errors=d.errors+1;d.lastError=m end
 local b=state.next.body
 for _,x in ipairs({b.velocity.x,b.velocity.y,b.velocity.z,b.acceleration.x,b.acceleration.y,b.acceleration.z,b.angularVelocity.x,b.angularVelocity.y,b.angularVelocity.z})do if not finite(x)then fail("Non-finite body state");break end end
 local pt=state.next.powertrain.differential;local expected=pt.inputTorque*(1-(pt.loss or 0.02));local total=pt.leftTorque+pt.rightTorque
 if math.abs(total-expected)>math.max(1,math.abs(expected)*0.05)then fail("Differential torque conservation")end
 for _,n in ipairs(N)do local w=state.next.wheels[n];local t=state.next.tires[n];if not w or not t then fail("Missing wheel/tire: "..n)else for _,x in ipairs({w.omega,w.load,w.force.longitudinal,w.force.lateral,t.force.longitudinal,t.force.lateral,t.force.vertical})do if not finite(x)then fail("Non-finite wheel state: "..n);break end end end end
 if state.next.coupled.iterations<=0 then fail("Coupled solver did not execute")end
 return d.valid
end
function V.getObserverData(state)
  local d=state and state.current and state.current.diagnostics or {}
  return {valid=d.valid==true, errors=d.errors or 0, warnings=d.warnings or 0, lastError=d.lastError or ""}
end
return V
