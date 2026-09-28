local Scheduler={}
function Scheduler.create() return {tick=0,dt=1/333} end
function Scheduler:update(state,dt)
  self.tick=self.tick+1
  self.dt=dt or self.dt
end
function Scheduler.getObserverData(self)
  return {tick=self.tick or 0, dt=self.dt or 0}
end
return Scheduler
