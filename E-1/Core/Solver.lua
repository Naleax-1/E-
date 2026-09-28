-- DETOX E-11.5 compatibility Solver facade
-- Keeps older callers using Core.Solver alive while routing to the E-11 coupled solver.
local Solver = {}
local Coupled = require("Core.coupled_solver")

function Solver.create(model)
  return Coupled.create(model)
end

function Solver.update(self, state, modules)
  if type(self) ~= "table" then error("Solver.update: invalid solver instance") end
  if type(state) ~= "table" then error("Solver.update: state is unavailable") end
  if type(modules) ~= "table" then error("Solver.update: modules are unavailable") end
  return Coupled.update(self, state, modules)
end

return Solver
