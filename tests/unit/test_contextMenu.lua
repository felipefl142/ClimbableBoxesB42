-- Unit tests for ClimbBoxContextMenu

local MockFactory = require("tests.mocks.pz_classes")
local helpers = require("tests.mocks.mock_helpers")

describe("ClimbBoxContextMenu", function()
    local ClimbBox
    local onFillWorldObjectContextMenu

    setup(function()
        resetAllMocks()
        require("ClimbBoxConfig")
        require("ClimbBoxHealth")
        require("ISClimbBox")
        require("ClimbBox")
        ClimbBox = _G.ClimbBox

        -- Require the context menu module which registers the event
        require("ClimbBoxContextMenu")

        -- Extract the registered callback
        onFillWorldObjectContextMenu = Events.OnFillWorldObjectContextMenu._callbacks[1]
        assert.is_not_nil(onFillWorldObjectContextMenu, "Context menu callback should be registered")
    end)

    local function createContext()
        local ctx = {
            _options = {},
        }
        function ctx:addOption(text, player, callback, ...)
            table.insert(self._options, {
                text = text,
                player = player,
                callback = callback,
                args = {...},
            })
        end
        return ctx
    end

    before_each(function()
        _G._specificPlayers = {}
        _G.ISTimedActionQueue._added = {}
        helpers.resetSandboxVars()
    end)

    it("does nothing when player is nil", function()
        _G._specificPlayers[0] = nil
        local ctx = createContext()
        onFillWorldObjectContextMenu(0, ctx, {}, false)
        assert.are.equal(0, #ctx._options)
    end)

    it("does nothing when player has timed actions", function()
        local player = MockFactory.createPlayer({ hasTimedActions = true })
        _G._specificPlayers[0] = player
        local ctx = createContext()
        onFillWorldObjectContextMenu(0, ctx, {}, false)
        assert.are.equal(0, #ctx._options)
    end)

    it("adds option for climbable adjacent box", function()
        -- Create adjacent player + box setup
        local playerSquare = MockFactory.createGridSquare(100, 100, 0)
        local boxSquare = MockFactory.createGridSquare(101, 100, 0)

        local box = helpers.makeBoxObject({ square = boxSquare })
        -- Override getSquare on the box to return our square
        box.getSquare = function() return boxSquare end

        local player = MockFactory.createPlayer({
            square = playerSquare,
            bodyParts = helpers.allHealthyParts(),
        })
        _G._specificPlayers[0] = player

        local ctx = createContext()
        onFillWorldObjectContextMenu(0, ctx, { box }, false)
        assert.are.equal(1, #ctx._options)
        assert.are.equal("ContextMenu_ClimbBox", ctx._options[1].text)
    end)

    it("skips non-climbable objects", function()
        local playerSquare = MockFactory.createGridSquare(100, 100, 0)
        local objSquare = MockFactory.createGridSquare(101, 100, 0)
        local nonBox = MockFactory.createIsoObject({
            name = "Chair",
            sprite = MockFactory.createSprite("furniture_01_01", { IsMoveAble = true }),
            square = objSquare,
        })
        nonBox.getSquare = function() return objSquare end

        local player = MockFactory.createPlayer({
            square = playerSquare,
            bodyParts = helpers.allHealthyParts(),
        })
        _G._specificPlayers[0] = player

        local ctx = createContext()
        onFillWorldObjectContextMenu(0, ctx, { nonBox }, false)
        assert.are.equal(0, #ctx._options)
    end)

    it("skips non-adjacent climbable box", function()
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
        parts[BodyPartType.Hand_L] = MockFactory.createBodyPart({ fractureTime = 10.0 })

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

    it("allows injured player when health check is disabled", function()
        local playerSquare = MockFactory.createGridSquare(100, 100, 0)
        local boxSquare = MockFactory.createGridSquare(101, 100, 0)

        local box = helpers.makeBoxObject({ square = boxSquare })
        box.getSquare = function() return boxSquare end

        local parts = helpers.allHealthyParts()
        parts[BodyPartType.Hand_L] = MockFactory.createBodyPart({ fractureTime = 10.0 })

        local player = MockFactory.createPlayer({
            square = playerSquare,
            bodyParts = parts,
        })
        _G._specificPlayers[0] = player
        SandboxVars.ClimbableBoxes.EnableHealthCheck = false

        local ctx = createContext()
        onFillWorldObjectContextMenu(0, ctx, { box }, false)
        assert.are.equal(1, #ctx._options)
    end)

    it("handles wrapped objects", function()
        local playerSquare = MockFactory.createGridSquare(100, 100, 0)
        local boxSquare = MockFactory.createGridSquare(101, 100, 0)

        local box = helpers.makeBoxObject({ square = boxSquare })
        box.getSquare = function() return boxSquare end

        local wrapped = { object = box }

        local player = MockFactory.createPlayer({
            square = playerSquare,
            bodyParts = helpers.allHealthyParts(),
        })
        _G._specificPlayers[0] = player

        local ctx = createContext()
        onFillWorldObjectContextMenu(0, ctx, { wrapped }, false)
        assert.are.equal(1, #ctx._options)
    end)

    it("only adds one option even with multiple boxes", function()
        local playerSquare = MockFactory.createGridSquare(100, 100, 0)
        local boxSquare = MockFactory.createGridSquare(101, 100, 0)

        local box1 = helpers.makeBoxObject({ square = boxSquare })
        box1.getSquare = function() return boxSquare end
        local box2 = helpers.makeBoxObject({ square = boxSquare })
        box2.getSquare = function() return boxSquare end

        local player = MockFactory.createPlayer({
            square = playerSquare,
            bodyParts = helpers.allHealthyParts(),
        })
        _G._specificPlayers[0] = player

        local ctx = createContext()
        onFillWorldObjectContextMenu(0, ctx, { box1, box2 }, false)
        -- Should break after first match
        assert.are.equal(1, #ctx._options)
    end)
end)
