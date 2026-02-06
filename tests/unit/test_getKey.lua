-- Unit tests for ClimbBox.getKey

describe("ClimbBox.getKey", function()
    local ClimbBox

    setup(function()
        resetAllMocks()
        require("ClimbBoxConfig")
        ClimbBox = _G.ClimbBox
    end)

    before_each(function()
        _G._keyDownState = {}
        _G._isClientVal = false
        _G._isServerVal = false
        ClimbBox.keyBind = nil
    end)

    describe("with ModOptions keybind", function()
        it("returns true when keybind is pressed", function()
            ClimbBox.keyBind = { isPressed = function() return true end }
            assert.is_true(ClimbBox.getKey())
        end)

        it("returns false when keybind is not pressed", function()
            ClimbBox.keyBind = { isPressed = function() return false end }
            assert.is_false(ClimbBox.getKey())
        end)
    end)

    describe("with fallback isKeyDown", function()
        it("returns true on client when key pressed", function()
            _G._isClientVal = true
            _G._keyDownState[Keyboard.KEY_G] = true
            assert.is_true(ClimbBox.getKey())
        end)

        it("returns false on client when key not pressed", function()
            _G._isClientVal = true
            _G._keyDownState[Keyboard.KEY_G] = false
            assert.is_false(ClimbBox.getKey())
        end)

        it("returns false on dedicated server", function()
            _G._isServerVal = true
            _G._isClientVal = false
            assert.is_false(ClimbBox.getKey())
        end)

        it("returns true in single-player (not server, not client) when key pressed", function()
            _G._isServerVal = false
            _G._isClientVal = false
            _G._keyDownState[Keyboard.KEY_G] = true
            assert.is_true(ClimbBox.getKey())
        end)
    end)
end)
