local LoadModel = {}

LoadModel.VERSION = 'E-5'

LoadModel.DEFAULT_REFERENCE_LOAD = 3500.0
LoadModel.DEFAULT_EXPONENT = 0.92

local function safe(value, fallback)
    if type(value) == 'number' then
        return value
    end

    return fallback or 0
end

local function clamp(value, minimum, maximum)
    if value < minimum then
        return minimum
    end

    if value > maximum then
        return maximum
    end

    return value
end

function LoadModel.create(definition)
    definition = definition or {}

    return {
        version = LoadModel.VERSION,

        referenceLoad =
            safe(
                definition.referenceLoad,
                LoadModel.DEFAULT_REFERENCE_LOAD
            ),

        exponent =
            safe(
                definition.exponent,
                LoadModel.DEFAULT_EXPONENT
            )
    }
end

function LoadModel.capacity(
    model,
    load
)
    local reference =
        math.max(
            model.referenceLoad,
            1.0
        )

    local normalized =
        math.max(
            load / reference,
            0
        )

    return math.pow(
        normalized,
        model.exponent
    )
end

function LoadModel.factor(
    model,
    load
)
    local capacity =
        LoadModel.capacity(
            model,
            load
        )

    return clamp(
        capacity,
        0,
        2.0
    )
end

return LoadModel
