-- DETOX vehicle definition
local D={}
function D.create()
  return {
    mass=1300,
    wheelbase=2.55,
    trackFront=1.48,
    trackRear=1.45,
    cgHeight=0.32,
    cg={x=0,y=0,z=0.32},
    inertia={x=1500,y=1800,z=2500},
    wheelRadius=0.33,
    wheelInertia=1.8,
    staticFront=0.52,
    drivetrain="RWD"
  }
end
function D.apply(state,self)
  local v=self
  state.next.vehicle.mass=v.mass
  state.next.body.mass=v.mass
  state.next.body.inertia.x=v.inertia.x
  state.next.body.inertia.y=v.inertia.y
  state.next.body.inertia.z=v.inertia.z
  local frontX=v.wheelbase*(1-v.staticFront)
  local rearX=-v.wheelbase*v.staticFront
  local tf=v.trackFront*0.5
  local tr=v.trackRear*0.5
  local p={FL={x=frontX,y=tf,z=0},FR={x=frontX,y=-tf,z=0},RL={x=rearX,y=tr,z=0},RR={x=rearX,y=-tr,z=0}}
  for n,pos in pairs(p) do
    state.next.wheels[n].position.x=pos.x
    state.next.wheels[n].position.y=pos.y
    state.next.wheels[n].position.z=pos.z
    state.next.wheels[n].radius=v.wheelRadius
    state.next.wheels[n].inertia=v.wheelInertia
  end
end
function D.getObserverData(self) return self end
return D
