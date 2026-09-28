local M={}
local function tanh(x)
  -- Lua runtimes used by AC/CSP do not all expose math.tanh.
  local e2=math.exp(2*x)
  return (e2-1)/(e2+1)
end
function M.create()
  return {
    peakLongitudinal=1.25,peakLateral=1.30,
    slipScale=0.12,angleScale=0.10,combinedScale=1.0
  }
end
function M.solve(self,wheel,tire)
  local fz=math.max(wheel.load,0)
  local sr=wheel.slipRatio
  local sa=wheel.slipAngle
  local thermal=math.max(tire.thermalGrip or 1,0)
  local deflect=math.max(0,1-0.15*math.min(math.abs(tire.carcassDeflection or 0),1))
  local grip=thermal*deflect
  local sx=tanh(sr/self.slipScale)
  local sy=tanh(sa/self.angleScale)
  local combined=math.sqrt(sx*sx+sy*sy)
  local scale=combined>1 and 1/combined or 1
  return {
    longitudinal=fz*self.peakLongitudinal*grip*sx*scale,
    lateral=fz*self.peakLateral*grip*sy*scale,
    vertical=fz,
    reactionTorque=-(fz*self.peakLongitudinal*grip*sx*scale)*wheel.radius
  }
end
function M.getObserverData(self) return {peakLongitudinal=self.peakLongitudinal, peakLateral=self.peakLateral, slipScale=self.slipScale, angleScale=self.angleScale, combinedScale=self.combinedScale, api=true} end
return M
