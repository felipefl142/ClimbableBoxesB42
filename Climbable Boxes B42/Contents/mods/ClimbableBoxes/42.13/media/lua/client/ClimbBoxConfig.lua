ClimbBox = ClimbBox or {}
ClimbBox.defaultKey = Keyboard.KEY_G  -- Fallback default key
ClimbBox.Verbose = true  -- Enable debug output
ClimbBox.wasKeyDown = false  -- For edge detection (key-down only, not key-held)

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

-- Get key state with edge detection (only returns true on key-DOWN, not key-HELD)
function ClimbBox.getKey()
    local isDown = false

    -- Try ModOptions keybind first
    if ClimbBox.keyBind then
        isDown = ClimbBox.keyBind:isPressed()
    elseif isClient() or not isServer() then
        -- Fallback: direct keyboard check using PZ's isKeyDown
        isDown = isKeyDown(ClimbBox.defaultKey)
    end

    -- Edge detection: only trigger on rising edge (not-pressed -> pressed)
    if isDown and not ClimbBox.wasKeyDown then
        ClimbBox.wasKeyDown = true
        if ClimbBox.Verbose then
            print("[ClimbBox] Key pressed (edge detected)")
        end
        return true
    elseif not isDown then
        ClimbBox.wasKeyDown = false
    end

    return false
end
