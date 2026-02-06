-- Unit tests for ISClimbBox:computeOutcome

local MockFactory = require("tests.mocks.pz_classes")
local helpers = require("tests.mocks.mock_helpers")

describe("ISClimbBox:computeOutcome", function()
    local ISClimbBox

    setup(function()
        resetAllMocks()
        require("ISClimbBox")
        ISClimbBox = _G.ISClimbBox
    end)

    local function makeAction(opts)
        opts = opts or {}
        local player = MockFactory.createPlayer({
            perkLevels = opts.perkLevels or {},
            moodleLevels = opts.moodleLevels or {},
            traits = opts.traits or {},
            attackedBy = opts.attackedBy,
            targetSeenCount = opts.targetSeenCount or 0,
        })
        return ISClimbBox:new(player, nil, nil)
    end

    before_each(function()
        helpers.resetSandboxVars()
        _G._zombRandVal = 50
        _G._sentClientCommands = {}
    end)

    it("calls computeSuccessRate in Full mode (DifficultyMode=1)", function()
        SandboxVars.ClimbableBoxes.DifficultyMode = 1
        SandboxVars.ClimbableBoxes.BaseSuccessRate = 10
        _G._zombRandVal = 99
        local action = makeAction()
        action:computeOutcome()
        -- With base=10 and rand=99, should fail
        assert.is_true(action.isFail)
    end)

    it("skips computeSuccessRate in Simplified mode", function()
        SandboxVars.ClimbableBoxes.DifficultyMode = 2
        SandboxVars.ClimbableBoxes.BaseSuccessRate = 10
        _G._zombRandVal = 99
        local action = makeAction()
        action:computeOutcome()
        -- Simplified always succeeds regardless of stats
        assert.is_false(action.isFail)
        assert.is_false(action.isStruggle)
    end)

    it("defaults to Full mode when DifficultyMode is nil", function()
        SandboxVars.ClimbableBoxes.DifficultyMode = nil
        SandboxVars.ClimbableBoxes.BaseSuccessRate = 10
        _G._zombRandVal = 99
        local action = makeAction()
        action:computeOutcome()
        assert.is_true(action.isFail)
    end)

    it("always calls consumeEndurance", function()
        local action = makeAction()
        action:computeOutcome()
        assert.are.equal(1, #_G._sentClientCommands)
        assert.are.equal("consumeEndurance", _G._sentClientCommands[1].command)
    end)

    it("sets failAnim on fail outcome", function()
        SandboxVars.ClimbableBoxes.BaseSuccessRate = 10
        _G._zombRandVal = 99
        local action = makeAction()
        action:computeOutcome()
        assert.are.equal("ClimbBoxFail", action._currentAnim)
    end)

    it("sets struggleAnim on struggle outcome", function()
        SandboxVars.ClimbableBoxes.BaseSuccessRate = 90
        _G._zombRandVal = 70  -- between 65 and 90
        local action = makeAction()
        action:computeOutcome()
        assert.are.equal("ClimbBoxStruggle", action._currentAnim)
    end)

    it("sets successAnim on success outcome", function()
        _G._zombRandVal = 1  -- critical success
        local action = makeAction()
        action:computeOutcome()
        assert.are.equal("ClimbBoxSuccess", action._currentAnim)
    end)
end)
