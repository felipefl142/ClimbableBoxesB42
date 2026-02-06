-- Unit tests for ClimbBox.OnPlayerUpdate

local MockFactory = require("tests.mocks.pz_classes")
local helpers = require("tests.mocks.mock_helpers")

describe("ClimbBox.OnPlayerUpdate", function()
    local ClimbBox

    setup(function()
        resetAllMocks()
        require("ClimbBoxConfig")
        require("ClimbBoxHealth")
        require("ISClimbBox")
        require("ClimbBox")
        ClimbBox = _G.ClimbBox
    end)

    before_each(function()
        _G._keyDownState = {}
        _G._isClientVal = false
        _G._isServerVal = false
        _G.ISTimedActionQueue._added = {}
        ClimbBox.keyBind = nil
        helpers.resetSandboxVars()
    end)

    it("does nothing when key is not pressed", function()
        local scenario = helpers.createClimbScenario({ dir = IsoDirections.E })
        ClimbBox.OnPlayerUpdate(scenario.player)
        assert.are.equal(0, #ISTimedActionQueue._added)
    end)

    it("does nothing when player has timed actions", function()
        local scenario = helpers.createClimbScenario({ dir = IsoDirections.E, hasTimedActions = true })
        _G._keyDownState[Keyboard.KEY_G] = true
        ClimbBox.OnPlayerUpdate(scenario.player)
        assert.are.equal(0, #ISTimedActionQueue._added)
    end)

    it("does nothing when player has no square", function()
        local player = MockFactory.createPlayer({ square = nil })
        _G._keyDownState[Keyboard.KEY_G] = true
        ClimbBox.OnPlayerUpdate(player)
        assert.are.equal(0, #ISTimedActionQueue._added)
    end)

    it("does nothing when player is on stairs", function()
        local square = MockFactory.createGridSquare(10, 10, 0, { hasStairs = true })
        local player = MockFactory.createPlayer({ square = square })
        _G._keyDownState[Keyboard.KEY_G] = true
        ClimbBox.OnPlayerUpdate(player)
        assert.are.equal(0, #ISTimedActionQueue._added)
    end)

    it("does nothing when health check fails and is enabled", function()
        local scenario = helpers.createClimbScenario({
            dir = IsoDirections.E,
            bodyParts = (function()
                local parts = helpers.allHealthyParts()
                parts[BodyPartType.Hand_L] = MockFactory.createBodyPart({ fractureTime = 10.0 })
                return parts
            end)(),
        })
        SandboxVars.ClimbableBoxes.EnableHealthCheck = true
        _G._keyDownState[Keyboard.KEY_G] = true
        ClimbBox.OnPlayerUpdate(scenario.player)
        assert.are.equal(0, #ISTimedActionQueue._added)
    end)

    it("skips health check when disabled", function()
        local scenario = helpers.createClimbScenario({
            dir = IsoDirections.E,
            bodyParts = (function()
                local parts = helpers.allHealthyParts()
                parts[BodyPartType.Hand_L] = MockFactory.createBodyPart({ fractureTime = 10.0 })
                return parts
            end)(),
        })
        SandboxVars.ClimbableBoxes.EnableHealthCheck = false
        _G._keyDownState[Keyboard.KEY_G] = true
        ClimbBox.OnPlayerUpdate(scenario.player)
        assert.are.equal(1, #ISTimedActionQueue._added)
    end)

    it("does nothing when no climbable box found", function()
        -- Create scenario with empty target square
        local playerSquare = MockFactory.createGridSquare(100, 100, 0)
        local targetSquare = MockFactory.createGridSquare(101, 100, 0, { objects = {} })
        local cell = MockFactory.createCell({ ["101,100,0"] = targetSquare })
        local player = MockFactory.createPlayer({
            square = playerSquare,
            dir = IsoDirections.E,
            cell = cell,
        })
        _G._keyDownState[Keyboard.KEY_G] = true
        ClimbBox.OnPlayerUpdate(player)
        assert.are.equal(0, #ISTimedActionQueue._added)
    end)

    it("does nothing when target is same square as player", function()
        -- Edge case: create player where findClimbTarget returns own square
        -- This shouldn't happen in practice, but the guard checks for it
        local scenario = helpers.createClimbScenario({ dir = IsoDirections.E })
        -- Override the target square to match player's position
        scenario.targetSquare._x = 100
        scenario.targetSquare._y = 100
        _G._keyDownState[Keyboard.KEY_G] = true
        ClimbBox.OnPlayerUpdate(scenario.player)
        assert.are.equal(0, #ISTimedActionQueue._added)
    end)

    it("queues action when all checks pass", function()
        local scenario = helpers.createClimbScenario({ dir = IsoDirections.E })
        _G._keyDownState[Keyboard.KEY_G] = true
        ClimbBox.OnPlayerUpdate(scenario.player)
        assert.are.equal(1, #ISTimedActionQueue._added)
    end)
end)
