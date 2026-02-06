-- Integration: timer-based state machine full flow

local MockFactory = require("tests.mocks.pz_classes")
local helpers = require("tests.mocks.mock_helpers")

describe("State machine flow integration", function()
    local ISClimbBox

    setup(function()
        resetAllMocks()
        require("ISClimbBox")
        ISClimbBox = _G.ISClimbBox
    end)

    before_each(function()
        _G.MovePlayer._calls = {}
        _G._sentClientCommands = {}
        helpers.resetSandboxVars()
    end)

    local function makeAction(opts)
        opts = opts or {}
        local player = MockFactory.createPlayer({
            perkLevels = opts.perkLevels or { [Perks.Fitness] = 5, [Perks.Strength] = 5 },
        })
        local sq = MockFactory.createGridSquare(101, 100, 0)
        local box = MockFactory.createIsoObject({ name = "Crate" })
        return ISClimbBox:new(player, sq, box)
    end

    it("success path: start -> outcome -> teleport -> end -> complete", function()
        _G._zombRandVal = 1  -- critical success
        local action = makeAction()

        -- Start phase
        action:start()
        assert.are.equal("ClimbBoxStart", action._currentAnim)

        -- Advance to outcome computation
        action.action._jobDelta = 45
        action:update()
        assert.is_true(action.outcomeComputed)
        assert.is_false(action.isFail)
        assert.is_false(action.isStruggle)
        assert.are.equal("ClimbBoxSuccess", action._currentAnim)

        -- Advance to teleport
        action.action._jobDelta = action.stateStartTime + 40
        action:update()
        assert.is_true(action.teleported)
        assert.are.equal(1, #MovePlayer._calls)
        assert.are.equal("ClimbBoxEnd", action._currentAnim)

        -- Advance to completion
        action.action._jobDelta = action.stateStartTime + 30
        action:update()
        assert.is_true(action._forceCompleted)
    end)

    it("struggle path: teleports but with extra endurance", function()
        SandboxVars.ClimbableBoxes.BaseSuccessRate = 90
        _G._zombRandVal = 70  -- struggle zone (65-90)
        local action = makeAction({ perkLevels = {} })

        action:start()
        action.action._jobDelta = 45
        action:update()

        assert.is_true(action.isStruggle)
        assert.is_false(action.isFail)
        assert.are.equal("ClimbBoxStruggle", action._currentAnim)

        -- Endurance was consumed with struggle bonus
        assert.are.equal(1, #_G._sentClientCommands)
        assert.is_true(_G._sentClientCommands[1].args.isStruggle)

        -- Still teleports
        action.action._jobDelta = action.stateStartTime + 40
        action:update()
        assert.is_true(action.teleported)
        assert.are.equal(1, #MovePlayer._calls)
    end)

    it("fail path: no teleport", function()
        SandboxVars.ClimbableBoxes.BaseSuccessRate = 10
        _G._zombRandVal = 99
        local action = makeAction({ perkLevels = {} })

        action:start()
        action.action._jobDelta = 45
        action:update()

        assert.is_true(action.isFail)
        assert.are.equal("ClimbBoxFail", action._currentAnim)

        -- Transition to end
        action.action._jobDelta = action.stateStartTime + 40
        action:update()
        assert.is_false(action.teleported)
        assert.are.equal(0, #MovePlayer._calls)
        assert.are.equal("ClimbBoxEnd", action._currentAnim)

        -- Still completes
        action.action._jobDelta = action.stateStartTime + 30
        action:update()
        assert.is_true(action._forceCompleted)
    end)

    it("simplified mode: always succeeds and teleports", function()
        SandboxVars.ClimbableBoxes.DifficultyMode = 2
        _G._zombRandVal = 99
        local action = makeAction({ perkLevels = {} })

        action:start()
        action.action._jobDelta = 45
        action:update()

        assert.is_false(action.isFail)
        assert.is_false(action.isStruggle)
        assert.are.equal("ClimbBoxSuccess", action._currentAnim)

        action.action._jobDelta = action.stateStartTime + 40
        action:update()
        assert.is_true(action.teleported)
        assert.are.equal(1, #MovePlayer._calls)
    end)
end)
