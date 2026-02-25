-- ═══════════════════════════════════════════════════════════════════
-- nova_target — Zone System
-- Box, Sphere, Poly zone detection with math-based point-in-zone
-- ═══════════════════════════════════════════════════════════════════

Zones = {}

-- ═══════════════════════════════════════════════════════════════════
-- Point-in-zone math functions
-- ═══════════════════════════════════════════════════════════════════

--- Check if a point is inside a sphere zone
---@param point vector3
---@param zone table { coords, radius }
---@return boolean
function Zones.isPointInSphere(point, zone)
    return #(point - zone.coords) <= zone.radius
end

--- Check if a point is inside a rotated box zone
---@param point vector3
---@param zone table { coords, size, rotation }
---@return boolean
function Zones.isPointInBox(point, zone)
    local center = zone.coords
    local size = zone.size
    local rot = math.rad(-(zone.rotation or 0.0))

    -- Translate point relative to box center
    local dx = point.x - center.x
    local dy = point.y - center.y
    local dz = point.z - center.z

    -- Rotate point into box's local space (inverse rotation around Z)
    local cosR = math.cos(rot)
    local sinR = math.sin(rot)
    local localX = dx * cosR - dy * sinR
    local localY = dx * sinR + dy * cosR

    -- Check if within half-extents
    local halfW = size.x / 2.0
    local halfL = size.y / 2.0
    local halfH = size.z / 2.0

    return math.abs(localX) <= halfW
       and math.abs(localY) <= halfL
       and math.abs(dz) <= halfH
end

--- Check if a 2D point is inside a polygon (ray casting algorithm)
---@param px number
---@param py number
---@param points table[] array of {x, y} or vector3
---@return boolean
local function pointInPolygon2D(px, py, points)
    local n = #points
    local inside = false

    local j = n
    for i = 1, n do
        local xi, yi = points[i].x, points[i].y
        local xj, yj = points[j].x, points[j].y

        if ((yi > py) ~= (yj > py)) and (px < (xj - xi) * (py - yi) / (yj - yi) + xi) then
            inside = not inside
        end
        j = i
    end

    return inside
end

--- Check if a point is inside a poly zone
---@param point vector3
---@param zone table { points, thickness }
---@return boolean
function Zones.isPointInPoly(point, zone)
    local points = zone.points
    if not points or #points < 3 then return false end

    -- Calculate average Z of polygon points
    local avgZ = 0
    for _, p in ipairs(points) do
        avgZ = avgZ + (p.z or 0)
    end
    avgZ = avgZ / #points

    -- Check Z range (thickness)
    local halfThick = (zone.thickness or 4.0) / 2.0
    if point.z < (avgZ - halfThick) or point.z > (avgZ + halfThick) then
        return false
    end

    -- Check 2D point-in-polygon
    return pointInPolygon2D(point.x, point.y, points)
end

--- Check if a point is inside any zone type
---@param point vector3
---@param zone table
---@return boolean
function Zones.isPointInZone(point, zone)
    if zone.type == "sphere" then
        return Zones.isPointInSphere(point, zone)
    elseif zone.type == "box" then
        return Zones.isPointInBox(point, zone)
    elseif zone.type == "poly" then
        return Zones.isPointInPoly(point, zone)
    end
    return false
end

--- Get the center of a zone (for distance calculations)
---@param zone table
---@return vector3|nil
function Zones.getZoneCenter(zone)
    if zone.coords then
        return zone.coords
    end
    if zone.points and #zone.points > 0 then
        local cx, cy, cz = 0, 0, 0
        for _, p in ipairs(zone.points) do
            cx = cx + p.x
            cy = cy + p.y
            cz = cz + (p.z or 0)
        end
        local n = #zone.points
        return vector3(cx / n, cy / n, cz / n)
    end
    return nil
end

--- Get all zones the player is currently inside
---@param playerCoords vector3
---@return table[] array of { zone, options, distance }
function Zones.getActiveZones(playerCoords)
    local active = {}

    for _, zone in pairs(Registry.zones) do
        if Zones.isPointInZone(playerCoords, zone) then
            local center = Zones.getZoneCenter(zone)
            local dist = center and #(playerCoords - center) or 0

            active[#active + 1] = {
                zone     = zone,
                options  = zone.options,
                distance = dist,
            }
        end
    end

    return active
end

--- Draw debug markers for zones (when Config.Debug is true)
---@param playerCoords vector3
function Zones.drawDebug(playerCoords)
    if not Config.Debug then return end

    for _, zone in pairs(Registry.zones) do
        local center = Zones.getZoneCenter(zone)
        if center and #(playerCoords - center) < Config.DrawDistance then
            local isInside = Zones.isPointInZone(playerCoords, zone)
            local r = isInside and 0 or 255
            local g = isInside and 255 or 0

            if zone.type == "sphere" then
                DrawMarker(28, center.x, center.y, center.z,
                    0, 0, 0, 0, 0, 0,
                    zone.radius * 2, zone.radius * 2, zone.radius * 2,
                    r, g, 0, 50, false, false, 2, false, nil, nil, false)
            elseif zone.type == "box" then
                DrawMarker(1, center.x, center.y, center.z,
                    0, 0, 0, 0, 0, zone.rotation or 0,
                    zone.size.x, zone.size.y, zone.size.z,
                    r, g, 0, 50, false, false, 2, false, nil, nil, false)
            end
        end
    end
end
