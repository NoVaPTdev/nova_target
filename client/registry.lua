-- ═══════════════════════════════════════════════════════════════════
-- nova_target — Target Registry
-- Central data store for all registered target options
-- ═══════════════════════════════════════════════════════════════════

Registry = {
    -- Global options by entity type
    globals = {
        ped     = {},  -- options that apply to ALL peds
        vehicle = {},  -- options that apply to ALL vehicles
        object  = {},  -- options that apply to ALL objects
        player  = {},  -- options that apply to ALL players (subset of peds)
        any     = {},  -- options that apply to ANY entity (global option)
    },

    -- Options by model hash
    models = {},  -- [modelHash] = { options... }

    -- Options by network entity ID
    entities = {},  -- [netId] = { options... }

    -- Options by local entity handle
    localEntities = {},  -- [entityHandle] = { options... }

    -- Zone-based targets
    zones = {},  -- [zoneId] = { zone data + options }

    -- Auto-increment zone IDs
    _nextZoneId = 1,
}

-- ═══════════════════════════════════════════════════════════════════
-- Utility: normalize options table
-- ═══════════════════════════════════════════════════════════════════

--- Normalize a single option to ensure consistent structure
---@param opt table
---@return table
local function normalizeOption(opt)
    return {
        name        = opt.name or opt.label or ("opt_" .. tostring(math.random(100000))),
        icon        = opt.icon or "fas fa-eye",
        label       = opt.label or "Interact",
        distance    = opt.distance or Config.MaxDistance,
        onSelect    = opt.onSelect or opt.action or nil,
        canInteract = opt.canInteract or nil,
        groups      = opt.groups or opt.job or nil,
        items       = opt.items or nil,
        anyItem     = opt.anyItem or false,
        event       = opt.event or nil,
        serverEvent = opt.serverEvent or nil,
        command     = opt.command or nil,
        -- qb-target compat
        type        = opt.type or nil,       -- "client" | "server" | "command"
        num         = opt.num or nil,
    }
end

