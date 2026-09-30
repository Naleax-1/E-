-- Read-only diagnostic samples from each runtime instance. No file I/O or AC calls.
local T={}
local function finite(v) return type(v)=="number" and v==v and v~=math.huge and v~=-math.huge end
function T.create(context,instance)
  return {context=context,instance=instance,label="UNLABELLED",rows={},count=0,
    lastSpeed=nil,lastTime=nil,last=nil}
end
function T.setLabel(self,label)
  if type(label)~="string" or (label~="NORMAL" and label~="ARM_ATTEMPT") then
    return false,"INVALID_LABEL"
  end
  self.label=label;return true
end
function T.capture(self,state,output,controller,bridge)
  local vehicle=state and state.current and state.current.vehicle or {}
  local input=vehicle.input or {};local force=output and output.force or {}
  local speed=input.speedKmh
  local time=vehicle.time
  local elapsed=finite(time) and finite(self.lastTime) and time-self.lastTime or 0
  local acceleration=finite(speed) and finite(self.lastSpeed) and elapsed>0
    and (speed-self.lastSpeed)/(3.6*elapsed) or nil
  self.lastSpeed=finite(speed) and speed or nil
  self.lastTime=finite(time) and time or nil
  self.count=self.count+1
  local row={id=self.count,frame=state and state.frame or 0,time=time,
    context=self.context,instance=self.instance,label=self.label,
    speed=speed,acceleration=acceleration,gas=input.gas,brake=input.brake,steer=input.steer,
    FX=force.x,FY=force.y,FZ=force.z,
    injection=controller.mode,safety=controller.safety,reason=controller.reason,
    requested=controller.requested,applied=controller.applied,
    adapterCalls=controller.calls,controllerEvent=controller.lastEvent and controller.lastEvent.event or "NONE",
    bridgeStatus=bridge.status,physicsReceived=bridge.received,
    physicsAccepted=bridge.accepted,physicsApplied=controller.enabledInPhysics and controller.calls or 0,
    addForceCalls=controller.calls}
  self.last=row
  self.rows[#self.rows+1]=row
  if #self.rows>600 then table.remove(self.rows,1) end
  return row
end
local function copyRow(row)
  if not row then return nil end
  local result={}
  for key,value in pairs(row) do result[key]=value end
  return result
end
function T.getRows(self)
  local rows={}
  for i,row in ipairs(self.rows) do rows[i]=copyRow(row) end
  return rows
end
function T.getObserverData(self)
  return {context=self.context,instance=self.instance,label=self.label,
    count=self.count,last=copyRow(self.last)}
end
return T
