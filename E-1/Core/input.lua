local Input = {}

Input.VERSION = 'E-3'

local WHEELS = {
    'FL',
    'FR',
    'RL',
    'RR'
}

local function safeNumber(value, fallback)
    if type(value) == 'number' then
        return value
    end

    return fallback or 0
end

local function safeBool(value, fallback)
    if type(value) == 'boolean' then
        return value
    end

    return fallback or false
end

local function vec3(x, y, z)
    return {
        x = safeNumber(x),
        y = safeNumber(y),
        z = safeNumber(z)
    }
end

local function readCar()
    if not ac or not ac.getCar then
        return nil
    end

    local ok, car = pcall(ac.getCar)

    if not ok then
        return nil
    end

    return car
end

local function readWheel(car, index)
    local result = {
        valid = false,
        index = index,

        rotation = 0,
        omega = 0,

        speed = 0,

        load = 0,

        suspensionTravel = 0,
        suspensionVelocity = 0,

        contact = false
    }

    if not car then
        return result
    end

    /*
     * AC API差異をEngineへ漏らさないため、
     * ここで取得できる値だけをSnapshotへ変換する。
     *
     * 車両APIの詳細取得は後続Eフェーズで拡張する。
     */

    local wheelSpeed

    if car.wheelAngularSpeed then
        wheelSpeed = car.wheelAngularSpeed[index]
    end

    if type(wheelSpeed) == 'number' then
        result.omega = wheelSpeed
        result.valid = true
    end

    return result
end

local function readVehicle(car)
    local vehicle = {
        valid = false,

        speed = 0,
        rpm = 0,

        gear = 0,

        steer = 0,
        gas = 0,
        brake = 0,
        clutch = 0,
        handbrake = 0,

        velocity = vec3(),
        acceleration = vec3(),

        angularVelocity = vec3(),

        position = vec3(),

        heading = 0
    }

    if not car then
        return vehicle
    end

    vehicle.speed =
        safeNumber(car.speedKmh, 0)

    vehicle.rpm =
        safeNumber(car.rpm, 0)

    vehicle.gear =
        safeNumber(car.gear, 0)

    vehicle.steer =
        safeNumber(car.steer, 0)

    vehicle.gas =
        safeNumber(car.gas, 0)

    vehicle.brake =
        safeNumber(car.brake, 0)

    vehicle.clutch =
        safeNumber(car.clutch, 0)

    vehicle.handbrake =
        safeNumber(car.handbrake, 0)

    vehicle.valid = true

    return vehicle
end

function Input.create()
    return {
        version = Input.VERSION,

        valid = false,

        frame = 0,
        time = 0,
        dt = 0,

        vehicle = {
            valid = false
        },

        wheels = {},

        diagnostics = {
            readErrors = 0,
            missingValues = 0
        }
    }
end

function Input.reset(input)
    local fresh = Input.create()

    for key, value in pairs(fresh) do
        input[key] = value
    end
end

function Input.read(input, dt)
    input.frame = input.frame + 1
    input.dt = dt or 0
    input.time = input.time + input.dt

    input.diagnostics.readErrors = 0
    input.diagnostics.missingValues = 0

    local car = readCar()

    if not car then
        input.valid = false
        input.vehicle.valid = false

        input.diagnostics.readErrors =
            input.diagnostics.readErrors + 1

        return false
    end

    input.vehicle = readVehicle(car)

    input.wheels = {}

    for index, name in ipairs(WHEELS) do
        input.wheels[name] =
            readWheel(car, index)
    end

    input.valid =
        input.vehicle.valid

    return input.valid
end

function Input.getWheelNames()
    return WHEELS
end

return Input
