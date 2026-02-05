require "ClimbBoxConfig"
require "ClimbBoxHealth"
require "Actions/ISClimbBox"

ClimbBox = ClimbBox or {}
ClimbBox.Verbose = true  -- Enable debug output

print("[ClimbBox] Module loaded successfully")

-- Normalize floating point direction to cardinal (-1, 0, or 1)
function ClimbBox.normalizeByDirection(value)
    if value > 0 then return 1 end
    if value < 0 then return -1 end
    return 0
end

-- Check if two squares are adjacent (not diagonal, not same)
function ClimbBox.isAdjacent(squareA, squareB)
    if not squareA or not squareB then return false end
    local diffX = math.abs(squareA:getX() - squareB:getX())
    local diffY = math.abs(squareA:getY() - squareB:getY())
    local diffZ = math.abs(squareA:getZ() - squareB:getZ())
    if diffZ ~= 0 then return false end
    -- Adjacent means exactly 1 tile away in one axis only
    return (diffX == 1 and diffY == 0) or (diffX == 0 and diffY == 1)
end

-- Detect if an object is a climbable box/crate by properties
function ClimbBox.isClimbableBox(isoObject)
    if ClimbBox.Verbose then print("[ClimbBox] isClimbableBox called") end
    if not isoObject then return false end

    -- Skip non-physical objects
    if instanceof(isoObject, "IsoWorldInventoryObject") then return false end

    local sprite = isoObject:getSprite()
    if not sprite then return false end
    local props = sprite:getProperties()
    if not props then return false end

    -- Must be a moveable object
    local isMoveable = props:has("IsMoveAble")
    if ClimbBox.Verbose then print("[ClimbBox] IsMoveAble: " .. tostring(isMoveable)) end
    if not isMoveable then return false end

    -- Must have a container type
    local containerType = props:get("ContainerType")
    if ClimbBox.Verbose then print("[ClimbBox] ContainerType: " .. tostring(containerType)) end
    if not containerType then return false end

    -- Known box/crate container types
    local validTypes = {
        ["crate"] = true,
        ["smallbox"] = true,
        ["cardboardbox"] = true,
    }

    if validTypes[string.lower(containerType)] then
        if ClimbBox.Verbose then print("[ClimbBox] Valid container type matched!") end
        return true
    end

    -- Fallback: check object name for box/crate keywords
    local objName = isoObject:getName()
    if objName then
        local lower = string.lower(objName)
        if string.find(lower, "box") or string.find(lower, "crate") then
            return true
        end
    end

    return false
end

-- Find a climbable box on the square the player is facing
function ClimbBox.findClimbTarget(isoPlayer)
    local playerSquare = isoPlayer:getSquare()
    if not playerSquare then return nil, nil end

    -- Get facing direction
    local angle = isoPlayer:getAnimSetName()
    local deltaX = ClimbBox.normalizeByDirection(math.cos(math.rad(angle)))
    local deltaY = ClimbBox.normalizeByDirection(math.sin(math.rad(angle)))

    -- Target is the adjacent square in the facing direction (same Z)
    local targetSquare = getGridSquare(
        playerSquare:getX() + deltaX,
        playerSquare:getY() + deltaY,
        playerSquare:getZ()
    )
    if not targetSquare then return nil, nil end

    -- Find a climbable box on the target square
    local objects = targetSquare:getObjects()
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if ClimbBox.isClimbableBox(obj) then
            return targetSquare, obj
        end
    end

    return nil, nil
end

-- Main input detection loop
function ClimbBox.OnPlayerUpdate(isoPlayer)
    -- 1. Cheapest checks first
    local keyPressed = ClimbBox.getKey()
    if ClimbBox.Verbose and keyPressed then print("[ClimbBox] Key pressed detected") end
    if not keyPressed then return end
    if isoPlayer:hasTimedActions() then return end

    -- 2. Square checks
    local square = isoPlayer:getSquare()
    if not square then return end
    if square:HasStairs() then return end

    -- 3. Health check (if enabled in sandbox)
    if SandboxVars.ClimbableBoxes.EnableHealthCheck then
        if ClimbBox.isHealthInhibitingClimb(isoPlayer) then return end
    end

    -- 4. Find target box
    local targetSquare, targetBox = ClimbBox.findClimbTarget(isoPlayer)
    if not targetSquare or not targetBox then return end

    -- 5. Verify target square is not already occupied by player
    if square:getX() == targetSquare:getX() and
       square:getY() == targetSquare:getY() then return end

    -- 6. Queue the action
    ISTimedActionQueue.add(ISClimbBox:new(isoPlayer, targetSquare, targetBox))
end

print("[ClimbBox] Registering OnPlayerUpdate event")
Events.OnPlayerUpdate.Add(ClimbBox.OnPlayerUpdate)
