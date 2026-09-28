local D={}
function D.create()
  return {
    engine={
      inertia=0.22,idleRPM=900,limiterRPM=7600,
      torqueCurve={{rpm=1000,torque=120},{rpm=2000,torque=180},
      {rpm=3000,torque=220},{rpm=4000,torque=250},{rpm=5000,torque=270},
      {rpm=6000,torque=275},{rpm=7000,torque=260},{rpm=7600,torque=220}}
    },
    clutch={capacity=800,engagementRate=8},
    gearbox={ratios={[-1]=-3.20,[0]=0,[1]=3.20,[2]=2.10,[3]=1.55,[4]=1.20,[5]=1.00,[6]=0.82},finalDrive=3.90},
    shaft={stiffness=18,damping=2}
  }
end
function D.getObserverData(self) return self end
return D
