"""DETOX smoke/regression tests using the system Lua 5.4 shared library.

Run from the repository root: python3 E-1/tests/test_runtime.py
AC/CSP itself is not available here; these tests only exercise a mock car API.
"""
import ctypes
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
LIB = ctypes.CDLL("liblua5.4.so.0")
LIB.luaL_newstate.restype = ctypes.c_void_p
LIB.luaL_openlibs.argtypes = [ctypes.c_void_p]
LIB.luaL_loadstring.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
LIB.luaL_loadstring.restype = ctypes.c_int
LIB.lua_pcallk.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int,
                           ctypes.c_longlong, ctypes.c_void_p]
LIB.lua_pcallk.restype = ctypes.c_int
LIB.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_void_p]
LIB.lua_tolstring.restype = ctypes.c_char_p
LIB.lua_close.argtypes = [ctypes.c_void_p]


def execute(source):
    state = LIB.luaL_newstate()
    assert state, "Cannot create Lua state"
    try:
        LIB.luaL_openlibs(state)
        result = LIB.luaL_loadstring(state, source.encode())
        if result == 0:
            result = LIB.lua_pcallk(state, 0, 0, 0, 0, None)
        if result:
            error = LIB.lua_tolstring(state, -1, None)
            raise AssertionError(error.decode() if error else "Lua error")
    finally:
        LIB.lua_close(state)


if __name__ == "__main__":
    import os
    os.chdir(ROOT)
    execute(r'''
package.path="./E-1/?.lua;"..package.path
script={}
local lines={}
ui={text=function(s) lines[#lines+1]=s end, separator=function() end}
local car={speedKmh=100,rpm=3500,gear=3,gas=0.4,brake=0,
  steer=0,clutch=1,handbrake=0,velocity={x=0,y=0,z=0}}
ac={getCar=function() return car end}
dofile("E-1/DETOX.lua")
local State=require("Core.state")
local Observer=require("Observer.observer")
local captured
local originalCommit=State.commit
State.commit=function(s) originalCommit(s); captured=s end
script.update(0.01)
assert(captured and captured.frame==1)
assert(captured.current.vehicle.time==0.01, "first tick dt")
assert(captured.current.vehicle.valid)
assert(captured.current.wheels.FL.position.x~=0, "vehicle definition lost")
assert(captured.current.diagnostics.errors==0,captured.current.diagnostics.lastError)
assert(captured.current.coupled.iterations>0)
assert(captured.current.body.valid)
assert(captured.current.vehicle.input.speedKmh==100)
local obs=Observer.getState()
for group,entries in pairs(obs.snapshots) do
  local count=0
  for name,entry in pairs(entries) do
    assert(entry.ok,group.."."..name..": "..tostring(entry.data))
    count=count+1
  end
  assert(count>0,"missing observer group "..group)
end
assert(obs.lastError=="")
script.windowMain()
local output=table.concat(lines,"\n")
assert(output:find("DETOX.State.3",1,true))
assert(output:find("AC Speed 100.00 km/h",1,true))
assert(output:find("PhysicsOutput : OK",1,true))
assert(not output:find("OBSERVER ERROR",1,true))
lines={}
script.update(0.02)
assert(captured.frame==2 and math.abs(captured.current.vehicle.time-0.03)<1e-10)
assert(captured.current.diagnostics.errors==0,captured.current.diagnostics.lastError)
assert(captured.current.body.force.x~=0,"tire force not mapped to body")
-- Loss of car API must be visible, without crashing the observer or hiding its contracts.
ac.getCar=function() return nil end
script.update(0.01)
assert(captured.current.vehicle.valid==false)
assert(require("Core.input").getObserverData({available=false}).available==false)
script.windowMain()
assert(table.concat(lines,"\n"):find("AC Vehicle   : WAIT",1,true))
-- Reconnect on the following frame.
ac.getCar=function() return car end
script.update(0.01)
assert(captured.current.vehicle.valid==true)
assert(Observer.getState().lastError=="")
-- Missing/invalid observer contracts are failures, not false OKs.
local fake=require("Observer.observer")
fake.update(0,captured.current,nil,{core={Broken={api={getObserverData=function() end}}}})
assert(fake.getState().snapshots.core.Broken.ok==false)
assert(fake.getState().lastError:find("Broken",1,true))
''')
    print("DETOX observer/runtime tests passed")
