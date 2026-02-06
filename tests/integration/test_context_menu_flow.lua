-- Integration: right-click -> context menu -> add option -> trigger action

local MockFactory = require("tests.mocks.pz_classes")
local helpers = require("tests.mocks.mock_helpers")

describe("Context menu flow integration", function()
    local onFillWorldObjectContextMenu

    setup(function()
        resetAllMocks()
        require("ClimbBoxConfig")
        require("ClimbBoxHealth")
        require("ISClimbBox")
        require("ClimbBox")
        require("ClimbBoxContextMenu")

        onFillWorldObjectContextMenu = Events.OnFillWorldObjectContextMenu._callbacks[1]
    end)

    local function createContext()
        local ctx = { _options = {} }
        function ctx:addOption(text, player, callback, ...)
            table.insert(self._options, {
                text = text, player = player, callback = callback, args = {...},
            })
        end
        return ctx
    end

    before_each(function()
        _G.ISTimedActionQueue._added = {}
        _G._sentClientCommands = {}
        helpers.resetSandboxVars()
    end)

    it("adds option and triggers action when selected", function()
        local playerSquare = MockFactory.createGridSquare(100, 100, 0)
        local boxSquare = MockFactory.createGridSquare(101, 100, 0)
        local box = helpers.makeBoxObject({ square = boxSquare })
        box.getSquare = function() return boxSquare end

        local player = MockFactory.createPlayer({
            square = playerSquare,
            bodyParts = helpers.allHealthyParts(),
        })
        _G._specificPlayers[0] = player

        local ctx = createContext()
        onFillWorldObjectContextMenu(0, ctx, { box }, false)

        -- Option was added
        assert.are.equal(1, #ctx._options)

        -- Simulate clicking the option
        local opt = ctx._options[1]
        opt.callback(opt.player, unpack(opt.args))

        -- Action was queued
        assert.are.equal(1, #ISTimedActionQueue._added)
        local action = ISTimedActionQueue._added[1]
        assert.are.equal(player, action.character)
    end)

    it("does not add option for non-adjacent box", function()
        local playerSquare = MockFactory.createGridSquare(100, 100, 0)
        local farSquare = MockFactory.createGridSquare(105, 100, 0)
        local box = helpers.makeBoxObject({ square = farSquare })
        box.getSquare = function() return farSquare end

        local player = MockFactory.createPlayer({
            square = playerSquare,
            bodyParts = helpers.allHealthyParts(),
        })
        _G._specificPlayers[0] = player

        local ctx = createContext()
        onFillWorldObjectContextMenu(0, ctx, { box }, false)
        assert.are.equal(0, #ctx._options)
    end)

    it("blocks when health check fails", function()
        local playerSquare = MockFactory.createGridSquare(100, 100, 0)
        local boxSquare = MockFactory.createGridSquare(101, 100, 0)
        local box = helpers.makeBoxObject({ square = boxSquare })
        box.getSquare = function() return boxSquare end

        local parts = helpers.allHealthyParts()
        parts[BodyPartType.Foot_R] = MockFactory.createBodyPart({ deepWounded = true })

        local player = MockFactory.createPlayer({
            square = playerSquare,
            bodyParts = parts,
        })
        _G._specificPlayers[0] = player
        SandboxVars.ClimbableBoxes.EnableHealthCheck = true

        local ctx = createContext()
        onFillWorldObjectContextMenu(0, ctx, { box }, false)
        assert.are.equal(0, #ctx._options)
    end)
end)
