local Input = {}
function Input.create() return {available=false,lastError=nil} end
local function safe(fn,default)
  local ok,v=pcall(fn); if ok and v~=nil then return v end; return default
end
local function getCar()
  if ac and ac.getCar then
    local ok,c=pcall(ac.getCar,0)
    if ok and c then return c,nil end
    if not ok then return nil,tostring(c) end
  end
  if ac and ac.getCarState then
    local ok,c=pcall(ac.getCarState,0)
    if ok and c then return c,nil end
    if not ok then return nil,tostring(c) end
  end
  return nil,"no compatible car-state API"
end
function Input.update(self,state)
  local n=state.next.vehicle
  self.lastError=nil
  local c,err=getCar()
  if not c then
    self.available=false
    self.lastError=err or "AC car state returned nil"
    n.valid=false
    return false
  end
  n.input.speedKmh=safe(function() return c.speedKmh end,n.input.speedKmh or 0)
  n.speed=n.input.speedKmh/3.6
  n.velocity=safe(function() return c.velocity end,n.velocity)
  n.input.steer=safe(function() return c.steer end,n.input.steer)
  n.input.gas=safe(function() return c.gas end,n.input.gas)
  n.input.brake=safe(function() return c.brake end,n.input.brake)
  n.input.clutch=safe(function() return c.clutch end,n.input.clutch)
  n.input.handbrake=safe(function() return c.handbrake end,n.input.handbrake)
  n.input.gear=safe(function() return c.gear end,n.input.gear)
  n.input.rpm=safe(function() return c.rpm end,n.input.rpm)
  -- Independent AC measurements for E-17; do not overwrite DETOX wheel states.
  n.input.acWheels={}
  for index,name in ipairs({"FL","FR","RL","RR"}) do
    local i=index-1 -- CSP wheel arrays are zero-based.
    n.input.acWheels[name]={
      omega=safe(function() return c.wheelAngularSpeed[i] end,nil),
      slip=safe(function() return c.wheelSlipRatio[i] end,nil),
      load=safe(function() return c.wheelLoad[i] end,nil)
    }
  end
  n.valid=true; self.available=true
  return true
end
function Input.getObserverData(self)
  return {available=self.available==true, lastError=self.lastError or ""}
end
return Input
