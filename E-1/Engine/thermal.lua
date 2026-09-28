local T={}
function T.create(model) return {model=model} end
function T.update(self,state,model)
  local api=model
  local config=self and self.model
  if type(api)~="table" or type(api.solve)~="function" then error("ThermalModel.solve is unavailable") end
  if type(config)~="table" then error("ThermalModel configuration is unavailable") end
  local solve=api.solve
  local dt=state.next.vehicle.dt
  for _,n in ipairs({"FL","FR","RL","RR"}) do
    local t=state.next.tires[n]; local w=state.next.wheels[n]
    if not t or not w then error("Missing thermal wheel/tire: "..n) end
    local slipEnergy=math.abs((t.force.longitudinal or 0)*(w.longitudinalVelocity or 0)) + math.abs((t.force.lateral or 0)*(w.lateralVelocity or 0))
    local surface,carcass,grip,heat=solve(config,t,slipEnergy,dt)
    t.surfaceTemperature=surface; t.carcassTemperature=carcass
    t.thermalGrip=grip; t.heatInput=heat; t.slipEnergy=slipEnergy
    t.cooling=math.max(0,surface-config.ambient)*config.cooling
  end
end
function T.getObserverData(state)
  local out={}
  for _,name in ipairs({"FL","FR","RL","RR"}) do local t=state and state.tires and state.tires[name] or {}; out[name]={surface=t.surfaceTemperature or 0, carcass=t.carcassTemperature or 0, grip=t.thermalGrip or 0, heat=t.heatInput or 0} end
  return out
end
return T
