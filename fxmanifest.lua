--@diagnostic disable: undefined-global
fx_version("cerulean")
game("gta5")

name("nova_target")
author("NOVA Framework")
description("NOVA Target — Sistema de Targeting Raycast")
version("2.0.0")

shared_script("config.lua")

client_scripts({
    "client/registry.lua",
    "client/zones.lua",
    "client/raycast.lua",
    "client/resolver.lua",
    "client/main.lua",
    "client/compat.lua",
})

ui_page("html/index.html")

files({
    "html/index.html",
})

-- ═══════════════════════════════════════════════════════════════════
-- Native nova_target exports
-- ═══════════════════════════════════════════════════════════════════
exports({
    -- Global options
    "addGlobalOption",
    "removeGlobalOption",
    "addGlobalVehicle",
    "removeGlobalVehicle",
    "addGlobalPed",
    "removeGlobalPed",
    "addGlobalPlayer",
    "removeGlobalPlayer",
    "addGlobalObject",
    "removeGlobalObject",

    -- Model targeting
    "addModel",
    "removeModel",

    -- Entity targeting (network ID)
    "addEntity",
    "removeEntity",

    -- Local entity targeting (handle)
    "addLocalEntity",
    "removeLocalEntity",

    -- Zone targeting
    "addBoxZone",
    "addSphereZone",
    "addPolyZone",
    "removeZone",
    "zoneExists",

    -- Utility
    "disableTargeting",
    "isActive",

    -- qb-target PascalCase compat exports
    "AddBoxZone",
    "AddCircleZone",
    "AddPolyZone",
    "RemoveZone",
    "AddTargetEntity",
    "RemoveTargetEntity",
    "AddTargetModel",
    "RemoveTargetModel",
    "AddTargetBone",
    "RemoveTargetBone",
    "AddGlobalPed",
    "RemoveGlobalPed",
    "AddGlobalVehicle",
    "RemoveGlobalVehicle",
    "AddGlobalObject",
    "RemoveGlobalObject",
    "AddGlobalPlayer",
    "RemoveGlobalPlayer",
    "AddEntityZone",
    "RemoveEntityZone",
    "AllowTargeting",
    "RaycastCamera",
    "RemoveGlobalTypeOptions",
})

lua54("yes")

-- ═══════════════════════════════════════════════════════════════════
-- Provide compatibility — FiveM redirects calls from these resources
-- to nova_target automatically. ox_target uses the same camelCase
-- names as our native API, qb-target uses PascalCase (registered above).
-- ═══════════════════════════════════════════════════════════════════
provide("ox_target")
provide("qb-target")
