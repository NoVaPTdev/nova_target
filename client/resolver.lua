-- ═══════════════════════════════════════════════════════════════════
-- nova_target — Option Resolver
-- Filters options based on distance, canInteract, job/gang, items
-- ═══════════════════════════════════════════════════════════════════

Resolver = {}

--- Check if the player meets group (job/gang) requirements
---@param groups table|string|nil
---@return boolean
local function checkGroups(groups)
    if not groups then return true end

    -- Try to get player data from nova_core
    local ok, playerData = pcall(function()
        return exports['nova_core']:GetPlayerData()
    end)

    if not ok or not playerData then return true end -- Allow if framework not loaded

    -- String: single job name
    if type(groups) == "string" then
        if playerData.job and playerData.job.name == groups then return true end
        if playerData.gang and playerData.gang.name == groups then return true end
        return false
    end

    -- Table with string values: array of allowed job/gang names
    if type(groups) == "table" then
        -- Check if it's an array (numeric keys)
        if groups[1] then
            for _, name in ipairs(groups) do
                if playerData.job and playerData.job.name == name then return true end
                if playerData.gang and playerData.gang.name == name then return true end
            end
            return false
        end

        -- Dictionary: { ["police"] = 0, ["sheriff"] = 2 } (name = minGrade)
        for name, minGrade in pairs(groups) do
            if playerData.job and playerData.job.name == name then
                local g = playerData.job.grade
                local grade = type(g) == 'table' and (g.level or 0) or (tonumber(g) or 0)
                if grade >= (minGrade or 0) then return true end
            end
            if playerData.gang and playerData.gang.name == name then
                local g = playerData.gang.grade
                local grade = type(g) == 'table' and (g.level or 0) or (tonumber(g) or 0)
                if grade >= (minGrade or 0) then return true end
            end
        end
        return false
    end

    return true
end

--- Check if the player has required items
---@param items table|string|nil
---@param anyItem boolean
---@return boolean
local function checkItems(items, anyItem)
    if not items then return true end

    local ok, hasItem = pcall(function()
        return exports['nova_inventory']:HasItem(items, anyItem)
    end)

    if not ok then return true end -- Allow if inventory not available
    return hasItem
end

--- Filter options list based on all conditions
---@param options table[] raw options from registry
---@param entity number entity handle (0 for zones)
---@param distance number current distance to target
---@param coords vector3 hit coordinates
---@return table[] filtered options ready for NUI
function Resolver.filterOptions(options, entity, distance, coords)
    local filtered = {}

    for _, opt in ipairs(options) do
        local pass = true

        -- Distance check
        if opt.distance and distance > opt.distance then
            pass = false
        end

        -- canInteract callback
        if pass and opt.canInteract then
            local ok, result = pcall(opt.canInteract, entity, distance, coords, opt.name)
            if ok then
                pass = result
            else
                pass = false
            end
        end

        -- Group (job/gang) check
        if pass and opt.groups then
            pass = checkGroups(opt.groups)
        end

        -- Item check
        if pass and opt.items then
            pass = checkItems(opt.items, opt.anyItem)
        end

        if pass then
            filtered[#filtered + 1] = {
                name  = opt.name,
                icon  = opt.icon,
                label = opt.label,
                -- Store callbacks for execution (not sent to NUI)
                _onSelect    = opt.onSelect,
                _event       = opt.event,
                _serverEvent = opt.serverEvent,
                _command     = opt.command,
                _type        = opt.type,
            }
        end
    end

    return filtered
end

--- Execute the selected option's action
---@param option table the filtered option with _onSelect etc.
---@param data table { entity, coords, distance, zone }
function Resolver.executeOption(option, data)
    if not option then return end

    -- Priority: onSelect > command > serverEvent > event
    if option._onSelect then
        local ok, err = pcall(option._onSelect, data)
        if not ok then
            print("^1[nova_target] Error in onSelect callback: " .. tostring(err) .. "^0")
        end
        return
    end

    if option._command then
        ExecuteCommand(option._command)
        return
    end

    if option._serverEvent then
        TriggerServerEvent(option._serverEvent, data)
        return
    end

    if option._event then
        TriggerEvent(option._event, data)
        return
    end

    -- qb-target compat: type + event
    if option._type and option._event then
        if option._type == "server" then
            TriggerServerEvent(option._event, data)
        elseif option._type == "command" then
            ExecuteCommand(option._event)
        else
            TriggerEvent(option._event, data)
        end
    end
end
