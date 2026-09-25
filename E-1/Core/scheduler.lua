local Scheduler = {}

Scheduler.VERSION = 'E-3'

Scheduler.MAX_COUPLED_ITERATIONS = 3

Scheduler.PHASES = {
    'Input',
    'Snapshot',
    'Kinematics',
    'Slip',
    'ThermalCarcass',
    'Tire',
    'Powertrain',
    'Differential',
    'Suspension',
    'Wheel',
    'CoupledIteration',
    'Body',
    'Validation',
    'Commit',
    'Output'
}

local function safeCall(name, fn, runtime)
    if type(fn) ~= 'function' then
        return true
    end

    local ok, result =
        pcall(fn, runtime)

    if not ok then
        return false,
            name .. ': ' .. tostring(result)
    end

    if result == false then
        return false,
            name .. ': phase returned false'
    end

    return true
end

function Scheduler.create()
    return {
        version = Scheduler.VERSION,

        tick = 0,
        dt = 0,

        running = false,

        phaseIndex = 0,
        currentPhase = 'Idle',
        completedPhase = 'None',

        failedPhase = nil,
        error = nil,

        coupledIterations = 0,

        statistics = {
            totalTicks = 0,
            failedTicks = 0,
            lastTickTime = 0
        }
    }
end

function Scheduler.beginTick(runtime, dt)
    local scheduler =
        runtime.scheduler

    scheduler.tick =
        scheduler.tick + 1

    scheduler.dt = dt or 0

    scheduler.phaseIndex = 0
    scheduler.currentPhase = 'Begin'
    scheduler.completedPhase = 'None'

    scheduler.failedPhase = nil
    scheduler.error = nil

    scheduler.coupledIterations = 0

    scheduler.running = true

    scheduler.statistics.totalTicks =
        scheduler.statistics.totalTicks + 1
end

function Scheduler.runPhase(
    runtime,
    name,
    fn
)
    local scheduler =
        runtime.scheduler

    scheduler.currentPhase = name

    scheduler.phaseIndex =
        scheduler.phaseIndex + 1

    local ok, err =
        safeCall(name, fn, runtime)

    if not ok then
        scheduler.error = err
        scheduler.failedPhase = name

        return false
    end

    scheduler.completedPhase = name

    return true
end

function Scheduler.runCoupledIteration(
    runtime,
    fn
)
    local scheduler =
        runtime.scheduler

    if type(fn) ~= 'function' then
        return true
    end

    for iteration = 1,
        Scheduler.MAX_COUPLED_ITERATIONS do

        scheduler.coupledIterations =
            iteration

        local ok, err =
            pcall(
                fn,
                runtime,
                iteration
            )

        if not ok then
            scheduler.error =
                'CoupledIteration: ' ..
                tostring(err)

            scheduler.failedPhase =
                'CoupledIteration'

            return false
        end
    end

    return true
end

function Scheduler.execute(
    runtime,
    phases
)
    for _, phase in
        ipairs(Scheduler.PHASES) do

        local fn =
            phases and phases[phase]

        if not Scheduler.runPhase(
            runtime,
            phase,
            fn
        ) then

            runtime.scheduler.running =
                false

            runtime.scheduler.statistics.failedTicks =
                runtime.scheduler.statistics.failedTicks + 1

            return false
        end
    end

    runtime.scheduler.running =
        false

    return true
end

function Scheduler.endTick(runtime)
    local scheduler =
        runtime.scheduler

    scheduler.running = false
    scheduler.currentPhase = 'Idle'

    scheduler.statistics.lastTickTime =
        scheduler.dt

    return scheduler.error == nil
end

function Scheduler.getStatus(runtime)
    local scheduler =
        runtime.scheduler

    return {
        version = scheduler.version,

        tick = scheduler.tick,

        running = scheduler.running,

        phaseIndex =
            scheduler.phaseIndex,

        currentPhase =
            scheduler.currentPhase,

        completedPhase =
            scheduler.completedPhase,

        failedPhase =
            scheduler.failedPhase,

        error =
            scheduler.error,

        coupledIterations =
            scheduler.coupledIterations,

        totalTicks =
            scheduler.statistics.totalTicks,

        failedTicks =
            scheduler.statistics.failedTicks
    }
end

return Scheduler
