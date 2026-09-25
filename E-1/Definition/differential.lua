local DifferentialDefinition = {}

DifferentialDefinition.VERSION = 'E-6'

DifferentialDefinition.DEFAULT = {
    preload = 20.0,

    powerLock = 0.20,

    coastLock = 0.10,

    rampAnglePower = 45.0,

    rampAngleCoast = 60.0,

    capacity = 1200.0
}

function DifferentialDefinition.create()
    return {
        version =
            DifferentialDefinition.VERSION,

        preload =
            DifferentialDefinition.DEFAULT.preload,

        powerLock =
            DifferentialDefinition.DEFAULT.powerLock,

        coastLock =
            DifferentialDefinition.DEFAULT.coastLock,

        rampAnglePower =
            DifferentialDefinition.DEFAULT.rampAnglePower,

        rampAngleCoast =
            DifferentialDefinition.DEFAULT.rampAngleCoast,

        capacity =
            DifferentialDefinition.DEFAULT.capacity
    }
end

return DifferentialDefinition
