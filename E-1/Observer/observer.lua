---@diagnostic disable: undefined-global
-- DETOX Observer E-12
-- Module-connected numerical verification surface.
--
-- The Observer reads snapshots exposed by Core / Engine / Model / Definition / Send.
-- It never performs physics calculation, modifies state, or injects output.

local M = {}
local frame = 0
local observerTime = 0.0
local lastError = ""
local registry = nil
local snapshots = {core={},engine={},model={},definition={},send={},safety={},verification={}}
local WHEELS = {"FL","FR","RL","RR"}

local function num(v,d)
  local n=tonumber(v)
  if n==nil or n~=n or n==math.huge or n==-math.huge then return d or 0 end
  return n
end
local function yes(v) return v and "YES" or "NO" end
local function ok(v) return v and "OK" or "WAIT" end
local function safeCall(entry,state)
  if type(entry)~="table" or type(entry.api)~="table" or type(entry.api.getObserverData)~="function" then
    return false,"CONTRACT MISSING"
  end
  local okCall,result
  if entry.arg~=nil then
    okCall,result=pcall(entry.api.getObserverData,entry.arg,state)
  else
    okCall,result=pcall(entry.api.getObserverData,state)
  end
  if not okCall then return false,tostring(result) end
  if type(result)~="table" then return false,"CONTRACT RETURNED NON-TABLE" end
  return true,result
end
local function collectGroup(group,state)
  local out={}
  for name,entry in pairs(group or {}) do
    local good,data=safeCall(entry,state)
    out[name]={ok=good,data=data}
    if not good then lastError=name..": "..tostring(data) end
  end
  return out
end
local function get(g,n)
  local x=snapshots[g] and snapshots[g][n]
  return x and x.data or nil
end

function M.init()
  frame=0;observerTime=0;lastError="";registry=nil
  snapshots={core={},engine={},model={},definition={},send={}}
end

function M.update(dt,state,input,modules)
  observerTime=observerTime+math.max(num(dt,0),0)
  lastError=""
  registry=modules or registry
  if not registry then return end
  snapshots.core=collectGroup(registry.core,state)
  snapshots.engine=collectGroup(registry.engine,state)
  snapshots.model=collectGroup(registry.model,state)
  snapshots.definition=collectGroup(registry.definition,state)
  snapshots.send=collectGroup(registry.send,state)
  snapshots.safety=collectGroup(registry.safety,state)
  snapshots.verification=collectGroup(registry.verification,state)
end

local function statusLine(group,name)
  local x=snapshots[group] and snapshots[group][name]
  return x and ok(x.ok) or "WAIT"
end

local function drawHeader(state)
  local info=get("core","State") or {}
  ui.text("DETOX Observer")
  ui.text("E-12 BASELINE / E-13 TO E-17 SAFETY VERIFICATION")
  ui.separator()
  ui.text("Frame       : "..tostring(info.frame or 0).." / UI "..tostring(frame))
  ui.text(string.format("Observer    : %.2f s",observerTime))
  ui.text("Schema      : "..tostring(info.schema or "UNKNOWN"))
end

local function drawRuntime(state,input)
  local v=state.vehicle or {};local i=v.input or {};local c=state.coupled or {};local d=state.diagnostics or {}
  local r=c.residual or {}
  ui.separator();ui.text("=== RUNTIME ===")
  ui.text("AC Vehicle   : "..ok(v.valid==true).."   Input : "..statusLine("core","Input"))
  ui.text(string.format("AC Speed %.2f km/h  Sim Speed %.2f km/h",num(i.speedKmh),num(v.speed)*3.6))
  ui.text(string.format("RPM %.0f  Gear %s",num(i.rpm),tostring(i.gear or 0)))
  ui.text(string.format("Steer %.3f  Gas %.3f  Brake %.3f",num(i.steer),num(i.gas),num(i.brake)))
  ui.text("Scheduler    : "..statusLine("core","Scheduler").."   Tick "..tostring((get("core","Scheduler") or {}).tick or 0))
  ui.text("Solver       : "..statusLine("core","CoupledSolver").."   Iter "..tostring(c.iterations or 0).."  Conv "..yes(c.converged))
  ui.text(string.format("Residual F %.4f T %.4f V %.4f W %.4f",num(r.force),num(r.torque),num(r.velocity),num(r.wheel)))
  ui.text("Validation   : "..statusLine("core","Validation").."   Errors "..tostring(d.errors or 0))
  if d.lastError and d.lastError~="" then ui.text("Last Error   : "..tostring(d.lastError)) end
