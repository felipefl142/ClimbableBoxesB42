-- Unit tests for ISClimbBox:teleportPlayer

local MockFactory = require("tests.mocks.pz_classes")

describe("ISClimbBox:teleportPlayer", function()
    local ISClimbBox

    setup(function()
        resetAllMocks()
        require("ISClimbBox")
        ISClimbBox = _G.ISClimbBox
    end)

    before_each(function()
        _G.MovePlayer._calls = {}
    end)

    it("calls MovePlayer.Teleport with x+0.5, y+0.5, z", function()
        local player = MockFactory.createPlayer({})
        local sq = MockFactory.createGridSquare(50, 75, 2)
        local action = ISClimbBox:new(player, sq, nil)

        action:teleportPlayer()

        assert.are.equal(1, #MovePlayer._calls)
        local call = MovePlayer._calls[1]
        assert.are.equal(player, call.character)
        assert.are.equal(50.5, call.x)
        assert.are.equal(75.5, call.y)
        assert.are.equal(2, call.z)
    end)
end)
