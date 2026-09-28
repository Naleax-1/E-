local M={}
function M.create()
  return {
    maxIterations=3,
    forceTolerance=5.0,
    torqueTolerance=0.5,
    velocityTolerance=0.01,
    wheelTolerance=0.5,
    relaxation=0.65
  }
end
function M.getObserverData(self) return {maxIterations=self.maxIterations, forceTolerance=self.forceTolerance, torqueTolerance=self.torqueTolerance, velocityTolerance=self.velocityTolerance, wheelTolerance=self.wheelTolerance, relaxation=self.relaxation, api=true} end
return M
