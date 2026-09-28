local M={}
function M.create()
  return {mass=1300,inertia={x=1500,y=1800,z=2500},gravity=9.81}
end
function M.solve(self,body,wheels)
  local force={x=0,y=0,z=-self.mass*self.gravity}
  local moment={x=0,y=0,z=0}
  for _,w in pairs(wheels) do
    local fx=w.force.longitudinal or 0
    local fy=w.force.lateral or 0
    local fz=w.force.vertical or 0
    force.x=force.x+fx; force.y=force.y+fy; force.z=force.z+fz
    local r=w.position
    moment.x=moment.x+r.y*fz-r.z*fy
    moment.y=moment.y+r.z*fx-r.x*fz
    moment.z=moment.z+r.x*fy-r.y*fx
  end
  return force,moment
end
function M.getObserverData(self) return {mass=self.mass, gravity=self.gravity, api=true} end
return M
