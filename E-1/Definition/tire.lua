-- DETOX common tire definition
local D={}
function D.create()
  return {
    referenceLoad=3500,
    longitudinalStiffness=1.35,
    lateralStiffness=1.20,
    peakLongitudinal=1.55,
    peakLateral=1.45,
    combinedExponent=1.7,
    rollingResistance=0.015,
    optimumTemperature=85,
    temperatureRange=55,
    pressureReference=2.0,
    pressureSensitivity=0.06
  }
end
function D.getObserverData(self) return self end
return D
