-- Integration: keybind press -> OnPlayerUpdate -> findClimbTarget -> ISTimedActionQueue.add

local MockFactory = require("tests.mocks.pz_classes")
local helpers = require("tests.mocks.mock_helpers")

describe("Keybind to action integration", function()
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
        _G.ISTimedActionQueue._added = {}
        _G._sentClientCommands = {}
        helpers.resetSandboxVars()
    end)

    it("full success: key press -> detect box -> queue action", function()
        local scenario = helpers.createClimbScenario({
            dir = IsoDirections.E,
            containerType = "crate",
        })
        _G._keyDownState[Keyboard.KEY_G] = true

        ClimbBox.OnPlayerUpdate(scenario.player)

        assert.are.equal(1, #ISTimedActionQueue._added)
        local action = ISTimedActionQueue._added[1]
        assert.are.equal(scenario.player, action.character)
        assert.are.equal(scenario.targetSquare, action.targetSquare)
        assert.are.equal(scenario.box, action.targetBox)
    end)

    it("no box: key press -> search -> nothing queued", function()
        local playerSquare = MockFactory.createGridSquare(100, 100, 0)
        local emptySquare = MockFactory.createGridSquare(101, 100, 0, { objects = {} })
        local cell = MockFactory.createCell({ ["101,100,0"] = emptySquare })
        local player = MockFactory.createPlayer({
            square = playerSquare,
            dir = IsoDirections.E,
            cell = cell,
        })
        _G._keyDownState[Keyboard.KEY_G] = true

        ClimbBox.OnPlayerUpdate(player)

        assert.are.equal(0, #ISTimedActionQueue._added)
    end)

    it("health blocked: injured player cannot climb", function()
        local parts = helpers.allHealthyParts()
        parts[BodyPartType.Torso_Upper] = MockFactory.createBodyPart({ fractureTime = 10.0 })

        local scenario = helpers.createClimbScenario({
            dir = IsoDirections.E,
            bodyParts = parts,
        })
        SandboxVars.ClimbableBoxes.EnableHealthCheck = true
        _G._keyDownState[Keyboard.KEY_G] = true

        ClimbBox.OnPlayerUpdate(scenario.player)

        assert.are.equal(0, #ISTimedActionQueue._added)
    end)

    it("busy player: timed actions prevent new action", function()
        local scenario = helpers.createClimbScenario({
            dir = IsoDirections.E,
            hasTimedActions = true,
        })
        _G._keyDownState[Keyboard.KEY_G] = true

        ClimbBox.OnPlayerUpdate(scenario.player)

        assert.are.equal(0, #ISTimedActionQueue._added)
    end)
end)
