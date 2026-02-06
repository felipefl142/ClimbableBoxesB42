-- Structural: verify all expected files exist

local lfs = require("lfs")

local function fileExists(path)
    local attr = lfs.attributes(path)
    return attr ~= nil and attr.mode == "file"
end

local BASE = "Climbable Boxes B42/Contents/mods/ClimbableBoxes/42.13/media/"

describe("File structure", function()
    it("all 6 Lua files exist", function()
        local luaFiles = {
            "lua/client/ClimbBoxConfig.lua",
            "lua/client/ClimbBoxHealth.lua",
            "lua/client/ClimbBox.lua",
            "lua/client/ClimbBoxContextMenu.lua",
            "lua/client/ClimbableBoxesB42.lua",
            "lua/shared/Actions/ISClimbBox.lua",
        }
        for _, f in ipairs(luaFiles) do
            assert.is_true(fileExists(BASE .. f), "Missing: " .. f)
        end
    end)

    it("all 5 animation XMLs exist", function()
        local xmlFiles = {
            "AnimSets/player/actions/ClimbBoxStart.xml",
            "AnimSets/player/actions/ClimbBoxSuccess.xml",
            "AnimSets/player/actions/ClimbBoxStruggle.xml",
            "AnimSets/player/actions/ClimbBoxFail.xml",
            "AnimSets/player/actions/ClimbBoxEnd.xml",
        }
        for _, f in ipairs(xmlFiles) do
            assert.is_true(fileExists(BASE .. f), "Missing: " .. f)
        end
    end)

    it("sandbox-options.txt exists", function()
        assert.is_true(fileExists(BASE .. "sandbox-options.txt"))
    end)

    it("UI_EN.txt exists", function()
        assert.is_true(fileExists(BASE .. "lua/shared/Translate/EN/UI_EN.txt"))
    end)
end)
