-- Unit tests for ISClimbBox:new constructor

local MockFactory = require("tests.mocks.pz_classes")

describe("ISClimbBox:new", function()
    local ISClimbBox

    setup(function()
        resetAllMocks()
        require("ISClimbBox")
        ISClimbBox = _G.ISClimbBox
    end)

    it("stores character, targetSquare, and targetBox", function()
        local player = MockFactory.createPlayer({})
        local sq = MockFactory.createGridSquare(10, 10, 0)
        local box = MockFactory.createIsoObject({ name = "Crate" })
        local action = ISClimbBox:new(player, sq, box)
        assert.are.equal(player, action.character)
        assert.are.equal(sq, action.targetSquare)
        assert.are.equal(box, action.targetBox)
    end)

    it("sets stopOn flags to false", function()
        local player = MockFactory.createPlayer({})
        local action = ISClimbBox:new(player, nil, nil)
        assert.is_false(action.stopOnWalk)
        assert.is_false(action.stopOnRun)
    end)

    it("initializes state to 'start'", function()
        local player = MockFactory.createPlayer({})
        local action = ISClimbBox:new(player, nil, nil)
        assert.are.equal("start", action.currentState)
    end)

    it("initializes fail and struggle flags to false", function()
        local player = MockFactory.createPlayer({})
        local action = ISClimbBox:new(player, nil, nil)
        assert.is_false(action.isFail)
        assert.is_false(action.isStruggle)
    end)

    it("initializes outcome and teleport flags to false", function()
        local player = MockFactory.createPlayer({})
        local action = ISClimbBox:new(player, nil, nil)
        assert.is_false(action.outcomeComputed)
        assert.is_false(action.teleported)
    end)

    it("sets maxTime to 150", function()
        local player = MockFactory.createPlayer({})
        local action = ISClimbBox:new(player, nil, nil)
        assert.are.equal(150, action.maxTime)
    end)

    it("sets animation name fields", function()
        local player = MockFactory.createPlayer({})
        local action = ISClimbBox:new(player, nil, nil)
        assert.are.equal("ClimbBoxStart", action.startAnim)
        assert.are.equal("ClimbBoxSuccess", action.successAnim)
        assert.are.equal("ClimbBoxStruggle", action.struggleAnim)
        assert.are.equal("ClimbBoxFail", action.failAnim)
        assert.are.equal("ClimbBoxEnd", action.endAnim)
    end)
end)
