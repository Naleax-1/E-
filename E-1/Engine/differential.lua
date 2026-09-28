local D={}
function D.create(def) return {definition=def} end
function D.update(state,def)
  local s=state.next.powertrain
  local input=s.shaft.torque or 0
  local l=s.differential
  local wl=state.next.wheels.RL.omega
  local wr=state.next.wheels.RR.omega
  local diff=wl-wr
  local lock=def.preload+math.abs(input)*(input>=0 and def.powerLock or def.coastLock)
  lock=math.min(lock,def.capacity)
  local split=input*(1-def.loss)
  l.loss=def.loss
  local bias=math.max(-lock,math.min(lock,-diff*0.5))
  l.inputTorque=input
  l.lockTorque=lock
  l.lockRatio=input~=0 and math.min(1,lock/math.abs(input)) or 0
  l.leftTorque=split*0.5+bias
  l.rightTorque=split*0.5-bias
  -- Reaction at the differential input is a positive resisting torque.
  l.reactionTorque=(l.leftTorque+l.rightTorque)
end
function D.getObserverData(state)
  local d=state and state.powertrain and state.powertrain.differential or {}
  return {inputTorque=d.inputTorque or 0, lockRatio=d.lockRatio or 0, lockTorque=d.lockTorque or 0, leftTorque=d.leftTorque or 0, rightTorque=d.rightTorque or 0}
end
return D
