local D={}
function D.create()
  return {preload=20,powerLock=0.20,coastLock=0.10,rampAnglePower=45,rampAngleCoast=60,capacity=1200,loss=0.02}
end
function D.getObserverData(self) return self end
return D
