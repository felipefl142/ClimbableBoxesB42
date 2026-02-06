-- Unit tests for ClimbBox.isAdjacent

local MockFactory = require("tests.mocks.pz_classes")

describe("ClimbBox.isAdjacent", function()
    local ClimbBox

    setup(function()
        resetAllMocks()
        require("ClimbBoxConfig")
        require("ClimbBoxHealth")
        require("ISClimbBox")
        require("ClimbBox")
        ClimbBox = _G.ClimbBox
    end)

    it("returns true for north adjacency", function()
        local a = MockFactory.createGridSquare(10, 10, 0)
        local b = MockFactory.createGridSquare(10, 9, 0)
        assert.is_true(ClimbBox.isAdjacent(a, b))
    end)

    it("returns true for south adjacency", function()
        local a = MockFactory.createGridSquare(10, 10, 0)
        local b = MockFactory.createGridSquare(10, 11, 0)
        assert.is_true(ClimbBox.isAdjacent(a, b))
    end)

    it("returns true for east adjacency", function()
        local a = MockFactory.createGridSquare(10, 10, 0)
        local b = MockFactory.createGridSquare(11, 10, 0)
        assert.is_true(ClimbBox.isAdjacent(a, b))
    end)

    it("returns true for west adjacency", function()
        local a = MockFactory.createGridSquare(10, 10, 0)
        local b = MockFactory.createGridSquare(9, 10, 0)
        assert.is_true(ClimbBox.isAdjacent(a, b))
    end)

    it("returns false for diagonal squares", function()
        local a = MockFactory.createGridSquare(10, 10, 0)
        local b = MockFactory.createGridSquare(11, 11, 0)
        assert.is_false(ClimbBox.isAdjacent(a, b))
    end)

    it("returns false for same square", function()
        local a = MockFactory.createGridSquare(10, 10, 0)
        local b = MockFactory.createGridSquare(10, 10, 0)
        assert.is_false(ClimbBox.isAdjacent(a, b))
    end)

    it("returns false for different Z levels", function()
        local a = MockFactory.createGridSquare(10, 10, 0)
        local b = MockFactory.createGridSquare(10, 11, 1)
        assert.is_false(ClimbBox.isAdjacent(a, b))
    end)

    it("returns false for far-away squares", function()
        local a = MockFactory.createGridSquare(10, 10, 0)
        local b = MockFactory.createGridSquare(15, 10, 0)
        assert.is_false(ClimbBox.isAdjacent(a, b))
    end)

    it("returns false for nil first square", function()
        local b = MockFactory.createGridSquare(10, 10, 0)
        assert.is_false(ClimbBox.isAdjacent(nil, b))
    end)

    it("returns false for nil second square", function()
        local a = MockFactory.createGridSquare(10, 10, 0)
        assert.is_false(ClimbBox.isAdjacent(a, nil))
    end)

    it("returns false for both nil", function()
        assert.is_false(ClimbBox.isAdjacent(nil, nil))
    end)

    it("is symmetric", function()
        local a = MockFactory.createGridSquare(10, 10, 0)
        local b = MockFactory.createGridSquare(11, 10, 0)
        assert.are.equal(ClimbBox.isAdjacent(a, b), ClimbBox.isAdjacent(b, a))
    end)
end)