--- Normalize an options table (can be a single option or array of options)
---@param options table
---@return table[] array of normalized options
local function normalizeOptions(options)
    if not options then return {} end

    -- If it's a single option (has 'label' key), wrap in array
    if options.label or options.name then
        return { normalizeOption(options) }
    end

    -- It's an array of options
    local result = {}
    for _, opt in ipairs(options) do
        result[#result + 1] = normalizeOption(opt)
    end
    return result
end

--- Insert options into a list, replacing any existing option with the same name
---@param list table target list
---@param opts table[] options to insert
local function insertOrReplace(list, opts)
    for _, opt in ipairs(opts) do
        local replaced = false
        for i = 1, #list do
            if list[i].name == opt.name then
                list[i] = opt
                replaced = true
                break
            end
        end
        if not replaced then
            list[#list + 1] = opt
        end
    end
end

-- ═══════════════════════════════════════════════════════════════════
-- Global Options
-- ═══════════════════════════════════════════════════════════════════

--- Add options that apply to all entities of any type
---@param options table|table[]
function Registry.addGlobalOption(options)
    local opts = normalizeOptions(options)
    insertOrReplace(Registry.globals.any, opts)
    return opts
end

--- Remove global options by name(s)
---@param names string|string[]
function Registry.removeGlobalOption(names)
    if type(names) == "string" then names = { names } end
    for _, name in ipairs(names) do
        for i = #Registry.globals.any, 1, -1 do
            if Registry.globals.any[i].name == name then
                table.remove(Registry.globals.any, i)
            end
        end
    end
end

--- Add global options for a specific entity type
---@param entityType string "ped"|"vehicle"|"object"|"player"
---@param options table|table[]
function Registry.addGlobalType(entityType, options)
    local opts = normalizeOptions(options)
    local list = Registry.globals[entityType]
    if not list then return end
    insertOrReplace(list, opts)
    return opts
end

--- Remove global options for a specific entity type by name(s)
---@param entityType string
---@param names string|string[]
function Registry.removeGlobalType(entityType, names)
    if type(names) == "string" then names = { names } end
    local list = Registry.globals[entityType]
    if not list then return end
    for _, name in ipairs(names) do
        for i = #list, 1, -1 do
            if list[i].name == name then
                table.remove(list, i)
            end
        end
    end
end

-- ═══════════════════════════════════════════════════════════════════
-- Model Options
-- ═══════════════════════════════════════════════════════════════════

--- Add options for specific model(s)
---@param models number|string|table  Model hash(es) or name(s)
---@param options table|table[]
function Registry.addModel(models, options)
    if type(models) ~= "table" then models = { models } end
    local opts = normalizeOptions(options)

    for _, model in ipairs(models) do
        local hash = type(model) == "string" and joaat(model) or model
        if not Registry.models[hash] then
            Registry.models[hash] = {}
        end
        insertOrReplace(Registry.models[hash], opts)
    end
    return opts
end

--- Remove options for specific model(s) by name(s)
---@param models number|string|table
---@param names string|string[]
function Registry.removeModel(models, names)
    if type(models) ~= "table" then models = { models } end
    if type(names) == "string" then names = { names } end

    for _, model in ipairs(models) do
        local hash = type(model) == "string" and joaat(model) or model
        local list = Registry.models[hash]
        if list then
            if names then
                for _, name in ipairs(names) do
                    for i = #list, 1, -1 do
                        if list[i].name == name then
                            table.remove(list, i)
                        end
                    end
                end
                if #list == 0 then
                    Registry.models[hash] = nil
                end
            else
                Registry.models[hash] = nil
            end
        end
    end
end

-- ═══════════════════════════════════════════════════════════════════
-- Entity Options (Network ID)
-- ═══════════════════════════════════════════════════════════════════

--- Add options for specific network entity ID(s)
---@param netIds number|table
---@param options table|table[]
function Registry.addEntity(netIds, options)
    if type(netIds) ~= "table" then netIds = { netIds } end
    local opts = normalizeOptions(options)

    for _, netId in ipairs(netIds) do
        if not Registry.entities[netId] then
            Registry.entities[netId] = {}
        end
        insertOrReplace(Registry.entities[netId], opts)
    end
    return opts
end

--- Remove options for specific network entity ID(s)
---@param netIds number|table
---@param names string|string[]|nil
function Registry.removeEntity(netIds, names)
    if type(netIds) ~= "table" then netIds = { netIds } end

    for _, netId in ipairs(netIds) do
        if names then
            if type(names) == "string" then names = { names } end
            local list = Registry.entities[netId]
            if list then
                for _, name in ipairs(names) do
                    for i = #list, 1, -1 do
                        if list[i].name == name then
                            table.remove(list, i)
                        end
                    end
                end
                if #list == 0 then
                    Registry.entities[netId] = nil
                end
            end
        else
            Registry.entities[netId] = nil
        end
    end
end

-- ═══════════════════════════════════════════════════════════════════
-- Local Entity Options (Handle)
-- ═══════════════════════════════════════════════════════════════════

--- Add options for local entity handle(s)
---@param entities number|table
---@param options table|table[]
function Registry.addLocalEntity(entities, options)
    if type(entities) ~= "table" then entities = { entities } end
    local opts = normalizeOptions(options)

    for _, entity in ipairs(entities) do
        if not Registry.localEntities[entity] then
            Registry.localEntities[entity] = {}
        end
        insertOrReplace(Registry.localEntities[entity], opts)
    end
    return opts
end

--- Remove options for local entity handle(s)
---@param entities number|table
---@param names string|string[]|nil
function Registry.removeLocalEntity(entities, names)
    if type(entities) ~= "table" then entities = { entities } end

    for _, entity in ipairs(entities) do
        if names then
            if type(names) == "string" then names = { names } end
            local list = Registry.localEntities[entity]
            if list then
                for _, name in ipairs(names) do
                    for i = #list, 1, -1 do
                        if list[i].name == name then
                            table.remove(list, i)
                        end
                    end
                end
                if #list == 0 then
                    Registry.localEntities[entity] = nil
                end
            end
        else
            Registry.localEntities[entity] = nil
        end
    end
end

-- ═══════════════════════════════════════════════════════════════════
-- Zone Registry (data stored here, logic in zones.lua)
-- ═══════════════════════════════════════════════════════════════════

--- Register a box zone
---@param params table { coords, size, rotation, name, options, ... }
---@return number zoneId
function Registry.addBoxZone(params)
    local id = Registry._nextZoneId
    Registry._nextZoneId = id + 1

    local opts = normalizeOptions(params.options or params)

    Registry.zones[id] = {
        id       = id,
        type     = "box",
        name     = params.name or ("box_" .. id),
        coords   = params.coords,
        size     = params.size or vector3(2.0, 2.0, 2.0),
        rotation = params.rotation or 0.0,
        options  = opts,
        drawSprite = params.drawSprite ~= false,
    }

    return id
end

--- Register a sphere zone
---@param params table { coords, radius, name, options, ... }
---@return number zoneId
function Registry.addSphereZone(params)
    local id = Registry._nextZoneId
    Registry._nextZoneId = id + 1

    local opts = normalizeOptions(params.options or params)

    Registry.zones[id] = {
        id       = id,
        type     = "sphere",
        name     = params.name or ("sphere_" .. id),
        coords   = params.coords,
        radius   = params.radius or 2.0,
        options  = opts,
        drawSprite = params.drawSprite ~= false,
    }

    return id
end

--- Register a poly zone
---@param params table { points, thickness, name, options, ... }
---@return number zoneId
function Registry.addPolyZone(params)
    local id = Registry._nextZoneId
    Registry._nextZoneId = id + 1

    local opts = normalizeOptions(params.options or params)

    Registry.zones[id] = {
        id        = id,
        type      = "poly",
        name      = params.name or ("poly_" .. id),
        points    = params.points,
        thickness = params.thickness or 4.0,
        options   = opts,
        drawSprite = params.drawSprite ~= false,
    }

    return id
end

--- Check if a zone exists
---@param id number
---@return boolean
function Registry.zoneExists(id)
    return Registry.zones[id] ~= nil
end

--- Remove a zone by ID
---@param id number|string
function Registry.removeZone(id)
    -- Support removal by ID (number) or by name (string)
    if type(id) == "string" then
        for zoneId, zone in pairs(Registry.zones) do
            if zone.name == id then
                Registry.zones[zoneId] = nil
                return true
            end
        end
        return false
    end
    if Registry.zones[id] then
        Registry.zones[id] = nil
        return true
    end
    return false
end

--- Get all options for a specific entity (combining globals + model + entity + localEntity)
---@param entity number entity handle
---@param entityType number 1=ped, 2=vehicle, 3=object
---@param modelHash number
---@return table[] combined options
function Registry.getOptionsForEntity(entity, entityType, modelHash)
    local options = {}

    -- 1. Global "any" options
    for _, opt in ipairs(Registry.globals.any) do
        options[#options + 1] = opt
    end

    -- 2. Global type options
    local typeKey = entityType == 1 and "ped" or entityType == 2 and "vehicle" or "object"
    for _, opt in ipairs(Registry.globals[typeKey] or {}) do
        options[#options + 1] = opt
    end

    -- 3. Player-specific globals (if ped is a player)
    if entityType == 1 and IsPedAPlayer(entity) then
        for _, opt in ipairs(Registry.globals.player) do
            options[#options + 1] = opt
        end
    end

    -- 4. Model options
    if modelHash and Registry.models[modelHash] then
        for _, opt in ipairs(Registry.models[modelHash]) do
            options[#options + 1] = opt
        end
    end

    -- 5. Network entity options
    if NetworkGetEntityIsNetworked(entity) then
        local netId = NetworkGetNetworkIdFromEntity(entity)
        if netId and Registry.entities[netId] then
            for _, opt in ipairs(Registry.entities[netId]) do
                options[#options + 1] = opt
            end
        end
    end

    -- 6. Local entity options
    if Registry.localEntities[entity] then
        for _, opt in ipairs(Registry.localEntities[entity]) do
            options[#options + 1] = opt
        end
    end

    return options
end