end

local function drawEngine(state)
  local b=get("engine","Body") or {};local pt=get("engine","Powertrain") or {};local df=get("engine","Differential") or {};local wl=get("engine","Wheel") or {}
  local ti=get("engine","Tire") or {};local ca=get("engine","Carcass") or {};local th=get("engine","Thermal") or {};local su=get("engine","Suspension") or {}
  ui.separator();ui.text("=== ENGINE MODULES ===")
  ui.text(string.format("Body %s  Wheel %s  Tire %s  Suspension %s",statusLine("engine","Body"),statusLine("engine","Wheel"),statusLine("engine","Tire"),statusLine("engine","Suspension")))
  ui.text(string.format("Powertrain %s  Differential %s",statusLine("engine","Powertrain"),statusLine("engine","Differential")))
  ui.text(string.format("Carcass %s  Thermal %s",statusLine("engine","Carcass"),statusLine("engine","Thermal")))
  ui.text(string.format("Body V %.2f/%.2f/%.2f",num(b.velocity and b.velocity.x),num(b.velocity and b.velocity.y),num(b.velocity and b.velocity.z)))
  ui.text(string.format("PT RPM %.0f Torque %.1f Gear %s",num(pt.rpm),num(pt.torque),tostring(pt.gear or 0)))
  ui.text(string.format("Diff Lock %.3f  L %.1f  R %.1f",num(df.lockRatio),num(df.leftTorque),num(df.rightTorque)))
  for _,n in ipairs(WHEELS) do
    local w=wl[n] or {};local t=ti[n] or {};local c=ca[n] or {};local h=th[n] or {};local s=su[n] or {}
    ui.text(string.format("%s Load %.1f N O %.2f  T Fx %.1f Fy %.1f  C D %.4f  H %.1f",n,num(w.load),num(w.omega),num(t.Fx),num(t.Fy),num(c.deflection),num(h.surface)))
  end
end

local function drawModelsDefinitions()
  ui.separator();ui.text("=== MODEL / DEFINITION CONTRACTS ===")
  ui.text(string.format("Models: Body %s Tire %s Load %s",statusLine("model","BodyModel"),statusLine("model","TireModel"),statusLine("model","LoadModel")))
  ui.text(string.format("        Carcass %s Thermal %s Coupled %s",statusLine("model","CarcassModel"),statusLine("model","ThermalModel"),statusLine("model","CoupledModel")))
  ui.text(string.format("Definitions: Vehicle %s Powertrain %s Differential %s",statusLine("definition","Vehicle"),statusLine("definition","Powertrain"),statusLine("definition","Differential")))
  ui.text(string.format("            Suspension %s Tire %s",statusLine("definition","Suspension"),statusLine("definition","Tire")))
  local vd=get("definition","Vehicle") or {};local pd=get("definition","Powertrain") or {};local dd=get("definition","Differential") or {};local sd=get("definition","Suspension") or {};local td=get("definition","Tire") or {}
  ui.text(string.format("Vehicle M %.0f WB %.2f TF %.2f TR %.2f",num(vd.mass),num(vd.wheelbase),num(vd.trackFront),num(vd.trackRear)))
  ui.text(string.format("Powertrain Inertia %.3f  Diff Preload %.1f  PowerLock %.2f",num(pd.engine and pd.engine.inertia),num(dd.preload),num(dd.powerLock)))
  ui.text(string.format("Susp Spring F %.0f R %.0f  Tire Peak L %.2f Y %.2f",num(sd.spring and sd.spring.FL),num(sd.spring and sd.spring.RL),num(td.peakLongitudinal),num(td.peakLateral)))
  local cm=get("model","CarcassModel") or {};local tm=get("model","TireModel") or {};local th=get("model","ThermalModel") or {};local co=get("model","CoupledModel") or {}
  ui.text(string.format("Carcass cfg K %.0f D %.0f H %.4f API %s",num(cm.stiffness),num(cm.damping),num(cm.hysteresisGain),yes(cm.api)))
  ui.text(string.format("Tire cfg PeakL %.2f PeakY %.2f Slip %.3f Angle %.3f API %s",num(tm.peakLongitudinal),num(tm.peakLateral),num(tm.slipScale),num(tm.angleScale),yes(tm.api)))
  ui.text(string.format("Thermal Amb %.1f SurfTau %.2f CarcassTau %.2f API %s",num(th.ambient),num(th.surfaceTau),num(th.carcassTau),yes(th.api)))
  ui.text(string.format("Coupled MaxIter %.0f Relax %.2f API %s",num(co.maxIterations),num(co.relaxation),yes(co.api)))
