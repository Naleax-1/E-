-- DETOX suspension/load definition
local D={}
function D.create()
  return {
    spring={FL=35000,FR=35000,RL=30000,RR=30000},
    damper={FL=3500,FR=3500,RL=3200,RR=3200},
    travel=0.08,
    staticFront=0.52,
    rollStiffnessFront=0.56,
    rollStiffnessRear=0.44,
    pitchStiffness=0.60,
    aeroLoad=0
  }
end
function D.getObserverData(self) return self end
return D
