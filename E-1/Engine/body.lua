local B={}
local function n(x,d)return type(x)=="number" and x==x and x~=math.huge and x~=-math.huge and x or d end
local function v3(v)return{x=n(v and v.x,0),y=n(v and v.y,0),z=n(v and v.z,0)}end
local function cross(r,f)return{x=r.y*f.z-r.z*f.y,y=r.z*f.x-r.x*f.z,z=r.x*f.y-r.y*f.x}end
function B.create(model)return{model=model}end
function B.compute(state,model)
 local b=state.next.body or {}; local dt=n(state.next.vehicle and state.next.vehicle.dt,1/333)
 b.mass=n(b.mass,state.next.vehicle and state.next.vehicle.mass or 1300)
 b.inertia=b.inertia or {x=1500,y=1800,z=2500}
 b.velocity=v3(b.velocity); b.angularVelocity=v3(b.angularVelocity); b.predictedVelocity=v3(b.predictedVelocity); b.predictedAngularVelocity=v3(b.predictedAngularVelocity)
 local force={x=0,y=0,z=-b.mass*9.81};local moment={x=0,y=0,z=0}
 for _,name in ipairs({"FL","FR","RL","RR"}) do
  local w=state.next.wheels[name] or {}; local r=v3(w.position)
  local wf=w.force or {}
  local f={x=n(wf.longitudinal,0),y=n(wf.lateral,0),z=n(wf.vertical,0)}
  force.x=force.x+f.x; force.y=force.y+f.y; force.z=force.z+f.z
  local m=cross(r,f); moment.x=moment.x+m.x; moment.y=moment.y+m.y; moment.z=moment.z+m.z
 end
 b.force=force;b.moment=moment
 b.acceleration={x=force.x/b.mass,y=force.y/b.mass,z=force.z/b.mass}
 b.angularAcceleration={x=moment.x/math.max(n(b.inertia.x,1500),1),y=moment.y/math.max(n(b.inertia.y,1800),1),z=moment.z/math.max(n(b.inertia.z,2500),1)}
 b.predictedVelocity={x=b.velocity.x+b.acceleration.x*dt,y=b.velocity.y+b.acceleration.y*dt,z=b.velocity.z+b.acceleration.z*dt}
 b.predictedAngularVelocity={x=b.angularVelocity.x+b.angularAcceleration.x*dt,y=b.angularVelocity.y+b.angularAcceleration.y*dt,z=b.angularVelocity.z+b.angularAcceleration.z*dt}
end
function B.integrate(state)
 local b=state.next.body;local dt=n(state.next.vehicle.dt,1/333)
 b.velocity=v3(b.predictedVelocity);b.angularVelocity=v3(b.predictedAngularVelocity)
 b.position=v3(b.position);b.attitude=b.attitude or {roll=0,pitch=0,yaw=0}
 b.position.x=b.position.x+b.velocity.x*dt;b.position.y=b.position.y+b.velocity.y*dt;b.position.z=b.position.z+b.velocity.z*dt
 b.attitude.roll=n(b.attitude.roll,0)+b.angularVelocity.x*dt;b.attitude.pitch=n(b.attitude.pitch,0)+b.angularVelocity.y*dt;b.attitude.yaw=n(b.attitude.yaw,0)+b.angularVelocity.z*dt
 b.valid=true
 state.next.vehicle.velocity=v3(b.velocity);state.next.vehicle.acceleration=v3(b.acceleration);state.next.vehicle.position=v3(b.position)
end
function B.getObserverData(state)
  local b=state and state.body or {}
  return {valid=b.valid==true, velocity=b.velocity, acceleration=b.acceleration, angularVelocity=b.angularVelocity, force=b.force, moment=b.moment}
end
return B
