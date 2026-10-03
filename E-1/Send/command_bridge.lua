-- Diagnostic contract. CSP WorkerChannel is opt-in and ACTIVE only after
-- worker heartbeat; the legacy mock transport is never proof of AC success.
local B = {}
local Controller = require("Send.injection_controller")
function B.create(role, transport)
  return {role=role, transport=transport, status=transport and "UNVERIFIED_TRANSPORT" or "NO_TRANSPORT",
    sent=0, received=0, accepted=0, lastCommand="NONE", lastReason="NO_CROSS_CONTEXT_TRANSPORT",
    lastSequence=0, allowRemoteArm=false}
end
function B.send(self, command)
  self.sent=self.sent+1
  self.lastCommand=command
  if not self.transport or self.transport.verified~=true or type(self.transport.send)~="function" then
    self.status=self.transport and self.transport.status or "NO_TRANSPORT"
    self.lastReason=self.transport and "WORKER_NOT_READY" or "NO_CROSS_CONTEXT_TRANSPORT"
    return false,self.lastReason
  end
  local ok,result=pcall(self.transport.send,self.transport,{version=1,sequence=self.sent,command=command})
  if not ok or result~=true then
    self.status="TRANSPORT_ERROR";self.lastReason=tostring(result);return false,self.lastReason
  end
  self.status="SENT_UNACKNOWLEDGED";self.lastReason="WAITING_FOR_PHYSICS_ACK"
  return true
end
function B.poll(self, controller)
  if self.role~="CAR_PHYSICS" or not self.transport or self.transport.verified~=true or type(self.transport.receive)~="function" then
    return false,"NO_CROSS_CONTEXT_TRANSPORT"
  end
  local ok,message=pcall(self.transport.receive,self.transport)
  if not ok then self.status="TRANSPORT_ERROR";self.lastReason=tostring(message);return false,self.lastReason end
  if not message then return false,"NO_COMMAND" end
  self.received=self.received+1
  self.lastCommand=tostring(message.command or "UNKNOWN")
  if message.version~=1 or type(message.sequence)~="number" or message.sequence<=self.lastSequence then
    self.lastReason="INVALID_OR_REPLAYED_COMMAND";return false,self.lastReason
  end
  self.lastSequence=message.sequence
  if message.command=="PING" then
    self.accepted=self.accepted+1;self.status="PHYSICS_ACK";self.lastReason="PING_ACK"
    return true,"PING_ACK"
  end
  if message.command=="DISABLE" then
    Controller.disable(controller,"BRIDGE_DISABLING")
    self.accepted=self.accepted+1;self.status="PHYSICS_ACK";self.lastReason="DISABLE_ACK"
    return true,"DISABLE_ACK"
  end
  if message.command=="ARM_FX_TEST" and self.allowRemoteArm==true then
    local accepted,reason=Controller.armTest(controller,"BRIDGE_ARM_TEST")
    if accepted then self.accepted=self.accepted+1;self.status="PHYSICS_ACK" end
    self.lastReason=accepted and "ARM_ACK" or tostring(reason)
    return accepted,self.lastReason
  end
  self.lastReason="COMMAND_REJECTED_DIAGNOSTIC_ONLY"
  return false,self.lastReason
end
function B.getObserverData(self)
  local details=self.transport and type(self.transport.getStatus)=="function"
    and self.transport:getStatus() or nil
  local ack=details and details.sentSeq>0 and details.ackSeq==details.sentSeq
  return {role=self.role,status=details and details.status or self.status,
    ack=ack==true,
    sent=self.sent,received=details and details.received or self.received,
    accepted=details and details.accepted or self.accepted,
    ackSeq=details and details.ackSeq or 0,
    sentSeq=details and details.sentSeq or 0,
    physicsContext=details and details.physicsContext or "NONE",
    workerStatus=details and details.workerStatus or "NONE",
    addForceCalls=details and details.calls or 0,
    requestedFX=details and details.requestedFX or 0,
    preAddForceZ=details and details.preAddForceZ or 0,
    appliedFX=details and details.appliedFX or 0,
    outputValid=details and details.outputValid or false,
    lastCommand=self.lastCommand,lastReason=self.lastReason,
    allowRemoteArm=self.allowRemoteArm}
end
return B
