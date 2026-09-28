local O={}
function O.create() return {} end
function O.update(state)
  -- AC application output boundary. E-10 keeps this isolated and read-only
  -- until the physical integration gate is passed.
end
function O.getObserverData(state) return {injection="DISABLED", applied=0, boundary="READ_ONLY"} end
return O
