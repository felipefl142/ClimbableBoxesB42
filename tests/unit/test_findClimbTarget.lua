-- Unit tests for ClimbBox.findClimbTarget

local MockFactory = require("tests.mocks.pz_classes")
local helpers = require("tests.mocks.mock_helpers")

describe("ClimbBox.findClimbTarget", function()
    local ClimbBox

    setup(function()
        resetAllMocks()
        require("ClimbBoxConfig")
        require("ClimbBoxHealth")
        require("ISClimbBox")
        require("ClimbBox")
        ClimbBox = _G.ClimbBox
    end)

    -- Cardinal directions
    it("finds box to the North", function()
        local scenario = helpers.createClimbScenario({ dir = IsoDirections.N })
        local sq, box = ClimbBox.findClimbTarget(scenario.player)
        assert.is_not_nil(sq)
        assert.is_not_nil(box)
        assert.are.equal(100, sq:getX())
        assert.are.equal(99, sq:getY())
    end)

    it("finds box to the East", function()
        local scenario = helpers.createClimbScenario({ dir = IsoDirections.E })
        local sq, box = ClimbBox.findClimbTarget(scenario.player)
        assert.is_not_nil(sq)
        assert.are.equal(101, sq:getX())
        assert.are.equal(100, sq:getY())
    end)

    it("finds box to the South", function()
        local scenario = helpers.createClimbScenario({ dir = IsoDirections.S })
        local sq, box = ClimbBox.findClimbTarget(scenario.player)
        assert.is_not_nil(sq)
        assert.are.equal(100, sq:getX())
        assert.are.equal(101, sq:getY())
    end)

    it("finds box to the West", function()
        local scenario = helpers.createClimbScenario({ dir = IsoDirections.W })
        local sq, box = ClimbBox.findClimbTarget(scenario.player)
        assert.is_not_nil(sq)
        assert.are.equal(99, sq:getX())
        assert.are.equal(100, sq:getY())
    end)

    -- Diagonal directions (converted to cardinal)
    it("NE direction converts to East", function()
        local scenario = helpers.createClimbScenario({ dir = IsoDirections.NE })
        local sq, box = ClimbBox.findClimbTarget(scenario.player)
        assert.is_not_nil(sq)
        assert.are.equal(101, sq:getX())
        assert.are.equal(100, sq:getY())
    end)

    it("SE direction converts to East", function()
        local scenario = helpers.createClimbScenario({ dir = IsoDirections.SE })
        local sq, box = ClimbBox.findClimbTarget(scenario.player)
        assert.is_not_nil(sq)
        assert.are.equal(101, sq:getX())
        assert.are.equal(100, sq:getY())
    end)

    it("SW direction converts to West", function()
        local scenario = helpers.createClimbScenario({ dir = IsoDirections.SW })
        local sq, box = ClimbBox.findClimbTarget(scenario.player)
        assert.is_not_nil(sq)
        assert.are.equal(99, sq:getX())
        assert.are.equal(100, sq:getY())
    end)

    it("NW direction converts to West", function()
        local scenario = helpers.createClimbScenario({ dir = IsoDirections.NW })
        local sq, box = ClimbBox.findClimbTarget(scenario.player)
        assert.is_not_nil(sq)
        assert.are.equal(99, sq:getX())
        assert.are.equal(100, sq:getY())
    end)

    -- Nil/error cases
    it("returns nil when player has no square", function()
        local player = MockFactory.createPlayer({ square = nil })
        local sq, box = ClimbBox.findClimbTarget(player)
        assert.is_nil(sq)
        assert.is_nil(box)
    end)

    it("returns nil when direction is nil", function()
        local player = MockFactory.createPlayer({
            square = MockFactory.createGridSquare(10, 10, 0),
            dir = nil,
        })
        player.getDir = function() return nil end
        local sq, box = ClimbBox.findClimbTarget(player)
        assert.is_nil(sq)
        assert.is_nil(box)
    end)

    it("returns nil when cell is nil", function()
        local player = MockFactory.createPlayer({
            square = MockFactory.createGridSquare(10, 10, 0),
            cell = nil,
        })
        local sq, box = ClimbBox.findClimbTarget(player)
        assert.is_nil(sq)
        assert.is_nil(box)
    end)

    it("returns nil when target square doesn't exist", function()
        -- Cell returns nil for the target coordinates
        local cell = MockFactory.createCell({})
        local player = MockFactory.createPlayer({
            square = MockFactory.createGridSquare(10, 10, 0),
            dir = IsoDirections.N,
            cell = cell,
        })
        local sq, box = ClimbBox.findClimbTarget(player)
        assert.is_nil(sq)
        assert.is_nil(box)
    end)

    it("returns nil when no box on target square", function()
        local targetSquare = MockFactory.createGridSquare(10, 9, 0, { objects = {} })
        local cell = MockFactory.createCell({ ["10,9,0"] = targetSquare })
        local player = MockFactory.createPlayer({
            square = MockFactory.createGridSquare(10, 10, 0),
            dir = IsoDirections.N,
            cell = cell,
        })
        local sq, box = ClimbBox.findClimbTarget(player)
        assert.is_nil(sq)
        assert.is_nil(box)
    end)

    it("finds first climbable among multiple objects", function()
        local nonBox = MockFactory.createIsoObject({
            name = "Chair",
            sprite = MockFactory.createSprite("furniture_01_01", { IsMoveAble = true }),
        })
        local box = helpers.makeBoxObject({ containerType = "crate" })

        local targetSquare = MockFactory.createGridSquare(101, 100, 0, { objects = { nonBox, box } })
        local cell = MockFactory.createCell({ ["101,100,0"] = targetSquare })
        local player = MockFactory.createPlayer({
            square = MockFactory.createGridSquare(100, 100, 0),
            dir = IsoDirections.E,
            cell = cell,
        })
        local sq, foundBox = ClimbBox.findClimbTarget(player)
        assert.is_not_nil(sq)
        assert.are.equal(box, foundBox)
    end)
end)
