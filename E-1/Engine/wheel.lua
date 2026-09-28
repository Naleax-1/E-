local W={}
local N={"FL","FR","RL","RR"}
local function n(x,d)return type(x)=="number" and x==x and x~=math.huge and x~=-math.huge and x or d end
function W.create() return {} end
function W.updateKinematics(state)
 local b=state.next.body or {}; local pv=b.predictedVelocity or b.velocity or {}; local av=b.angularVelocity or {}; pv={x=n(pv.x,0),y=n(pv.y,0),z=n(pv.z,0)}; av={x=n(av.x,0),y=n(av.y,0),z=n(av.z,0)}
 for _,name in ipairs(N) do
  local w=state.next.wheels[name];w.position=w.position or {x=0,y=0,z=0};w.contactVelocity=w.contactVelocity or {x=0,y=0,z=0}
  local r=w.position
  w.contactVelocity.x=pv.x+av.y*n(r.z,0)-av.z*n(r.y,0)
  w.contactVelocity.y=pv.y+av.z*n(r.x,0)-av.x*n(r.z,0)
  w.contactVelocity.z=pv.z+av.x*n(r.y,0)-av.y*n(r.x,0)
  w.longitudinalVelocity=n(w.contactVelocity.x,0);w.lateralVelocity=n(w.contactVelocity.y,0)
 end
end
function W.updateSlip(state)
 for _,name in ipairs(N) do local w=state.next.wheels[name];w.omega=n(w.omega,0);w.radius=n(w.radius,0.33);local ref=math.max(math.abs(n(w.longitudinalVelocity,0)),1);w.slipRatio=(w.omega*w.radius-n(w.longitudinalVelocity,0))/ref;w.slipAngle=math.atan(n(w.lateralVelocity,0)/math.max(math.abs(n(w.longitudinalVelocity,0)),0.5)) end
end
function W.solveRotationCandidate(state,driveByWheel,dt)
 dt=n(dt,1/333)
 for _,name in ipairs(N) do local w=state.next.wheels[name];w.torque=w.torque or {};local tireTorque=n(w.torque.tire,0);local brake=n(w.torque.brake,0);local drive=n(driveByWheel[name],0);local sign=n(w.omega,0)>=0 and 1 or -1;local loss=n(w.torque.loss,0);local net=drive-brake*sign+tireTorque-loss*sign;w.inertia=n(w.inertia,1.8);w.angularAcceleration=net/math.max(w.inertia,0.01);w.omegaCandidate=n(w.omega,0)+w.angularAcceleration*dt;w.torque.drive=drive;w.torque.net=net end
end
function W.commitRotation(state,dt)
 dt=n(dt,1/333);for _,name in ipairs(N) do local w=state.next.wheels[name];w.omega=n(w.omegaCandidate,w.omega or 0);w.rotation=n(w.rotation,0)+w.omega*dt end
end
function W.getObserverData(state)
  local out={}
  for _,name in ipairs(N) do local w=state and state.wheels and state.wheels[name] or {}; out[name]={valid=w.valid==true, omega=w.omega or 0, load=w.load or 0, slipRatio=w.slipRatio or 0, slipAngle=w.slipAngle or 0, longitudinalVelocity=w.longitudinalVelocity or 0, lateralVelocity=w.lateralVelocity or 0} end
  return out
end
return W
