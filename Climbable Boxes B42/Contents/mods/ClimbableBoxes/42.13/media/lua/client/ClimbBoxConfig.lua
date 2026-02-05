ClimbBox = ClimbBox or {}

print("[ClimbBox] Loading keybind config...")
print("[ClimbBox] ModOptions available: " .. tostring(ModOptions ~= nil))

if ModOptions and ModOptions.getInstance then
    local modSettings = require "ClimbableBoxesB42"
    local settings = ModOptions:getInstance(modSettings)
    ClimbBox.keyBind = settings:addKeyBind(
        "0",
        getText("UI_optionscreen_binding_ClimbBox_Key"),
        Keyboard.KEY_G
    )
    print("[ClimbBox] Keybind registered via ModOptions")
else
    print("[ClimbBox] ModOptions not available, keybind disabled")
end

function ClimbBox.getKey()
    if ClimbBox.keyBind then
        return ClimbBox.keyBind:isPressed()
    end
    return false
end
