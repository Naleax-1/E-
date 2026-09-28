local C={}
function C.create(model) return {model=model} end
function C.update(self,state,model)
  local api=model
  local config=self and self.model
  if type(api)~="table" or type(api.solve)~="function" then
    error("CarcassModel.solve is unavailable")
  end
  if type(config)~="table" then error("CarcassModel configuration is unavailable") end
  local solve=api.solve
  local dt=state.next.vehicle.dt
  for _,n in ipairs({"FL","FR","RL","RR"}) do
    local t=state.next.tires[n]; local w=state.next.wheels[n]
    if not t or not w then error("Missing carcass wheel/tire: "..n) end
    local d,v,e,h=solve(config,t,w.load,dt)
    t.carcassDeflection=d; t.carcassVelocity=v; t.carcassEnergy=e; t.carcassHysteresis=h
  end
end
function C.getObserverData(state)
  local out={}
  for _,name in ipairs({"FL","FR","RL","RR"}) do local t=state and state.tires and state.tires[name] or {}; out[name]={deflection=t.carcassDeflection or 0, velocity=t.carcassVelocity or 0, energy=t.carcassEnergy or 0, hysteresis=t.carcassHysteresis or 0} end
  return out
end
return C
