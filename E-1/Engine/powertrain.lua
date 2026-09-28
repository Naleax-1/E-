local P={}
local function curve(def,rpm)
  local c=def.engine.torqueCurve
  if rpm<=c[1].rpm then return c[1].torque end
  for i=2,#c do
    if rpm<=c[i].rpm then
      local a,b=c[i-1],c[i]; local t=(rpm-a.rpm)/(b.rpm-a.rpm)
      return a.torque+(b.torque-a.torque)*t
    end
  end
  return c[#c].torque
end
function P.create(def) return {definition=def} end
function P.update(state,def)
  local s=state.next.powertrain
  local inp=state.next.vehicle.input
  local rpm=math.max(inp.rpm or s.engine.rpm or def.engine.idleRPM,def.engine.idleRPM)
  rpm=math.min(rpm,def.engine.limiterRPM)
  local eng=curve(def,rpm)*(inp.gas or 0)
  local ratio=def.gearbox.ratios[inp.gear or 1] or 0
  local clutch=(inp.clutch==nil and 1 or inp.clutch)
  s.engine.rpm=rpm; s.engine.omega=rpm*2*math.pi/60; s.engine.torque=eng
  s.gearbox.gear=inp.gear or 1; s.gearbox.ratio=ratio
  s.gearbox.omega=s.engine.omega*ratio
  s.clutch.inputOmega=s.engine.omega; s.clutch.outputOmega=s.gearbox.omega
  s.clutch.slip=s.clutch.inputOmega-s.clutch.outputOmega
  s.clutch.torque=eng*math.max(0,math.min(1,clutch))
  -- E-10: gearbox/final-drive multiplication happens exactly here, once.
  s.shaft.omega=s.gearbox.omega
  s.shaft.torque=s.clutch.torque*ratio*def.gearbox.finalDrive
  s.shaft.reactionTorque=s.differential.reactionTorque or 0
end
function P.solveReaction(state,def)
  local s=state.next.powertrain
  local reaction=s.differential.reactionTorque or 0
  local base=s.clutch.torque*(s.gearbox.ratio or 0)*def.gearbox.finalDrive
  s.shaft.torque=base-reaction
end
function P.getObserverData(state)
  local p=state and state.powertrain or {}; local e=p.engine or {}; local g=p.gearbox or {}; local s=p.shaft or {}
  return {rpm=e.rpm or 0, torque=e.torque or 0, gear=g.gear or 0, ratio=g.ratio or 0, shaftTorque=s.torque or 0, shaftOmega=s.omega or 0}
end
return P
