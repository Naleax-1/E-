-- Optional car data/script.lua entry point. NOT loaded by the DETOX Lua app.
-- Install the DETOX.lua and Core/ Engine/ Model/ Definition/ Observer/
-- Safety/ Send/ Verification/ folders alongside this file in a car's
-- unpacked data directory. Requires CSP extended physics and on-car testing.
-- This does not enable forces: it only allows explicit TEST arming later.
DETOX_PHYSICS_CONTEXT = true
require('DETOX')

-- Separate physics-thread trace in CSP Lua Debug (if available). This is
-- NOT a link to the Lua App: it reports this script's own controller only.
local updatePhysics = script.update
function script.update(dt)
  updatePhysics(dt)
  if not ac or type(ac.debug)~="function" or not script.detoxDiagnostics then return end
  local d=script.detoxDiagnostics()
  if not d then return end
  local c,b=d.controller,d.bridge
  pcall(ac.debug,"DETOX physics state",c.injection)
  pcall(ac.debug,"DETOX physics emergency",c.emergency)
  pcall(ac.debug,"DETOX physics bridge received",b.received)
  pcall(ac.debug,"DETOX physics bridge accepted",b.accepted)
  pcall(ac.debug,"DETOX physics safety",c.safety)
  pcall(ac.debug,"DETOX physics addForce calls",c.calls)
  pcall(ac.debug,"DETOX physics last adapter",c.adapter.reason)
  pcall(ac.debug,"DETOX physics pre-addForce Z",c.preAddForce and c.preAddForce.localZ or 0)
end

-- A CSP script reset must stop any already armed output.
function script.reset()
  if script.detoxEmergencyDisable then script.detoxEmergencyDisable("PHYSICS_SCRIPT_RESET") end
end
