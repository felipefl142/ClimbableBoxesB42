-- Test convenience helpers for Climbable Boxes tests

local MockFactory = require("tests.mocks.pz_classes")

local helpers = {}

-- Build a complete player + box + square scenario for testing
function helpers.createClimbScenario(opts)
    opts = opts or {}
    local playerX = opts.playerX or 100
    local playerY = opts.playerY or 100
    local playerZ = opts.playerZ or 0
    local dir = opts.dir or IsoDirections.N

    -- Calculate target based on direction
    local deltaX, deltaY = 0, 0
    if dir == IsoDirections.N then deltaY = -1
    elseif dir == IsoDirections.NE then deltaX = 1
    elseif dir == IsoDirections.E then deltaX = 1
    elseif dir == IsoDirections.SE then deltaX = 1
    elseif dir == IsoDirections.S then deltaY = 1
    elseif dir == IsoDirections.SW then deltaX = -1
    elseif dir == IsoDirections.W then deltaX = -1
    elseif dir == IsoDirections.NW then deltaX = -1
    end

    local targetX = playerX + deltaX
    local targetY = playerY + deltaY

    -- Create box sprite
    local boxSprite = MockFactory.createSprite(
        opts.spriteName or "carpentry_01_16",
        opts.spriteProps or { IsMoveAble = true, ContainerType = opts.containerType or "crate" }
    )

    -- Create target square with box
    local targetSquare = MockFactory.createGridSquare(targetX, targetY, playerZ)
    local box = MockFactory.createIsoObject({
        name = opts.boxName or "Crate",
        sprite = boxSprite,
        square = targetSquare,
    })
    targetSquare._objects = { box }

    -- Create player square
    local playerSquare = MockFactory.createGridSquare(playerX, playerY, playerZ)

    -- Create cell with both squares
    local cell = MockFactory.createCell({
        [targetX .. "," .. targetY .. "," .. playerZ] = targetSquare,
        [playerX .. "," .. playerY .. "," .. playerZ] = playerSquare,
    })

    -- Create player
    local player = MockFactory.createPlayer({
        square = playerSquare,
        dir = dir,
        cell = cell,
        traits = opts.traits or {},
        perkLevels = opts.perkLevels or {},
        moodleLevels = opts.moodleLevels or {},
        bodyParts = opts.bodyParts or helpers.allHealthyParts(),
        attackedBy = opts.attackedBy,
        targetSeenCount = opts.targetSeenCount or 0,
        hasTimedActions = opts.hasTimedActions or false,
    })

    return {
        player = player,
        playerSquare = playerSquare,
        targetSquare = targetSquare,
        box = box,
        cell = cell,
    }
end

-- Reset sandbox variables to defaults
function helpers.resetSandboxVars()
    SandboxVars.ClimbableBoxes = {
        DifficultyMode = 1,
        BaseSuccessRate = 90,
        EnduranceCostMultiplier = 1.0,
        EnableHealthCheck = true,
    }
end

-- Create a player with one specific injured body part
function helpers.createPlayerWithInjury(partName, injury)
    local parts = helpers.allHealthyParts()
    local injuryOpts = {}

    if injury == "fracture" then
        injuryOpts.fractureTime = 10.0
    elseif injury == "deepWound" then
        injuryOpts.deepWounded = true
    elseif injury == "lowHealth" then
        injuryOpts.health = 30.0
    elseif injury == "stiffness" then
        injuryOpts.stiffness = 60.0
    end

    parts[partName] = MockFactory.createBodyPart(injuryOpts)

    local square = MockFactory.createGridSquare(100, 100, 0)
    return MockFactory.createPlayer({
        square = square,
        bodyParts = parts,
    })
end

-- Return a body parts map where everything is healthy
function helpers.allHealthyParts()
    local parts = {}
    local allParts = {
        "Hand_L", "Hand_R", "ForeArm_L", "ForeArm_R",
        "UpperArm_L", "UpperArm_R", "Torso_Upper", "Torso_Lower",
        "UpperLeg_L", "UpperLeg_R", "LowerLeg_L", "LowerLeg_R",
        "Foot_L", "Foot_R", "Head", "Neck", "Groin",
    }
    for _, name in ipairs(allParts) do
        parts[name] = MockFactory.createBodyPart()
    end
    return parts
end

-- Shorthand for creating a climbable box IsoObject
function helpers.makeBoxObject(opts)
    opts = opts or {}
    local sprite = MockFactory.createSprite(
        opts.spriteName or "carpentry_01_16",
        opts.spriteProps or { IsMoveAble = true, ContainerType = opts.containerType or "crate" }
    )
    local square = opts.square or MockFactory.createGridSquare(101, 100, 0)
    local obj = MockFactory.createIsoObject({
        name = opts.name or "Crate",
        sprite = sprite,
        square = square,
        className = opts.className,
    })
    return obj
end

return helpers
