-- Integration: multiplayer sync - consumeEndurance -> sendClientCommand -> OnClientCommand -> stats:remove

local MockFactory = require("tests.mocks.pz_classes")
local helpers = require("tests.mocks.mock_helpers")

describe("Multiplayer sync integration", function()
    local ISClimbBox

    setup(function()
        resetAllMocks()
        require("ISClimbBox")
        ISClimbBox = _G.ISClimbBox
    end)

    before_each(function()
        _G._sentClientCommands = {}
        _G.Events.OnClientCommand = {
            _callbacks = {},
            Add = function(self, cb) table.insert(self._callbacks, cb) end,
            Remove = function(self, cb)
                for i, c in ipairs(self._callbacks) do
                    if c == cb then table.remove(self._callbacks, i); return end
                end
            end,
        }
        -- Fix: use function call style
        _G.Events.OnClientCommand.Add = function(cb)
            table.insert(_G.Events.OnClientCommand._callbacks, cb)
        end
        _G.Events.OnClientCommand.Remove = function(cb)
            for i, c in ipairs(_G.Events.OnClientCommand._callbacks) do
                if c == cb then table.remove(_G.Events.OnClientCommand._callbacks, i); return end
            end
        end
        helpers.resetSandboxVars()
    end)

    it("serverStart registers OnClientCommand callback", function()
        local player = MockFactory.createPlayer({})
        local action = ISClimbBox:new(player, nil, nil)
        action:serverStart()

        assert.are.equal(1, #Events.OnClientCommand._callbacks)
        assert.are.equal(ISClimbBox.OnClientCommandCallback, Events.OnClientCommand._callbacks[1])
    end)

    it("stop removes OnClientCommand callback", function()
        local player = MockFactory.createPlayer({})
        local action = ISClimbBox:new(player, nil, nil)
        action:serverStart()
        assert.are.equal(1, #Events.OnClientCommand._callbacks)

        action:stop()
        assert.are.equal(0, #Events.OnClientCommand._callbacks)
    end)

    it("perform removes OnClientCommand callback", function()
        local player = MockFactory.createPlayer({})
        local action = ISClimbBox:new(player, nil, nil)
        action:serverStart()
        assert.are.equal(1, #Events.OnClientCommand._callbacks)

        action:perform()
        assert.are.equal(0, #Events.OnClientCommand._callbacks)
    end)

    it("endurance round-trip: client sends -> server applies", function()
        local player = MockFactory.createPlayer({})
        local action = ISClimbBox:new(player, nil, nil)
        action.isStruggle = false
        SandboxVars.ClimbableBoxes.EnduranceCostMultiplier = 1.0

        -- Client side: consume endurance sends command
        action:consumeEndurance()
        assert.are.equal(1, #_G._sentClientCommands)

        local cmd = _G._sentClientCommands[1]
        assert.are.equal("ClimbBox", cmd.module)
        assert.are.equal("consumeEndurance", cmd.command)

        -- Server side: simulate receiving the command
        local serverPlayer = MockFactory.createPlayer({})
        local statsRef
        serverPlayer.getStats = function(self)
            local stats = { _removed = {} }
            function stats:remove(stat, amount)
                table.insert(self._removed, { stat = stat, amount = amount })
            end
            statsRef = stats
            return stats
        end

        ISClimbBox.OnClientCommandCallback(cmd.module, cmd.command, serverPlayer, cmd.args)

        assert.is_not_nil(statsRef)
        assert.are.equal(1, #statsRef._removed)
        assert.are.equal(CharacterStat.ENDURANCE, statsRef._removed[1].stat)
        assert.are.equal(cmd.args.tractionDone, statsRef._removed[1].amount)
    end)

    it("struggle endurance round-trip includes bonus", function()
        local player = MockFactory.createPlayer({})
        local action = ISClimbBox:new(player, nil, nil)
        action.isStruggle = true
        SandboxVars.ClimbableBoxes.EnduranceCostMultiplier = 1.0

        action:consumeEndurance()
        local cmd = _G._sentClientCommands[1]
        assert.is_true(cmd.args.isStruggle)

        -- Struggle cost is higher: (0.005*800 + 0.005*500) * 1.0 = 6.5
        assert.are.equal(6.5, cmd.args.tractionDone)
    end)
end)
