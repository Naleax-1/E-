local M={}
function M.create() return {referenceLoad=3500,loadExponent=0.92} end
function M.solve(self,load,scale)
  local l=math.max(load or 0,0)
  return l*(math.max(scale or 1,0.05))^self.loadExponent
end
function M.getObserverData(self) return {referenceLoad=self.referenceLoad, loadExponent=self.loadExponent, api=true} end
return M
