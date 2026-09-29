-- Optional car data/script.lua entry point. NOT loaded by the DETOX Lua app.
-- Install the DETOX.lua and Core/ Engine/ Model/ Definition/ Observer/
-- Safety/ Send/ Verification/ folders alongside this file in a car's
-- unpacked data directory. Requires CSP extended physics and on-car testing.
-- This does not enable forces: it only allows explicit TEST arming later.
DETOX_PHYSICS_CONTEXT = true
require('DETOX')

-- A CSP script reset must stop any already armed output.
function script.reset()
  if script.detoxEmergencyDisable then script.detoxEmergencyDisable() end
end
