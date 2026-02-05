ClimbBox = ClimbBox or {}

if ModOptions and ModOptions.getInstance then
    local settings = ModOptions:getInstance(require "ClimbableBoxesB42")
    ClimbBox.keyBind = settings:addKeyBind(
        "0",
        getText("UI_optionscreen_binding_ClimbBox_Key"),
        Keyboard.KEY_G
    )
end

function ClimbBox.getKey()
    if ClimbBox.keyBind then
        return ClimbBox.keyBind:isPressed()
    end
    return false
end
