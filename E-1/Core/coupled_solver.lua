local S={}
local N={"FL","FR","RL","RR"}
local function n(x,d)return type(x)=="number" and x==x and x~=math.huge and x~=-math.huge and x or d end
local function abs(x)return math.abs(n(x,0))end
local function relax(old,new,a)return n(old,0)+(n(new,0)-n(old,0))*n(a,0.65)end
local function metrics(state,previous)
 local r={force=0,torque=0,velocity=0,wheel=0}
 for _,name in ipairs(N) do local w=state.next.wheels[name] or {};local t=state.next.tires[name] or {};local f=t.force or {};local tw=w.torque or {};local cv=w.contactVelocity or {};local p=previous[name] or {}
  r.force=math.max(r.force,abs(n(f.longitudinal,0)-n(p.fx,0)),abs(n(f.lateral,0)-n(p.fy,0)))
  r.torque=math.max(r.torque,abs(n(tw.tire,0)-n(p.torque,0)))
  r.velocity=math.max(r.velocity,abs(n(cv.x,0)-n(p.vx,0)))
  r.wheel=math.max(r.wheel,abs(n(w.omegaCandidate,w.omega or 0)-n(p.omega,0)))
 end
 return r
end
function S.create(model)return{model=model,iterations=0,converged=false,residual={force=0,torque=0,velocity=0,wheel=0}}end
local function requireFn(owner,name,label)
 local fn=owner and owner[name]
 if type(fn)~="function" then
  error("CoupledSolver API missing: "..label.."."..name)
 end
 return fn
end
function S.update(solver,state,modules)
 local m=solver.model;
 if type(m)~="table" then error("CoupledSolver model is unavailable") end
 local ptSolve=requireFn(modules.powertrain,"solveReaction","Powertrain")
 local diffUpdate=requireFn(modules.differential,"update","Differential")
 local bodyCompute=requireFn(modules.body,"compute","Body")
 local wheelKinematics=requireFn(modules.wheel,"updateKinematics","Wheel")
 local wheelSlip=requireFn(modules.wheel,"updateSlip","Wheel")
 local suspensionUpdate=requireFn(modules.suspension,"update","Suspension")
 local carcassUpdate=requireFn(modules.carcass,"update","Carcass")
 local thermalUpdate=requireFn(modules.thermal,"update","Thermal")
 local tireUpdate=requireFn(modules.tire,"update","Tire")solver.iterations=0;solver.converged=false;local previous={}
 for _,name in ipairs(N)do local w=state.next.wheels[name] or {};local t=state.next.tires[name] or {};local f=t.force or {};local tw=w.torque or {};local cv=w.contactVelocity or {};previous[name]={fx=n(f.longitudinal,0),fy=n(f.lateral,0),torque=n(tw.tire,0),vx=n(cv.x,0),omega=n(w.omega,0)}end
 for i=1,n(m.maxIterations,3) do
  solver.iterations=i
  ptSolve(state,modules.powertrainDefinition);diffUpdate(state,modules.differentialDefinition);bodyCompute(state,modules.bodyModel);wheelKinematics(state);wheelSlip(state);suspensionUpdate(state,modules.loadModel,modules.suspensionDefinition);carcassUpdate(modules.carcassInstance,state,modules.carcassModel);thermalUpdate(modules.thermalInstance,state,modules.thermalModel);tireUpdate(modules.tireInstance,state,modules.tireModel)
  local pt=state.next.powertrain.differential or {};local drive={FL=0,FR=0,RL=n(pt.leftTorque,0),RR=n(pt.rightTorque,0)};modules.wheel.solveRotationCandidate(state,drive,state.next.vehicle.dt);modules.body.compute(state,modules.bodyModel)
  local residual=metrics(state,previous);solver.residual=residual
  if residual.force<=n(m.forceTolerance,5) and residual.torque<=n(m.torqueTolerance,.5) and residual.velocity<=n(m.velocityTolerance,.01) and residual.wheel<=n(m.wheelTolerance,.5)then solver.converged=true;break end
  for _,name in ipairs(N)do local w=state.next.wheels[name];local t=state.next.tires[name];local p=previous[name];w.omegaCandidate=relax(p.omega,w.omegaCandidate or w.omega,m.relaxation);w.torque.tire=relax(p.torque,w.torque.tire,m.relaxation);t.force.longitudinal=relax(p.fx,t.force.longitudinal,m.relaxation);t.force.lateral=relax(p.fy,t.force.lateral,m.relaxation);w.force.longitudinal=t.force.longitudinal;w.force.lateral=t.force.lateral;previous[name]={fx=t.force.longitudinal,fy=t.force.lateral,torque=w.torque.tire,vx=(w.contactVelocity and w.contactVelocity.x) or 0,omega=w.omega}
  end
 end
 return solver.converged
end
function S.getObserverData(self)
  return {iterations=self.iterations or 0, converged=self.converged==true, residual=self.residual or {}}
end
return S
