-- Unit tests for ISClimbBox:computeSuccessRate

local MockFactory = require("tests.mocks.pz_classes")
local helpers = require("tests.mocks.mock_helpers")

describe("ISClimbBox:computeSuccessRate", function()
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
        local action = ISClimbBox:new(player, nil, nil)
        return action
    end

    before_each(function()
        helpers.resetSandboxVars()
        _G._zombRandVal = 50
        _G._sentClientCommands = {}
    end)

    it("uses base rate from sandbox", function()
        SandboxVars.ClimbableBoxes.BaseSuccessRate = 80
        _G._zombRandVal = 0  -- always succeed
        local action = makeAction()
        action:computeSuccessRate()
        assert.is_false(action.isFail)
    end)

    it("defaults base rate to 90 when nil", function()
        SandboxVars.ClimbableBoxes.BaseSuccessRate = nil
        _G._zombRandVal = 89  -- just under 90
        local action = makeAction()
        action:computeSuccessRate()
        assert.is_false(action.isFail)
    end)

    it("adds +2 per Fitness level", function()
        SandboxVars.ClimbableBoxes.BaseSuccessRate = 90
        _G._zombRandVal = 95 -- between 90 and 100
        local action = makeAction({ perkLevels = { [Perks.Fitness] = 5 } })
        action:computeSuccessRate()
        -- 90 + 10 = 100, rand=95 <= 100, so not fail
        assert.is_false(action.isFail)
    end)

    it("adds +2 per Strength level", function()
        SandboxVars.ClimbableBoxes.BaseSuccessRate = 90
        _G._zombRandVal = 95
        local action = makeAction({ perkLevels = { [Perks.Strength] = 5 } })
        action:computeSuccessRate()
        -- 90 + 10 = 100
        assert.is_false(action.isFail)
    end)

    it("subtracts -10 per endurance moodle level", function()
        SandboxVars.ClimbableBoxes.BaseSuccessRate = 90
        _G._zombRandVal = 85
        local action = makeAction({ moodleLevels = { [MoodleType.ENDURANCE] = 2 } })
        action:computeSuccessRate()
        -- 90 - 20 = 70, rand=85 > 70, so fail
        assert.is_true(action.isFail)
    end)

    it("subtracts -16 per heavy load moodle level", function()
        SandboxVars.ClimbableBoxes.BaseSuccessRate = 90
        _G._zombRandVal = 80
        local action = makeAction({ moodleLevels = { [MoodleType.HEAVY_LOAD] = 2 } })
        action:computeSuccessRate()
        -- 90 - 32 = 58, rand=80 > 58, so fail
        assert.is_true(action.isFail)
    end)

    it("subtracts -25 for EMACIATED trait", function()
        SandboxVars.ClimbableBoxes.BaseSuccessRate = 90
        _G._zombRandVal = 70
        local action = makeAction({ traits = { CharacterTrait.EMACIATED } })
        action:computeSuccessRate()
        -- 90 - 25 = 65, rand=70 > 65, so fail
        assert.is_true(action.isFail)
    end)

    it("subtracts -25 for OBESE trait", function()
        SandboxVars.ClimbableBoxes.BaseSuccessRate = 90
        _G._zombRandVal = 70
        local action = makeAction({ traits = { CharacterTrait.OBESE } })
        action:computeSuccessRate()
        assert.is_true(action.isFail)
    end)

    it("subtracts -25 for VERY_UNDERWEIGHT trait", function()
        SandboxVars.ClimbableBoxes.BaseSuccessRate = 90
        _G._zombRandVal = 70
        local action = makeAction({ traits = { CharacterTrait.VERY_UNDERWEIGHT } })
        action:computeSuccessRate()
        assert.is_true(action.isFail)
    end)

    it("subtracts -15 for UNDERWEIGHT trait", function()
        SandboxVars.ClimbableBoxes.BaseSuccessRate = 90
        _G._zombRandVal = 80
        local action = makeAction({ traits = { CharacterTrait.UNDERWEIGHT } })
        action:computeSuccessRate()
        -- 90 - 15 = 75, rand=80 > 75, so fail
        assert.is_true(action.isFail)
    end)

    it("subtracts -15 for OVERWEIGHT trait", function()
        SandboxVars.ClimbableBoxes.BaseSuccessRate = 90
        _G._zombRandVal = 80
        local action = makeAction({ traits = { CharacterTrait.OVERWEIGHT } })
        action:computeSuccessRate()
        assert.is_true(action.isFail)
    end)

    it("stacks multiple trait penalties", function()
        SandboxVars.ClimbableBoxes.BaseSuccessRate = 90
        _G._zombRandVal = 50
        local action = makeAction({ traits = { CharacterTrait.EMACIATED, CharacterTrait.UNDERWEIGHT } })
        action:computeSuccessRate()
        -- 90 - 25 - 15 = 50, rand=50 <= 50, so not fail
        assert.is_false(action.isFail)
    end)

    it("subtracts -25 when attacked", function()
        SandboxVars.ClimbableBoxes.BaseSuccessRate = 90
        _G._zombRandVal = 70
        local action = makeAction({ attackedBy = {} })
        action:computeSuccessRate()
        -- 90 - 25 = 65, rand=70 > 65, so fail
        assert.is_true(action.isFail)
    end)

    it("subtracts -7 per nearby zombie", function()
        SandboxVars.ClimbableBoxes.BaseSuccessRate = 90
        _G._zombRandVal = 80
        local action = makeAction({ targetSeenCount = 3 })
        action:computeSuccessRate()
        -- 90 - 21 = 69, rand=80 > 69, so fail
        assert.is_true(action.isFail)
    end)

    it("clamps to 0 when negative", function()
        SandboxVars.ClimbableBoxes.BaseSuccessRate = 10
        _G._zombRandVal = 0 -- even 0 > 0 is false, so not fail with rand=0
        local action = makeAction({
            traits = { CharacterTrait.EMACIATED },
            moodleLevels = { [MoodleType.HEAVY_LOAD] = 4 },
        })
        action:computeSuccessRate()
        -- 10 - 25 - 64 = -79 -> clamped to 0
        -- rand=0 <= 0, so not fail (edge case)
        assert.is_false(action.isFail)
    end)

    it("clamps to 100 when exceeding", function()
        SandboxVars.ClimbableBoxes.BaseSuccessRate = 100
        _G._zombRandVal = 99
        local action = makeAction({
            perkLevels = { [Perks.Fitness] = 10, [Perks.Strength] = 10 },
        })
        action:computeSuccessRate()
        -- 100 + 20 + 20 = 140 -> clamped to 100
        assert.is_false(action.isFail)
    end)

    it("grants critical success when rand == 1", function()
        _G._zombRandVal = 1
        SandboxVars.ClimbableBoxes.BaseSuccessRate = 10
        local action = makeAction({
            traits = { CharacterTrait.EMACIATED },
            moodleLevels = { [MoodleType.HEAVY_LOAD] = 4 },
        })
        action:computeSuccessRate()
        assert.is_false(action.isFail)
        assert.is_false(action.isStruggle)
    end)

    it("sets struggle in the zone between (rate-25) and rate", function()
        SandboxVars.ClimbableBoxes.BaseSuccessRate = 90
        _G._zombRandVal = 70  -- between 65 and 90
        local action = makeAction()
        action:computeSuccessRate()
        -- rand=70 > (90-25)=65, so isStruggle = true
        -- rand=70 <= 90, so isFail = false
        assert.is_true(action.isStruggle)
        assert.is_false(action.isFail)
    end)

    it("sets both fail and struggle when rand exceeds rate", function()
        SandboxVars.ClimbableBoxes.BaseSuccessRate = 50
        _G._zombRandVal = 60  -- > 50 and > 25
        local action = makeAction()
        action:computeSuccessRate()
        -- rand=60 > (50-25)=25, so isStruggle = true
        -- rand=60 > 50, so isFail = true
        assert.is_true(action.isFail)
        assert.is_true(action.isStruggle)
    end)
end)
