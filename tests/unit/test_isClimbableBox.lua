-- Unit tests for ClimbBox.isClimbableBox

local MockFactory = require("tests.mocks.pz_classes")
local helpers = require("tests.mocks.mock_helpers")

describe("ClimbBox.isClimbableBox", function()
    local ClimbBox

    setup(function()
        resetAllMocks()
        require("ClimbBoxConfig")
        require("ClimbBoxHealth")
        require("ISClimbBox")
        require("ClimbBox")
        ClimbBox = _G.ClimbBox
    end)

    -- ContainerType detection (tier 1)
    describe("ContainerType detection", function()
        it("matches 'crate' container type", function()
            local obj = helpers.makeBoxObject({ containerType = "crate" })
            assert.is_true(ClimbBox.isClimbableBox(obj))
        end)

        it("matches 'smallbox' container type", function()
            local obj = helpers.makeBoxObject({ containerType = "smallbox" })
            assert.is_true(ClimbBox.isClimbableBox(obj))
        end)

        it("matches 'cardboardbox' container type", function()
            local obj = helpers.makeBoxObject({ containerType = "cardboardbox" })
            assert.is_true(ClimbBox.isClimbableBox(obj))
        end)

        it("matches container type case-insensitively", function()
            local obj = helpers.makeBoxObject({ containerType = "CRATE" })
            assert.is_true(ClimbBox.isClimbableBox(obj))
        end)
    end)

    -- Sprite name detection (tier 2)
    describe("sprite name detection", function()
        it("matches carpentry_01_16", function()
            local obj = helpers.makeBoxObject({
                spriteName = "carpentry_01_16",
                spriteProps = { IsMoveAble = true },
            })
            assert.is_true(ClimbBox.isClimbableBox(obj))
        end)

        it("matches carpentry_01_17", function()
            local obj = helpers.makeBoxObject({
                spriteName = "carpentry_01_17",
                spriteProps = { IsMoveAble = true },
            })
            assert.is_true(ClimbBox.isClimbableBox(obj))
        end)

        it("matches carpentry_01_18", function()
            local obj = helpers.makeBoxObject({
                spriteName = "carpentry_01_18",
                spriteProps = { IsMoveAble = true },
            })
            assert.is_true(ClimbBox.isClimbableBox(obj))
        end)

        it("matches carpentry_01_19", function()
            local obj = helpers.makeBoxObject({
                spriteName = "carpentry_01_19",
                spriteProps = { IsMoveAble = true },
            })
            assert.is_true(ClimbBox.isClimbableBox(obj))
        end)

        it("does not match carpentry_01_20 (out of range)", function()
            local obj = helpers.makeBoxObject({
                name = "Table",
                spriteName = "carpentry_01_20",
                spriteProps = { IsMoveAble = true },
            })
            assert.is_false(ClimbBox.isClimbableBox(obj))
        end)

        it("matches sprite name case-insensitively", function()
            local obj = helpers.makeBoxObject({
                spriteName = "CARPENTRY_01_16",
                spriteProps = { IsMoveAble = true },
            })
            assert.is_true(ClimbBox.isClimbableBox(obj))
        end)
    end)

    -- Object name detection (tier 3)
    describe("object name detection", function()
        it("matches 'box' in name", function()
            local obj = helpers.makeBoxObject({
                name = "Wooden Box",
                spriteName = "furniture_01_01",
                spriteProps = { IsMoveAble = true },
            })
            assert.is_true(ClimbBox.isClimbableBox(obj))
        end)

        it("matches 'crate' in name", function()
            local obj = helpers.makeBoxObject({
                name = "Supply Crate",
                spriteName = "furniture_01_01",
                spriteProps = { IsMoveAble = true },
            })
            assert.is_true(ClimbBox.isClimbableBox(obj))
        end)

        it("matches object name case-insensitively", function()
            local obj = helpers.makeBoxObject({
                name = "BIG BOX",
                spriteName = "furniture_01_01",
                spriteProps = { IsMoveAble = true },
            })
            assert.is_true(ClimbBox.isClimbableBox(obj))
        end)
    end)

    -- Guard conditions
    describe("guard conditions", function()
        it("returns false for nil object", function()
            assert.is_false(ClimbBox.isClimbableBox(nil))
        end)

        it("returns false for IsoWorldInventoryObject", function()
            local obj = helpers.makeBoxObject({ className = "IsoWorldInventoryObject" })
            assert.is_false(ClimbBox.isClimbableBox(obj))
        end)

        it("returns false when object has no sprite", function()
            local obj = MockFactory.createIsoObject({ name = "Crate" })
            -- sprite is nil
            assert.is_false(ClimbBox.isClimbableBox(obj))
        end)

        it("returns false when sprite has no properties", function()
            local sprite = { getName = function() return "test" end, getProperties = function() return nil end }
            local obj = MockFactory.createIsoObject({ name = "Crate", sprite = sprite })
            assert.is_false(ClimbBox.isClimbableBox(obj))
        end)

        it("returns false when IsMoveAble is not set", function()
            local obj = helpers.makeBoxObject({
                spriteProps = { ContainerType = "crate" },
                -- IsMoveAble not included
            })
            assert.is_false(ClimbBox.isClimbableBox(obj))
        end)

        it("returns false for non-matching object", function()
            local obj = helpers.makeBoxObject({
                name = "Table",
                spriteName = "furniture_01_01",
                spriteProps = { IsMoveAble = true },
            })
            assert.is_false(ClimbBox.isClimbableBox(obj))
        end)
    end)
end)