end

local function drawSend()
  local s=get("send","PhysicsOutput") or {}
  ui.separator();ui.text("=== SEND / OUTPUT BOUNDARY ===")
  ui.text("PhysicsOutput : "..statusLine("send","PhysicsOutput"))
  ui.text("Boundary      : "..tostring(s.boundary or "UNKNOWN"))
  ui.text("Injection     : "..tostring(s.injection or "UNKNOWN"))
  ui.text("Applied       : "..tostring(s.applied or 0))
end

local function drawOutputVerification()
  local s=get("send","PhysicsOutput") or {}
  local f=s.force or {}; local t=s.torque or {}; local wheels=s.wheels or {}
  local inj=get("send","Injection") or {}
  local dv=get("verification","Dynamic") or {}
  ui.separator();ui.text("=== PHYSICS OUTPUT VERIFICATION ===")
  ui.text("Output "..tostring(s.output or "NONE").."  Output Valid "..yes(s.valid))
  ui.text(string.format("Sequence %d  Transfer Count %d  Fresh %s  Stale %s",
    num(s.sequence),num(s.transferCount),yes(s.fresh),yes(s.stale)))
  ui.text("=== FORCE ===")
  ui.text(string.format("FX %.2f  FY %.2f  FZ %.2f",num(f.x),num(f.y),num(f.z)))
  ui.text("=== TORQUE ===")
  ui.text(string.format("TX %.2f  TY %.2f  TZ %.2f",num(t.x),num(t.y),num(t.z)))
  ui.text("=== WHEEL OUTPUT ===")
  for _,name in ipairs(WHEELS) do
    local w=wheels[name] or {}
    ui.text(string.format("%s Load %.1f Omega %.2f Slip %.3f Fx %.1f Fy %.1f",
      name,num(w.load),num(w.omega),num(w.slipRatio),num(w.fx),num(w.fy)))
  end
  ui.text("=== OUTPUT BOUNDARY ===")
  ui.text("PhysicsOutput "..statusLine("send","PhysicsOutput").." Boundary "..tostring(s.boundary or "UNKNOWN"))
  ui.text("Injection "..tostring(s.injection or "DISABLED").." Applied "..tostring(s.applied or 0))
  ui.separator();ui.text("=== INJECTION SAFETY ===")
  ui.text("Target "..tostring(inj.target or "FX").." Stage "..tostring(inj.stage or 1).." Context "..tostring(inj.context or "UNKNOWN"))
  ui.text(string.format("Requested %.2f  Applied %.2f  Limit %.2f  Clamped %s",
    num(inj.requested),num(inj.applied),num(inj.limit),yes(inj.clamped)))
  ui.text("Safety "..tostring(inj.safety or "UNKNOWN").." Reason "..tostring(inj.reason or "UNKNOWN"))
  ui.text("Emergency "..yes(inj.emergency).."  Adapter calls "..tostring(inj.calls or 0))
  local bridge=get("send","Bridge") or {}
  local tr=get("verification","Trace") or {}
  local event=inj.lastEvent or {}
  local adapter=inj.adapter or {}
  local before=inj.preAddForce or {}
  ui.text("=== INJECTION STATE MACHINE / TRANSITION LOG ===")
  ui.text("Instance "..tostring(tr.instance or "UNKNOWN").."  Context "..tostring(tr.context or "UNKNOWN"))
  ui.text("State "..tostring(inj.injection or "DISABLED").."  Last event "..tostring(event.event or "NONE"))
  ui.text("Transition "..tostring(event.from or "NONE").." -> "..tostring(event.to or "NONE")..
    " Cause "..tostring(event.reason or "DEFAULT_OFF"))
  local events=inj.transitions or {}
  for idx=math.max(1,#events-4),#events do
    local e=events[idx]
    if e then ui.text(string.format("#%d %s %s -> %s : %s",num(e.id),
      tostring(e.event),tostring(e.from),tostring(e.to),tostring(e.reason))) end
  end
  ui.text("=== APP / PHYSICS BRIDGE (UNVERIFIED UNTIL ACK) ===")
  ui.text("Bridge "..tostring(bridge.status or "NO_TRANSPORT").." Send attempts "..tostring(bridge.sent or 0)..
    " Physics received "..tostring(bridge.received or 0).." accepted "..tostring(bridge.accepted or 0))
  ui.text("Bridge command "..tostring(bridge.lastCommand or "NONE").." Reason "..tostring(bridge.lastReason or "UNKNOWN"))
  ui.text("=== DAY 2 SIX STAGE EVIDENCE (WORKER, NOT MOCK) ===")
  local latestAck=bridge.ack==true and bridge.sentSeq and bridge.sentSeq>0
  local armed=bridge.workerStatus=="ARMED" or bridge.workerStatus=="ADD_FORCE_RETURNED"
  ui.text("APP COMMAND "..yes(bridge.sentSeq and bridge.sentSeq>0)..
    " ("..tostring(bridge.lastCommand or "NONE")..")  TRANSPORT "..tostring(bridge.status or "NO_TRANSPORT"))
  ui.text("PHYSICS RECEIVED "..yes(latestAck and bridge.received and bridge.received>0)..
    "  ACK "..yes(latestAck).." Seq "..tostring(bridge.ackSeq or 0)..
    " / "..tostring(bridge.sentSeq or 0))
  ui.text("PHYSICS CONTEXT "..tostring(bridge.physicsContext or "NONE")..
    "  Worker "..tostring(bridge.workerStatus or "NONE"))
  ui.text("SAFETY ACCEPT "..yes(latestAck and armed and bridge.outputValid)..
    "  addForce EXECUTION "..yes(latestAck and bridge.workerStatus=="ADD_FORCE_RETURNED")..
    "  CALLS "..tostring(bridge.addForceCalls or 0))
  ui.text(string.format("REQUESTED FX %.4f  PRE-API local Z %.4f  APPLIED FX %.4f",
    num(bridge.requestedFX),num(bridge.preAddForceZ),num(bridge.appliedFX)))
  ui.text("VEHICLE RESPONSE NOT PROVEN (0.01 N diagnostic only)")
  ui.text("Adapter safety accepted "..tostring(adapter.accepted or 0).." addForce skipped "..
    tostring(adapter.skipped or 0).." requested "..tostring(adapter.request or 0)..
    " Reason "..tostring(adapter.reason or "DEFAULT_OFF"))
  ui.text(string.format("Pre-addForce FX %.4f  Safe FX %.4f  AC local Z %.4f N",
    num(before.requestedFX),num(before.safeFX),num(before.localZ)))
  local sample=tr.last or {}
  ui.text("=== SAME-SESSION COMPARISON SAMPLE ===")
  ui.text("Label "..tostring(tr.label or "UNLABELLED").." Frame "..tostring(sample.frame or 0)..
    " Count "..tostring(tr.count or 0))
  ui.text(string.format("AC speed %.3f km/h accel %.3f m/s2 gas %.3f brake %.3f steer %.3f",
    num(sample.speed),num(sample.acceleration),num(sample.gas),num(sample.brake),num(sample.steer)))
  ui.text(string.format("FX %.3f FY %.3f FZ %.3f Requested %.3f Applied %.4f addForce calls %d",
    num(sample.FX),num(sample.FY),num(sample.FZ),num(sample.requested),
    num(sample.applied),num(sample.addForceCalls)))
  ui.text("=== DYNAMIC VERIFICATION / PRODUCTION GATE ===")
  ui.text("A (AC standard) "..tostring((dv.count or {}).A or 0)..
    "  B (OFF) "..tostring((dv.count or {}).B or 0)..
    "  C (ON) "..tostring((dv.count or {}).C or 0))
  for _,test in ipairs({"Launch","Acceleration","Braking","Cornering","LoadTransfer"}) do
    local c=(dv.cases or {})[test] or {};local counts=c.counts or {}
    ui.text(string.format("%s A:%d B:%d C:%d %s delta(C-B):%s km/h",
      test,num(counts.A),num(counts.B),num(counts.C),c.status or "PENDING",
      c.deltaCB and string.format("%.3f",c.deltaCB) or "N/A"))
  end
  ui.text("Production Gate "..tostring(dv.productionGate or "PENDING_REAL_AC_EVIDENCE"))
end

local function drawErrors()
  if lastError~="" then
    ui.separator();ui.text("Observer Contract Error: ")
    ui.text(lastError)
  end
end

function M.windowMain(state,input)
  if not state then ui.text("DETOX Observer");ui.text("STATE UNAVAILABLE");return end
  frame=frame+1
  drawHeader(state)
  drawRuntime(state,input)
  drawEngine(state)
  drawModelsDefinitions()
  drawSend()
  drawOutputVerification()
  drawErrors()
end
M.drawUI=M.windowMain
function M.getState() return {frame=frame,observerTime=observerTime,lastError=lastError,snapshots=snapshots} end
return M
