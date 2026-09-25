local TireModel = {}

TireModel.VERSION = 'E-5'

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

function TireModel.create(definition)
    definition = definition or {}

    return {
        version = TireModel.VERSION,

        referenceLoad =
            safe(
                definition.referenceLoad,
                3500
            ),

        peakLongitudinal =
            safe(
                definition.peakLongitudinal,
                1.0
            ),

        peakLateral =
            safe(
                definition.peakLateral,
                1.0
            ),

        slipRatioScale =
            safe(
                definition.slipRatioScale,
                8.0
            ),

        slipAngleScale =
            safe(
                definition.slipAngleScale,
                8.0
            ),

        combinedLimit =
            safe(
                definition.combinedLimit,
                1.0
            )
    }
end

local function response(
    slip,
    scale
)
    if scale <= 0 then
        return 0
    end

    return math.tanh(
        slip * scale
    )
end

function TireModel.solve(
    model,
    load,
    slipRatio,
    slipAngle
)
    local loadFactor =
        math.sqrt(
            math.max(
                load /
                math.max(
                    model.referenceLoad,
                    1
                ),
                0
            )
        )

    local fxNormalized =
        response(
            slipRatio,
            model.slipRatioScale
        )

    local fyNormalized =
        response(
            slipAngle,
            model.slipAngleScale
        )

    local fx =
        fxNormalized *
        model.peakLongitudinal *
        loadFactor

    local fy =
        fyNormalized *
        model.peakLateral *
        loadFactor

    local combined =
        math.sqrt(
            fx * fx +
            fy * fy
        )

    local limit =
        math.max(
            model.combinedLimit,
            0.001
        )

    if combined > limit then
        local scale =
            limit / combined

        fx = fx * scale
        fy = fy * scale
    end

    return {
        longitudinal = fx,
        lateral = fy,

        normalizedLongitudinal =
            fxNormalized,

        normalizedLateral =
            fyNormalized,

        combined =
            math.sqrt(
                fx * fx +
                fy * fy
            )
    }
end

return TireModel
