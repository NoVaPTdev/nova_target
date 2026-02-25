-- ═══════════════════════════════════════════════════════════════════
-- nova_target — Main Client
-- Hold ALT to scan → options appear → LEFT CLICK to interact
-- ═══════════════════════════════════════════════════════════════════

local isTargeting = false
local isDisabled = false
local hasFocus = false
local hasTarget = false
local currentEntity = 0
local currentEntityType = 0
local currentModelHash = 0
local currentCoords = nil
local currentOptions = {}
local lastSentOptions = nil

local MOUSE_BUTTON = 24  -- LEFT CLICK
local CANCEL_BUTTON = 25 -- RIGHT CLICK

-- ═══════════════════════════════════════════════════════════════════
-- NUI Communication
-- ═══════════════════════════════════════════════════════════════════

local function sendEyeState(visible, targeted)
    SendNUIMessage({
        type = "setEye",
        visible = visible and 1 or 0,
        hasTarget = targeted and 1 or 0,
    })
end

local function sendOptions(options)
    local nuiOptions = {}
    for i, opt in ipairs(options) do
        nuiOptions[i] = {
            index = i,
            icon  = opt.icon,
            label = opt.label,
            name  = opt.name,
        }
    end

    local key = ""
    for _, o in ipairs(nuiOptions) do
        key = key .. o.name .. "|"
    end
    if key == lastSentOptions then return end
    lastSentOptions = key

    SendNUIMessage({
        type = "setOptions",
        options = nuiOptions,
    })
end

local function clearNUI()
    lastSentOptions = nil
    SendNUIMessage({ type = "hide" })
end

-- ═══════════════════════════════════════════════════════════════════
-- Focus Management (ox_target style)
-- ═══════════════════════════════════════════════════════════════════

local function setFocus(value)
    if value == hasFocus then return end
    hasFocus = value

    if value then
        SetCursorLocation(0.5, 0.5)
    end

    SetNuiFocus(value, value)
    SetNuiFocusKeepInput(value)
end

-- ═══════════════════════════════════════════════════════════════════
-- Main Targeting Logic
-- ═══════════════════════════════════════════════════════════════════

