-- Unit tests for ISClimbBox:update (timer-based state machine)

local MockFactory = require("tests.mocks.pz_classes")
local helpers = require("tests.mocks.mock_helpers")

describe("ISClimbBox:update", function()
    local ISClimbBox
    local action

    setup(function()
        resetAllMocks()
        require("ISClimbBox")
        ISClimbBox = _G.ISClimbBox
    end)

    before_each(function()
        _G._zombRandVal = 50
        _G._sentClientCommands = {}
        _G.MovePlayer._calls = {}
        helpers.resetSandboxVars()

        local player = MockFactory.createPlayer({
            perkLevels = { [Perks.Fitness] = 5, [Perks.Strength] = 5 },
        })
        local sq = MockFactory.createGridSquare(101, 100, 0)
        local box = MockFactory.createIsoObject({ name = "Crate" })
        action = ISClimbBox:new(player, sq, box)
    end)

    it("does not compute outcome before tick 45", function()
        action.action._jobDelta = 44
        action:update()
        assert.is_false(action.outcomeComputed)
        assert.are.equal("start", action.currentState)
    end)

    it("computes outcome at tick 45", function()
        action.action._jobDelta = 45
        action:update()
        assert.is_true(action.outcomeComputed)
        assert.are.equal("outcome", action.currentState)
    end)

    it("does not double-compute outcome", function()
        action.action._jobDelta = 45
        action:update()
        local firstFail = action.isFail

        -- Advance time and update again
        action.action._jobDelta = 50
        action:update()
        -- State should still be outcome, not re-computed
        assert.are.equal("outcome", action.currentState)
        assert.are.equal(firstFail, action.isFail)
    end)

    it("does not transition before 40 ticks after outcome", function()
        action.action._jobDelta = 45
        action:update()
        local stateStart = action.stateStartTime

        action.action._jobDelta = stateStart + 39
        action:update()
        assert.is_false(action.teleported)
        assert.are.equal("outcome", action.currentState)
    end)

    it("teleports on success at 40 ticks after outcome", function()
        -- Force success
        _G._zombRandVal = 1 -- critical success
        action.action._jobDelta = 45
        action:update()
        local stateStart = action.stateStartTime

        action.action._jobDelta = stateStart + 40
        action:update()
        assert.is_true(action.teleported)
        assert.are.equal("end", action.currentState)
        assert.are.equal(1, #MovePlayer._calls)
    end)

    it("does not teleport on fail", function()
        -- Force fail
        _G._zombRandVal = 100 -- will exceed success rate
        SandboxVars.ClimbableBoxes.BaseSuccessRate = 10
        action.action._jobDelta = 45
        action:update()
        local stateStart = action.stateStartTime

        action.action._jobDelta = stateStart + 40
        action:update()
        assert.are.equal("end", action.currentState)
        assert.are.equal(0, #MovePlayer._calls)
    end)

    it("sets end animation on transition to end state", function()
        _G._zombRandVal = 1
        action.action._jobDelta = 45
        action:update()
        local stateStart = action.stateStartTime

        action.action._jobDelta = stateStart + 40
        action:update()
        assert.are.equal("ClimbBoxEnd", action._currentAnim)
    end)

    it("calls forceComplete 30 ticks after end state", function()
        _G._zombRandVal = 1
        -- Get to outcome
        action.action._jobDelta = 45
        action:update()
        local outcomeStart = action.stateStartTime

        -- Get to end
        action.action._jobDelta = outcomeStart + 40
        action:update()
        local endStart = action.stateStartTime

        -- Complete
        action.action._jobDelta = endStart + 30
        action:update()
        assert.is_true(action._forceCompleted)
    end)
end)
