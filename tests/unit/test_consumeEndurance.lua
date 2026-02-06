-- Unit tests for ISClimbBox:consumeEndurance

local MockFactory = require("tests.mocks.pz_classes")
local helpers = require("tests.mocks.mock_helpers")

describe("ISClimbBox:consumeEndurance", function()
    local ISClimbBox

    setup(function()
        resetAllMocks()
        require("ISClimbBox")
        ISClimbBox = _G.ISClimbBox
    end)

    before_each(function()
        _G._sentClientCommands = {}
        helpers.resetSandboxVars()
        ZomboidGlobals.RunningEnduranceReduce = 0.005
    end)

    local function makeAction(opts)
        opts = opts or {}
        local player = MockFactory.createPlayer({})
        local action = ISClimbBox:new(player, nil, nil)
        action.isStruggle = opts.isStruggle or false
        return action
    end

    it("sends base endurance cost", function()
        SandboxVars.ClimbableBoxes.EnduranceCostMultiplier = 1.0
        local action = makeAction()
        action:consumeEndurance()

        assert.are.equal(1, #_G._sentClientCommands)
        local cmd = _G._sentClientCommands[1]
        assert.are.equal("ClimbBox", cmd.module)
        assert.are.equal("consumeEndurance", cmd.command)
        -- Base: 0.005 * 800 = 4.0, multiplied by 1.0
        assert.are.equal(4.0, cmd.args.tractionDone)
    end)

    it("adds struggle bonus endurance", function()
        SandboxVars.ClimbableBoxes.EnduranceCostMultiplier = 1.0
        local action = makeAction({ isStruggle = true })
        action:consumeEndurance()

        local cmd = _G._sentClientCommands[1]
        -- Base: 0.005 * 800 = 4.0, Struggle: 0.005 * 500 = 2.5, Total: 6.5 * 1.0
        assert.are.equal(6.5, cmd.args.tractionDone)
    end)

    it("scales by multiplier", function()
        SandboxVars.ClimbableBoxes.EnduranceCostMultiplier = 2.5
        local action = makeAction()
        action:consumeEndurance()

        local cmd = _G._sentClientCommands[1]
        -- 4.0 * 2.5 = 10.0
        assert.are.equal(10.0, cmd.args.tractionDone)
    end)

    it("applies zero cost with zero multiplier", function()
        SandboxVars.ClimbableBoxes.EnduranceCostMultiplier = 0
        local action = makeAction()
        action:consumeEndurance()

        local cmd = _G._sentClientCommands[1]
        assert.are.equal(0, cmd.args.tractionDone)
    end)

    it("defaults multiplier to 1.0 when nil", function()
        SandboxVars.ClimbableBoxes.EnduranceCostMultiplier = nil
        local action = makeAction()
        action:consumeEndurance()

        local cmd = _G._sentClientCommands[1]
        assert.are.equal(4.0, cmd.args.tractionDone)
    end)
end)
