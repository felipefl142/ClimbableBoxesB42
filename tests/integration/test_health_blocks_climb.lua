-- Integration: health check blocks both keybind and context menu paths

local MockFactory = require("tests.mocks.pz_classes")
local helpers = require("tests.mocks.mock_helpers")

describe("Health blocks climb integration", function()
    local ClimbBox, onFillWorldObjectContextMenu

    setup(function()
        resetAllMocks()
        require("ClimbBoxConfig")
        require("ClimbBoxHealth")
        require("ISClimbBox")
        require("ClimbBox")
        require("ClimbBoxContextMenu")
        ClimbBox = _G.ClimbBox
        onFillWorldObjectContextMenu = Events.OnFillWorldObjectContextMenu._callbacks[1]
    end)

    local function createContext()
        local ctx = { _options = {} }
        function ctx:addOption(text, player, callback, ...)
            table.insert(self._options, { text = text, player = player, callback = callback, args = {...} })
        end
        return ctx
    end

    before_each(function()
        _G._keyDownState = {}
        _G.ISTimedActionQueue._added = {}
        helpers.resetSandboxVars()
        SandboxVars.ClimbableBoxes.EnableHealthCheck = true
    end)

    it("keybind blocked by fractured arm", function()
        local parts = helpers.allHealthyParts()
        parts[BodyPartType.UpperArm_R] = MockFactory.createBodyPart({ fractureTime = 10.0 })
        local scenario = helpers.createClimbScenario({ dir = IsoDirections.E, bodyParts = parts })
        _G._keyDownState[Keyboard.KEY_G] = true

        ClimbBox.OnPlayerUpdate(scenario.player)
        assert.are.equal(0, #ISTimedActionQueue._added)
    end)

    it("context menu blocked by fractured arm", function()
        local playerSquare = MockFactory.createGridSquare(100, 100, 0)
        local boxSquare = MockFactory.createGridSquare(101, 100, 0)
        local box = helpers.makeBoxObject({ square = boxSquare })
        box.getSquare = function() return boxSquare end

        local parts = helpers.allHealthyParts()
        parts[BodyPartType.UpperArm_R] = MockFactory.createBodyPart({ fractureTime = 10.0 })

        local player = MockFactory.createPlayer({ square = playerSquare, bodyParts = parts })
        _G._specificPlayers[0] = player

        local ctx = createContext()
        onFillWorldObjectContextMenu(0, ctx, { box }, false)
        assert.are.equal(0, #ctx._options)
    end)

    it("healthy player can climb via both paths", function()
        local scenario = helpers.createClimbScenario({
            dir = IsoDirections.E,
            bodyParts = helpers.allHealthyParts(),
        })

        -- Test keybind path
        _G._keyDownState[Keyboard.KEY_G] = true
        ClimbBox.OnPlayerUpdate(scenario.player)
        assert.are.equal(1, #ISTimedActionQueue._added)

        -- Test context menu path
        _G.ISTimedActionQueue._added = {}
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
        assert.are.equal(1, #ctx._options)
    end)

    it("disabled health check allows injured player via both paths", function()
        SandboxVars.ClimbableBoxes.EnableHealthCheck = false
        local parts = helpers.allHealthyParts()
        parts[BodyPartType.Hand_L] = MockFactory.createBodyPart({ fractureTime = 10.0 })

        -- Keybind path
        local scenario = helpers.createClimbScenario({ dir = IsoDirections.E, bodyParts = parts })
        _G._keyDownState[Keyboard.KEY_G] = true
        ClimbBox.OnPlayerUpdate(scenario.player)
        assert.are.equal(1, #ISTimedActionQueue._added)

        -- Context menu path
        local playerSquare = MockFactory.createGridSquare(100, 100, 0)
        local boxSquare = MockFactory.createGridSquare(101, 100, 0)
        local box = helpers.makeBoxObject({ square = boxSquare })
        box.getSquare = function() return boxSquare end

        local player = MockFactory.createPlayer({ square = playerSquare, bodyParts = parts })
        _G._specificPlayers[0] = player

        local ctx = createContext()
        onFillWorldObjectContextMenu(0, ctx, { box }, false)
        assert.are.equal(1, #ctx._options)
    end)
end)
