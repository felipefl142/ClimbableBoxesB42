ClimbBox = ClimbBox or {}
ClimbBox.defaultKey = Keyboard.KEY_G  -- Fallback default key
ClimbBox.Verbose = true  -- Enable debug output

print("[ClimbBox] Loading keybind config...")
print("[ClimbBox] ModOptions available: " .. tostring(ModOptions ~= nil))
print("[ClimbBox] Keyboard.KEY_G value: " .. tostring(Keyboard.KEY_G))

-- Try to use ModOptions if available (requires PZAPI)
if ModOptions and ModOptions.getInstance then
    local success, modSettings = pcall(require, "ClimbableBoxesB42")
    if success then
        local settings = ModOptions:getInstance(modSettings)
        ClimbBox.keyBind = settings:addKeyBind(
            "0",
            getText("UI_optionscreen_binding_ClimbBox_Key"),
            ClimbBox.defaultKey
        )
        print("[ClimbBox] Keybind registered via ModOptions (PZAPI)")
    else
        print("[ClimbBox] Failed to load ClimbableBoxesB42 module: " .. tostring(modSettings))
    end
else
    print("[ClimbBox] ModOptions not available (PZAPI not installed), using fallback keybind")
end

-- Get key state with fallback to direct keyboard check
function ClimbBox.getKey()
    -- Try ModOptions keybind first
    if ClimbBox.keyBind then
        local pressed = ClimbBox.keyBind:isPressed()
        if pressed and ClimbBox.Verbose then
            print("[ClimbBox] Key detected via ModOptions keybind")
        end
        return pressed
    end

    -- Fallback: direct keyboard check using PZ's isKeyDown
    if isClient() or not isServer() then
        local pressed = isKeyDown(ClimbBox.defaultKey)
        if pressed and ClimbBox.Verbose then
            print("[ClimbBox] Key detected via fallback isKeyDown()")
        end
        return pressed
    end

    return false
end
