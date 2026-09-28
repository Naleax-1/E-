local M={}
function M.create()
  return {
    ambient=25,surfaceTau=0.35,carcassTau=2.0,cooling=0.018,
    heatGain=0.0008,optimum=85,window=35,minGrip=0.65
  }
end
function M.solve(self,tire,slipEnergy,dt)
  local surface=tire.surfaceTemperature or self.ambient
  local carcass=tire.carcassTemperature or self.ambient
  local heat=math.max(slipEnergy or 0,0)*self.heatGain
  local surfaceTarget=surface+heat-(surface-self.ambient)*self.cooling
  surface=surface+(surfaceTarget-surface)*math.min(dt/self.surfaceTau,1)
  carcass=carcass+(surface-carcass)*math.min(dt/self.carcassTau,1)
  local d=(surface-self.optimum)/self.window
  local grip=1-0.35*d*d
  if grip<self.minGrip then grip=self.minGrip end
  return surface,carcass,grip,heat
end
function M.getObserverData(self) return {ambient=self.ambient, surfaceTau=self.surfaceTau, carcassTau=self.carcassTau, cooling=self.cooling, heatGain=self.heatGain, api=true} end
return M
