-- Structural: verify UI_EN.txt localization keys

local function readFile(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local content = f:read("*a")
    f:close()
    return content
end

describe("Localization (UI_EN.txt)", function()
    local content

    setup(function()
        content = readFile("Climbable Boxes B42/Contents/mods/ClimbableBoxes/42.13/media/lua/shared/Translate/EN/UI_EN.txt")
        assert.is_not_nil(content, "Could not read UI_EN.txt")
    end)

    it("has all required keys", function()
        local requiredKeys = {
            "UI_optionscreen_binding_ClimbBox_Key",
            "ContextMenu_ClimbBox",
            "Tooltip_ClimbBox",
            "ClimbableBoxes_DifficultyMode",
            "ClimbableBoxes_DifficultyMode_Tooltip",
            "ClimbableBoxes_DifficultyMode1",
            "ClimbableBoxes_DifficultyMode2",
            "ClimbableBoxes_BaseSuccessRate",
            "ClimbableBoxes_BaseSuccessRate_Tooltip",
            "ClimbableBoxes_EnduranceCostMultiplier",
            "ClimbableBoxes_EnduranceCostMultiplier_Tooltip",
            "ClimbableBoxes_EnableHealthCheck",
            "ClimbableBoxes_EnableHealthCheck_Tooltip",
        }
        for _, key in ipairs(requiredKeys) do
            assert.is_truthy(content:find(key), "Missing key: " .. key)
        end
    end)

    it("has no empty values", function()
        for line in content:gmatch("[^\n]+") do
            local key, value = line:match('(%S+)%s*=%s*"(.*)"')
            if key then
                assert.is_truthy(#value > 0, "Empty value for key: " .. key)
            end
        end
    end)

    it("DifficultyMode enum values match sandbox numValues", function()
        -- sandbox has numValues=2, so we need DifficultyMode1 and DifficultyMode2
        assert.is_truthy(content:find("ClimbableBoxes_DifficultyMode1"))
        assert.is_truthy(content:find("ClimbableBoxes_DifficultyMode2"))
    end)
end)
