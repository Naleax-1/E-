local T={}
function T.create(model) return {model=model} end
function T.update(self,state,model)
  local api=model
  local config=self and self.model
  if type(api)~="table" or type(api.solve)~="function" then error("TireModel.solve is unavailable") end
  if type(config)~="table" then error("TireModel configuration is unavailable") end
  local solve=api.solve
  for _,n in ipairs({"FL","FR","RL","RR"}) do
    local w=state.next.wheels[n]; local t=state.next.tires[n]
    if not w or not t then error("Missing tire wheel/tire: "..n) end
    local f=solve(config,w,t)
    t.load=w.load; t.slipRatio=w.slipRatio; t.slipAngle=w.slipAngle
    t.force.longitudinal=f.longitudinal; t.force.lateral=f.lateral; t.force.vertical=f.vertical
    t.reactionTorque=f.reactionTorque
    w.force.longitudinal=f.longitudinal; w.force.lateral=f.lateral; w.force.vertical=f.vertical
    w.torque.tire=f.reactionTorque; t.valid=true; w.valid=true
  end
end
function T.getObserverData(state)
  local out={}
  for _,name in ipairs({"FL","FR","RL","RR"}) do local t=state and state.tires and state.tires[name] or {}; out[name]={valid=t.valid==true, load=t.load or 0, slipRatio=t.slipRatio or 0, slipAngle=t.slipAngle or 0, Fx=t.force and t.force.longitudinal or 0, Fy=t.force and t.force.lateral or 0, Fz=t.force and t.force.vertical or 0, thermalGrip=t.thermalGrip or 0} end
  return out
end
return T
