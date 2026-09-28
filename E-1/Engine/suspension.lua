local S={}
local N={"FL","FR","RL","RR"}
function S.create(model) return {model=model} end
function S.update(state,model,definition)
  local mass=state.next.body.mass or state.next.vehicle.mass
  local g=9.81
  local total=mass*g+math.max(0,definition.aeroLoad or 0)
  local staticFront=definition.staticFront or 0.52
  local front=total*staticFront
  local rear=total-front
  local ax=state.next.body.acceleration.x or 0
  local ay=state.next.body.acceleration.y or 0
  local h=0.32
  local wb=2.55
  local trackF=1.48
  local trackR=1.45
  local pitchTransfer=mass*ax*h/wb
  local lateral=mass*ay*h
  local frontLat=lateral*(definition.rollStiffnessFront or 0.56)
  local rearLat=lateral*(definition.rollStiffnessRear or 0.44)
  local loads={
    FL=(front-pitchTransfer)*0.5-frontLat/trackF,
    FR=(front-pitchTransfer)*0.5+frontLat/trackF,
    RL=(rear+pitchTransfer)*0.5-rearLat/trackR,
    RR=(rear+pitchTransfer)*0.5+rearLat/trackR
  }
  for _,n in ipairs(N) do
    local w=state.next.wheels[n]
    w.load=math.max(0,loads[n])
    w.force.vertical=w.load
    local previousTravel = state.current.wheels[n].suspensionTravel or 0
    w.suspensionVelocity=-(w.suspensionTravel-previousTravel)/math.max(state.next.vehicle.dt,1e-4)
  end
end
function S.getObserverData(state)
  local out={}
  for _,name in ipairs(N) do local w=state and state.wheels and state.wheels[name] or {}; out[name]={load=w.load or 0, travel=w.suspensionTravel or 0, velocity=w.suspensionVelocity or 0} end
  return out
end
return S
