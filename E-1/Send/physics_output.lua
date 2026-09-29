-- E-13: a read-only, per-committed-frame copy of existing DETOX outputs.
local O = {}
local N = {"FL", "FR", "RL", "RR"}
local function finite(x)
  return type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge
end
local function xyz(v)
  v = v or {}
  return {x = v.x, y = v.y, z = v.z}
end
function O.create()
  return {sequence = 0, transferCount = 0, fresh = false, stale = true,
    valid = false, boundary = "READ_ONLY", injection = "DISABLED", applied = 0, time = 0,
    force = {x=0,y=0,z=0}, torque = {x=0,y=0,z=0}, wheels = {},
    reason = "NO_OUTPUT"}
end
function O.update(self, state)
  if not state or not state.current or not state.frame or state.frame <= self.sequence then
    self.fresh = false; self.stale = true; self.valid = false
    self.reason = "STALE_SEQUENCE"
    return false
  end
  local s = state.current
  local b = s.body or {}
  self.sequence = state.frame
  self.time = s.vehicle and s.vehicle.time
  self.transferCount = self.transferCount + 1
  self.force = xyz(b.force)
  self.torque = xyz(b.moment)
  self.wheels = {}
  self.valid = s.diagnostics and s.diagnostics.valid == true and s.vehicle and s.vehicle.valid == true
  for _, name in ipairs(N) do
    local w = s.wheels and s.wheels[name]
    local t = s.tires and s.tires[name]
    self.wheels[name] = {load = w and w.load, omega = w and w.omega,
      slipRatio = w and w.slipRatio, fx = t and t.force and t.force.longitudinal,
      fy = t and t.force and t.force.lateral}
    if not w or not t then self.valid = false end
    local values = self.wheels[name]
    if not finite(values.load) or not finite(values.omega) or
      not finite(values.slipRatio) or not finite(values.fx) or not finite(values.fy) then
      self.valid = false
    end
  end
  if not finite(self.time) then self.valid = false end
  for _, key in ipairs({"x","y","z"}) do
    if not finite(self.force[key]) or not finite(self.torque[key]) then self.valid = false end
  end
  self.fresh = true; self.stale = false
  self.reason = self.valid and "OK" or "INVALID_OUTPUT"
  return self.valid
end
function O.invalidate(self, reason)
  self.fresh = false; self.stale = true; self.valid = false
  self.applied = 0; self.reason = reason or "RUNTIME_ERROR"
end
function O.getObserverData(self)
  -- Return a copy, never the writable producer object.
  local wheels = {}
  for _, name in ipairs(N) do
    local w = self.wheels[name] or {}
    wheels[name] = {load=w.load,omega=w.omega,slipRatio=w.slipRatio,fx=w.fx,fy=w.fy}
  end
  return {output="BODY_AND_WHEELS", valid=self.valid, sequence=self.sequence,
    transferCount=self.transferCount, fresh=self.fresh, stale=self.stale,
    force=xyz(self.force), torque=xyz(self.torque), wheels=wheels,
    boundary=self.boundary, injection=self.injection, applied=self.applied,
    reason=self.reason}
end
return O
