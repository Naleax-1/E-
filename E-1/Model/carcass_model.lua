local M={}
function M.create()
  return {stiffness=180000,damping=1200,hysteresisGain=0.015}
end
function M.solve(self,tire,load,dt)
  local target=math.max(load,0)/self.stiffness
  local prev=tire.carcassDeflection or 0
  local def=prev+(target-prev)*math.min(dt*18,1)
  local vel=(def-prev)/math.max(dt,1e-5)
  local energy=(tire.carcassEnergy or 0)*0.985+math.abs(vel*load)*dt
  local hyst=math.min(1,math.abs(vel)*self.hysteresisGain)
  return def,vel,energy,hyst
end
function M.getObserverData(self) return {stiffness=self.stiffness, damping=self.damping, hysteresisGain=self.hysteresisGain, api=true} end
return M
