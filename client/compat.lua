-- ═══════════════════════════════════════════════════════════════════
-- nova_target — Compatibility Layer
-- Uses FiveM's provide() to replace ox_target and qb-target.
-- Scripts calling exports['ox_target']:addBoxZone(...) will be
-- redirected to exports['nova_target']:addBoxZone(...) automatically.
-- For qb-target we register the PascalCase export names it uses.
-- ═══════════════════════════════════════════════════════════════════

if not Config.EnableCompat then return end

-- Store zone name-to-id mapping for qb-target style zone removal by name
local zoneNameMap = {}

-- ═══════════════════════════════════════════════════════════════════
-- qb-target Compatibility Exports (PascalCase names)
-- ox_target uses the same camelCase names as our native API,
-- so provide("ox_target") in fxmanifest handles it automatically.
-- ═══════════════════════════════════════════════════════════════════

--- Convert qb-target option format to nova_target format
---@param params table qb-target parameters
---@return table[] nova_target options
local function wrapQBOptions(params)
    if not params or not params.options then
        if params and params.label then
            return { params }
        end
        return {}
    end

    local result = {}
    for _, opt in ipairs(params.options) do
        result[#result + 1] = {
            name        = opt.label or ("qb_opt_" .. tostring(#result + 1)),
            icon        = opt.icon or "fas fa-eye",
            label       = opt.label or "Interact",
            distance    = params.distance or opt.distance or Config.MaxDistance,
            onSelect    = opt.action or nil,
            canInteract = opt.canInteract or nil,
            groups      = opt.job or opt.gang or nil,
            items       = opt.items or nil,
            event       = opt.event or nil,
            type        = opt.type or nil, -- "client" | "server" | "command"
            num         = opt.num or nil,
        }
    end
    return result
end

-- ── Zones ──

exports("AddBoxZone", function(name, center, width, length, options, targetoptions)
    local heading = options and options.heading or 0.0
    local minZ = options and options.minZ or (center.z - 1.0)
    local maxZ = options and options.maxZ or (center.z + 3.0)
    local height = maxZ - minZ

    local opts = wrapQBOptions(targetoptions)
    local id = Registry.addBoxZone({
        name     = name,
        coords   = vector3(center.x, center.y, minZ + height / 2),
        size     = vector3(width, length, height),
        rotation = heading,
        options  = opts,
    })
    zoneNameMap[name] = id
    return id
end)

exports("AddCircleZone", function(name, center, radius, options, targetoptions)
    local opts = wrapQBOptions(targetoptions)
    local id = Registry.addSphereZone({
        name    = name,
        coords  = center,
        radius  = radius,
        options = opts,
    })
    zoneNameMap[name] = id
    return id
end)

exports("AddPolyZone", function(name, points, options, targetoptions)
    local minZ = options and options.minZ or 0
    local maxZ = options and options.maxZ or 100
    local opts = wrapQBOptions(targetoptions)

    local points3 = {}
    for _, p in ipairs(points) do
        if p.z then
            points3[#points3 + 1] = p
        else
            points3[#points3 + 1] = vector3(p.x, p.y, (minZ + maxZ) / 2)
        end
    end

    local id = Registry.addPolyZone({
        name      = name,
        points    = points3,
        thickness = maxZ - minZ,
        options   = opts,
    })
    zoneNameMap[name] = id
    return id
end)

exports("RemoveZone", function(name)
    local id = zoneNameMap[name]
    if id then
        Registry.removeZone(id)
        zoneNameMap[name] = nil
        return true
    end
    return Registry.removeZone(name)
end)

-- ── Entity targeting ──

exports("AddTargetEntity", function(entity, params)
    local entities = type(entity) == "table" and entity or { entity }
    local opts = wrapQBOptions(params)
    for _, ent in ipairs(entities) do
        Registry.addLocalEntity(ent, opts)
    end
end)

exports("RemoveTargetEntity", function(entity, labels)
    local entities = type(entity) == "table" and entity or { entity }
    for _, ent in ipairs(entities) do
        Registry.removeLocalEntity(ent, labels)
    end
end)

-- ── Model targeting ──

exports("AddTargetModel", function(models, params)
    local opts = wrapQBOptions(params)
    Registry.addModel(models, opts)
end)

exports("RemoveTargetModel", function(models, labels)
    Registry.removeModel(models, labels)
end)

-- ── Bone targeting (approximated as global vehicle) ──

exports("AddTargetBone", function(bones, params)
    local opts = wrapQBOptions(params)
    for _, opt in ipairs(opts) do
        opt.bones = bones
    end
    Registry.addGlobalType("vehicle", opts)
end)

exports("RemoveTargetBone", function(bones)
    -- Simplified: would need bone-tagged removal
end)

-- ── Global types ──

exports("AddGlobalPed", function(params)
    return Registry.addGlobalType("ped", wrapQBOptions(params))
end)
exports("RemoveGlobalPed", function(labels)
    return Registry.removeGlobalType("ped", labels)
end)

exports("AddGlobalVehicle", function(params)
    return Registry.addGlobalType("vehicle", wrapQBOptions(params))
end)
exports("RemoveGlobalVehicle", function(labels)
    return Registry.removeGlobalType("vehicle", labels)
end)

exports("AddGlobalObject", function(params)
    return Registry.addGlobalType("object", wrapQBOptions(params))
end)
exports("RemoveGlobalObject", function(labels)
    return Registry.removeGlobalType("object", labels)
end)

exports("AddGlobalPlayer", function(params)
    return Registry.addGlobalType("player", wrapQBOptions(params))
end)
exports("RemoveGlobalPlayer", function(labels)
    return Registry.removeGlobalType("player", labels)
end)

-- ── Entity zone ──

exports("AddEntityZone", function(name, entity, options, targetoptions)
    local opts = wrapQBOptions(targetoptions)
    Registry.addLocalEntity(entity, opts)
    zoneNameMap[name] = entity
end)

exports("RemoveEntityZone", function(name)
    local entity = zoneNameMap[name]
    if entity then
        Registry.removeLocalEntity(entity)
        zoneNameMap[name] = nil
    end
end)

-- ── Utility ──

exports("AllowTargeting", function(allow)
    exports['nova_target']:disableTargeting(not allow)
end)

exports("RaycastCamera", function(flag, playerCoords)
    return Raycast.performFromCamera(Config.MaxDistance)
end)

exports("RemoveGlobalTypeOptions", function(entityType, labels)
    Registry.removeGlobalType(entityType, labels)
end)

print("^2[nova_target]^0 Compatibility layer loaded (ox_target + qb-target)")
