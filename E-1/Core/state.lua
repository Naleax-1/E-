local State={VERSION="E-11"}
local WHEELS={"FL","FR","RL","RR"}
local function v3(x,y,z) return {x=x or 0,y=y or 0,z=z or 0} end
local function wheel() return {
  position=v3(),radius=0.33,inertia=1.8,rotation=0,omega=0,omegaCandidate=0,angularAcceleration=0,
  torque={drive=0,brake=0,tire=0,loss=0,net=0},contactVelocity=v3(),longitudinalVelocity=0,lateralVelocity=0,
  slipRatio=0,slipAngle=0,load=0,force={longitudinal=0,lateral=0,vertical=0},
  suspensionTravel=0,suspensionVelocity=0,contact=false,valid=false
} end
local function tire() return {
  load=0,slipRatio=0,slipAngle=0,combinedSlip=0,surfaceTemperature=30,carcassTemperature=30,pressure=2.0,wear=0,
  carcassDeflection=0,carcassVelocity=0,carcassEnergy=0,carcassHysteresis=0,heatInput=0,cooling=0,slipEnergy=0,thermalGrip=1,
  force={longitudinal=0,lateral=0,vertical=0},reactionTorque=0,valid=false
} end
local function vehicle() return {valid=false,mass=1300,dt=1/333,time=0,speed=0,velocity=v3(),acceleration=v3(),position=v3(),heading=0,
  input={steer=0,gas=0,brake=0,clutch=1,handbrake=0,gear=1,rpm=900}} end
local function body() return {mass=1300,inertia=v3(1500,1800,2500),force=v3(),moment=v3(),acceleration=v3(),angularAcceleration=v3(),
  velocity=v3(),predictedVelocity=v3(),angularVelocity=v3(),predictedAngularVelocity=v3(),position=v3(),attitude={roll=0,pitch=0,yaw=0},valid=false} end
local function powertrain() return {engine={omega=0,rpm=900,torque=0,temperature=90},clutch={inputOmega=0,outputOmega=0,slip=0,torque=0},
  gearbox={gear=1,ratio=3.2,omega=0},shaft={twist=0,omega=0,torque=0,reactionTorque=0},differential={inputTorque=0,lockRatio=0,lockTorque=0,leftTorque=0,rightTorque=0,reactionTorque=0,loss=0.02}} end
local function snapshot() local s={vehicle=vehicle(),body=body(),wheels={},tires={},powertrain=powertrain(),
  coupled={iterations=0,converged=false,residual={force=0,torque=0,velocity=0,wheel=0},maxIterations=3},diagnostics={valid=true,errors=0,lastError="",warnings=0}}
  for _,n in ipairs(WHEELS) do s.wheels[n]=wheel();s.tires[n]=tire() end return s end
local function copy(x) if type(x)~="table" then return x end local r={};for k,v in pairs(x) do r[k]=copy(v) end return r end
function State.create() local s={schema="DETOX.State.3",frame=0,current=snapshot(),next=nil};s.next=copy(s.current);return s end
function State:getWheelNames() return WHEELS end
function State.beginTick(self,dt) self.next=copy(self.current);self.frame=self.frame+1;if type(dt)=="number" and dt>0 and dt<math.huge then self.next.vehicle.dt=dt end;self.next.vehicle.time=(self.current.vehicle.time or 0)+(self.next.vehicle.dt or 1/333);self.next.coupled.iterations=0;self.next.coupled.converged=false;self.next.coupled.residual={force=0,torque=0,velocity=0,wheel=0} end
function State.commit(self) self.current=self.next end
function State.getObserverData(self)
  return {schema=self.schema, frame=self.frame, currentFrame=self.current and self.current.frame or 0}
end
return State
