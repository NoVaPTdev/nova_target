-- ═══════════════════════════════════════════════════════════════════
-- nova_target — Raycast Engine
-- Camera-based line trace for entity detection
-- ═══════════════════════════════════════════════════════════════════

Raycast = {}

--- Convert rotation (degrees) to a forward direction vector
---@param rot vector3
---@return vector3
local function RotToDir(rot)
    local radX = math.rad(rot.x)
    local radZ = math.rad(rot.z)
    local absX = math.abs(math.cos(radX))
    return vector3(
        -math.sin(radZ) * absX,
        math.cos(radZ) * absX,
        math.sin(radX)
    )
end

--- Perform a single raycast from the gameplay camera
---@param maxDistance number
---@return boolean hit
---@return vector3 endCoords
---@return number entityHit
---@return number entityType  (0=none, 1=ped, 2=vehicle, 3=object)
---@return number modelHash
function Raycast.performFromCamera(maxDistance)
    maxDistance = maxDistance or Config.MaxDistance

    local camCoord = GetGameplayCamCoord()
    local camRot = GetGameplayCamRot(2)
    local forward = RotToDir(camRot)
    local endCoord = camCoord + (forward * maxDistance)

    local playerPed = PlayerPedId()

    -- flags: 30 = peds(1) + vehicles(2) + objects(4) + foliage(8) + everything(16)
    local ray = StartShapeTestRay(
        camCoord.x, camCoord.y, camCoord.z,
        endCoord.x, endCoord.y, endCoord.z,
        30,
        playerPed,
        7
    )

    local status, hit, endCoords, surfaceNormal, entityHit = GetShapeTestResult(ray)

    if hit == 1 and entityHit ~= 0 then
        local entityType = GetEntityType(entityHit)
        local modelHash = GetEntityModel(entityHit)
        return true, endCoords, entityHit, entityType, modelHash
    end

    return false, endCoords or endCoord, 0, 0, 0
end

--- Get the entity the player is looking at (quick single-frame check)
---@param maxDistance number|nil
---@return number entityHit
---@return vector3 endCoords
---@return number entityType
---@return number modelHash
function Raycast.getEntityLookingAt(maxDistance)
    local hit, endCoords, entityHit, entityType, modelHash = Raycast.performFromCamera(maxDistance)
    return entityHit, endCoords, entityType, modelHash
end

--- Get distance from player to a world coordinate
---@param coords vector3
---@return number
function Raycast.getPlayerDistance(coords)
    local playerCoords = GetEntityCoords(PlayerPedId())
    return #(playerCoords - coords)
end

--- Fallback: find the closest entity the camera is roughly pointing at
--- Used when the thin raycast misses vehicle/ped geometry
---@param maxDistance number
---@param angleTolerance number  max angle (degrees) between camera forward and entity direction
---@return boolean hit
---@return vector3 endCoords
---@return number entityHit
---@return number entityType
---@return number modelHash
function Raycast.proximityFallback(maxDistance, angleTolerance)
    maxDistance = maxDistance or Config.MaxDistance
    angleTolerance = angleTolerance or 25.0

    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local camCoord = GetGameplayCamCoord()
    local camRot = GetGameplayCamRot(2)
    local radX = math.rad(camRot.x)
    local radZ = math.rad(camRot.z)
    local absX = math.abs(math.cos(radX))
    local forward = vector3(
        -math.sin(radZ) * absX,
        math.cos(radZ) * absX,
        math.sin(radX)
    )

    local bestEntity = 0
    local bestDist = maxDistance + 1.0
    local bestType = 0
    local bestCoords = playerCoords

    local pools = {
        { name = 'CVehicle', etype = 2 },
        { name = 'CPed',     etype = 1 },
        { name = 'CObject',  etype = 3 },
    }

    for _, pool in ipairs(pools) do
        local entities = GetGamePool(pool.name)
        if entities then
            for _, entity in ipairs(entities) do
                if entity ~= playerPed and DoesEntityExist(entity) then
                    local eCoords = GetEntityCoords(entity)
                    local dist = #(playerCoords - eCoords)
                    if dist <= maxDistance and dist < bestDist then
                        local toEntity = eCoords - camCoord
                        local lenTE = #toEntity
                        if lenTE > 0.01 then
                            local dot = (forward.x * toEntity.x + forward.y * toEntity.y + forward.z * toEntity.z) / lenTE
                            local angle = math.deg(math.acos(math.min(1.0, math.max(-1.0, dot))))
                            if angle <= angleTolerance then
                                bestEntity = entity
                                bestDist = dist
                                bestType = pool.etype
                                bestCoords = eCoords
                            end
                        end
                    end
                end
            end
        end
    end

    if bestEntity ~= 0 then
        return true, bestCoords, bestEntity, bestType, GetEntityModel(bestEntity)
    end

    return false, playerCoords, 0, 0, 0
end
