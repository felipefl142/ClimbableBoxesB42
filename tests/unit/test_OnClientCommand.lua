-- Unit tests for ISClimbBox.OnClientCommandCallback

local MockFactory = require("tests.mocks.pz_classes")

describe("ISClimbBox.OnClientCommandCallback", function()
    local ISClimbBox

    setup(function()
        resetAllMocks()
        require("ISClimbBox")
        ISClimbBox = _G.ISClimbBox
    end)

    it("ignores other modules", function()
        local player = MockFactory.createPlayer({})
        local stats = player:getStats()
        ISClimbBox.OnClientCommandCallback("OtherMod", "consumeEndurance", player, { tractionDone = 5.0 })
        -- Stats should not have been touched
        assert.are.equal(0, #stats._removed)
    end)

    it("applies consumeEndurance command", function()
        local player = MockFactory.createPlayer({})
        -- Need to capture stats before the call
        local statsRef
        local origGetStats = player.getStats
        player.getStats = function(self)
            statsRef = origGetStats(self)
            return statsRef
        end

        ISClimbBox.OnClientCommandCallback("ClimbBox", "consumeEndurance", player, { tractionDone = 5.0 })

        assert.is_not_nil(statsRef)
        assert.are.equal(1, #statsRef._removed)
        assert.are.equal(CharacterStat.ENDURANCE, statsRef._removed[1].stat)
        assert.are.equal(5.0, statsRef._removed[1].amount)
    end)

    it("ignores other commands within ClimbBox module", function()
        local player = MockFactory.createPlayer({})
        local stats = player:getStats()
        ISClimbBox.OnClientCommandCallback("ClimbBox", "unknownCommand", player, {})
        assert.are.equal(0, #stats._removed)
    end)
end)
