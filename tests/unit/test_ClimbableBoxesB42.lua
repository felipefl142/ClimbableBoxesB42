-- Unit tests for ClimbableBoxesB42 module metadata

describe("ClimbableBoxesB42 module", function()
    local mod

    setup(function()
        resetAllMocks()
        -- Load the module directly (it's a pure return table)
        mod = dofile("Climbable Boxes B42/Contents/mods/ClimbableBoxes/42.13/media/lua/client/ClimbableBoxesB42.lua")
    end)

    it("returns a table", function()
        assert.is_table(mod)
    end)

    it("has a name field", function()
        assert.are.equal("Climbable Boxes (B42)", mod.name)
    end)

    it("has an id field", function()
        assert.are.equal("ClimbableBoxesB42", mod.id)
    end)

    it("has a description field", function()
        assert.is_string(mod.description)
        assert.is_truthy(#mod.description > 0)
    end)
end)
