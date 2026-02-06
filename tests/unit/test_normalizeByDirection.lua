-- Unit tests for ClimbBox.normalizeByDirection

describe("ClimbBox.normalizeByDirection", function()
    local ClimbBox

    setup(function()
        resetAllMocks()
        require("ClimbBoxConfig")
        require("ClimbBoxHealth")
        require("ISClimbBox")
        require("ClimbBox")
        ClimbBox = _G.ClimbBox
    end)

    it("returns 1 for positive values", function()
        assert.are.equal(1, ClimbBox.normalizeByDirection(5))
        assert.are.equal(1, ClimbBox.normalizeByDirection(0.1))
        assert.are.equal(1, ClimbBox.normalizeByDirection(1000))
    end)

    it("returns -1 for negative values", function()
        assert.are.equal(-1, ClimbBox.normalizeByDirection(-5))
        assert.are.equal(-1, ClimbBox.normalizeByDirection(-0.1))
        assert.are.equal(-1, ClimbBox.normalizeByDirection(-1000))
    end)

    it("returns 0 for zero", function()
        assert.are.equal(0, ClimbBox.normalizeByDirection(0))
    end)

    it("returns 0 for negative zero", function()
        assert.are.equal(0, ClimbBox.normalizeByDirection(-0))
    end)

    it("handles tiny floats correctly", function()
        assert.are.equal(1, ClimbBox.normalizeByDirection(0.0001))
        assert.are.equal(-1, ClimbBox.normalizeByDirection(-0.0001))
    end)
end)