local function startTargeting()
    if isDisabled or isTargeting or IsNuiFocused() or IsPauseMenuActive() then return end

    isTargeting = true
    hasTarget = false
    hasFocus = false
    sendEyeState(true, false)

    -- Thread 1: Controls — runs every frame (Wait 0)
    CreateThread(function()
        while isTargeting do
            DisablePlayerFiring(PlayerId(), true)
            DisableControlAction(0, 25, true)   -- INPUT_AIM
            DisableControlAction(0, 140, true)  -- INPUT_MELEE_ATTACK_LIGHT
            DisableControlAction(0, 141, true)  -- INPUT_MELEE_ATTACK_HEAVY
            DisableControlAction(0, 142, true)  -- INPUT_MELEE_ATTACK_ALTERNATE

            if hasFocus then
                DisableControlAction(0, 1, true)  -- INPUT_LOOK_LR
                DisableControlAction(0, 2, true)  -- INPUT_LOOK_UD

                if not hasTarget or IsDisabledControlJustPressed(0, CANCEL_BUTTON) then
                    setFocus(false)
                end
            elseif hasTarget and IsDisabledControlJustPressed(0, MOUSE_BUTTON) then
                setFocus(true)
            end

            Zones.drawDebug(GetEntityCoords(PlayerPedId()))
            Wait(0)
        end
    end)

    -- Thread 2: Scanning logic — runs at 50-100ms intervals
    while isTargeting do
        if IsPauseMenuActive() then
            isTargeting = false
            break
        end

        local playerCoords = GetEntityCoords(PlayerPedId())

        -- 1. Raycast for entities
        local hit, endCoords, entityHit, entityType, modelHash = Raycast.performFromCamera(Config.MaxDistance)

        local allOptions = {}
        local targetEntity = 0
        local targetCoords = endCoords
        local targetDistance = #(playerCoords - endCoords)

        if hit and entityHit ~= 0 then
            targetEntity = entityHit
            local entityOptions = Registry.getOptionsForEntity(entityHit, entityType, modelHash)
            allOptions = Resolver.filterOptions(entityOptions, entityHit, targetDistance, endCoords)
        end

        -- 1b. Proximity fallback when raycast missed
        if #allOptions == 0 then
            local fHit, fCoords, fEntity, fType, fModel = Raycast.proximityFallback(Config.MaxDistance)
            if fHit and fEntity ~= 0 then
                local fDist = #(playerCoords - fCoords)
                local fOptions = Registry.getOptionsForEntity(fEntity, fType, fModel)
                local filtered = Resolver.filterOptions(fOptions, fEntity, fDist, fCoords)
                if #filtered > 0 then
                    targetEntity = fEntity
                    targetCoords = fCoords
                    targetDistance = fDist
                    allOptions = filtered
                end
            end
        end

        -- 2. Zones (always checked)
        local activeZones = Zones.getActiveZones(playerCoords)
        for _, zoneData in ipairs(activeZones) do
            local zoneOptions = Resolver.filterOptions(zoneData.options, 0, zoneData.distance, playerCoords)
            for _, opt in ipairs(zoneOptions) do
                opt._zoneId = zoneData.zone.id
                allOptions[#allOptions + 1] = opt
            end
        end

        -- 3. Update state
        currentEntity = targetEntity
        currentEntityType = entityType or 0
        currentModelHash = modelHash or 0
        currentCoords = targetCoords
        currentOptions = allOptions

        -- 4. Update NUI
        local hadTarget = hasTarget
        hasTarget = #allOptions > 0

        if hasTarget then
            sendEyeState(true, true)
            sendOptions(allOptions)
        else
            if hadTarget then
                sendOptions({})
                if hasFocus then
                    setFocus(false)
                end
            end
            sendEyeState(true, false)
        end

        Wait(hit and 50 or 100)
    end

    -- Cleanup when targeting ends
    setFocus(false)
    clearNUI()
    hasTarget = false
    currentEntity = 0
    currentEntityType = 0
    currentModelHash = 0
    currentCoords = nil
    currentOptions = {}
    lastSentOptions = nil
end

local function stopTargeting()
    isTargeting = false
end

-- ═══════════════════════════════════════════════════════════════════
-- Keybind (hold ALT)
-- ═══════════════════════════════════════════════════════════════════

RegisterCommand('+nova_target', function()
    startTargeting()
end, false)

RegisterCommand('-nova_target', function()
    stopTargeting()
end, false)

RegisterKeyMapping('+nova_target', 'Target / Interact', 'keyboard', Config.Key)

-- ═══════════════════════════════════════════════════════════════════
-- NUI Callbacks
-- ═══════════════════════════════════════════════════════════════════

RegisterNUICallback('selectOption', function(data, cb)
    cb("ok")

    local index = tonumber(data.index)
    if not index or not currentOptions[index] then return end

    local selectedOption = currentOptions[index]

    local callbackData = {
        entity   = currentEntity ~= 0 and currentEntity or nil,
        coords   = currentCoords,
        distance = currentCoords and #(GetEntityCoords(PlayerPedId()) - currentCoords) or 0,
        zone     = selectedOption._zoneId or nil,
        name     = selectedOption.name,
    }

    -- Close cursor first, then stop targeting, then execute
    setFocus(false)
    isTargeting = false

    Wait(0)

    Resolver.executeOption(selectedOption, callbackData)
end)

RegisterNUICallback('closeTarget', function(_, cb)
    cb("ok")
    setFocus(false)
    isTargeting = false
end)

-- ═══════════════════════════════════════════════════════════════════
-- Exports
-- ═══════════════════════════════════════════════════════════════════

exports("addGlobalOption", function(options)
    return Registry.addGlobalOption(options)
end)
exports("removeGlobalOption", function(names)
    return Registry.removeGlobalOption(names)
end)

exports("addGlobalVehicle", function(options)
    return Registry.addGlobalType("vehicle", options)
end)
exports("removeGlobalVehicle", function(names)
    return Registry.removeGlobalType("vehicle", names)
end)
exports("addGlobalPed", function(options)
    return Registry.addGlobalType("ped", options)
end)
exports("removeGlobalPed", function(names)
    return Registry.removeGlobalType("ped", names)
end)
exports("addGlobalPlayer", function(options)
    return Registry.addGlobalType("player", options)
end)
exports("removeGlobalPlayer", function(names)
    return Registry.removeGlobalType("player", names)
end)
exports("addGlobalObject", function(options)
    return Registry.addGlobalType("object", options)
end)
exports("removeGlobalObject", function(names)
    return Registry.removeGlobalType("object", names)
end)

exports("addModel", function(models, options)
    return Registry.addModel(models, options)
end)
exports("removeModel", function(models, names)
    return Registry.removeModel(models, names)
end)

exports("addEntity", function(netIds, options)
    return Registry.addEntity(netIds, options)
end)
exports("removeEntity", function(netIds, names)
    return Registry.removeEntity(netIds, names)
end)

exports("addLocalEntity", function(entities, options)
    return Registry.addLocalEntity(entities, options)
end)
exports("removeLocalEntity", function(entities, names)
    return Registry.removeLocalEntity(entities, names)
end)

exports("addBoxZone", function(params)
    return Registry.addBoxZone(params)
end)
exports("addSphereZone", function(params)
    return Registry.addSphereZone(params)
end)
exports("addPolyZone", function(params)
    return Registry.addPolyZone(params)
end)
exports("removeZone", function(id)
    return Registry.removeZone(id)
end)
exports("zoneExists", function(id)
    return Registry.zoneExists(id)
end)

exports("disableTargeting", function(state)
    isDisabled = state
    if state and isTargeting then
        isTargeting = false
    end
end)
exports("isActive", function()
    return isTargeting
end)

-- ═══════════════════════════════════════════════════════════════════
-- Cleanup
-- ═══════════════════════════════════════════════════════════════════

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        isTargeting = false
        setFocus(false)
        clearNUI()
    end
end)


print("^2[nova_target]^0 Target system loaded successfully.")
