-- Structural: cross-file consistency checks

local function readFile(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local content = f:read("*a")
    f:close()
    return content
end

local BASE = "Climbable Boxes B42/Contents/mods/ClimbableBoxes/42.13/media/"
local XML_BASE = BASE .. "AnimSets/player/actions/"

describe("Config consistency", function()
    local luaClimbBox, luaISClimbBox, sandboxOpts, uiEN

    setup(function()
        luaClimbBox = readFile(BASE .. "lua/client/ClimbBox.lua")
        luaISClimbBox = readFile(BASE .. "lua/shared/Actions/ISClimbBox.lua")
        sandboxOpts = readFile(BASE .. "sandbox-options.txt")
        uiEN = readFile(BASE .. "lua/shared/Translate/EN/UI_EN.txt")
    end)

    it("animation names in ISClimbBox match XML file names", function()
        local animNames = {
            "ClimbBoxStart", "ClimbBoxSuccess", "ClimbBoxStruggle",
            "ClimbBoxFail", "ClimbBoxEnd",
        }
        for _, name in ipairs(animNames) do
            -- Check ISClimbBox references the anim name
            assert.is_truthy(luaISClimbBox:find('"' .. name .. '"'), "ISClimbBox missing: " .. name)

            -- Check corresponding XML exists and has correct m_Name
            local xmlContent = readFile(XML_BASE .. name .. ".xml")
            assert.is_not_nil(xmlContent, "XML missing: " .. name .. ".xml")
            assert.is_truthy(
                xmlContent:find("<m_Name>" .. name .. "</m_Name>"),
                "XML m_Name mismatch: " .. name
            )
        end
    end)

    it("sandbox option keys match Lua references", function()
        local sandboxKeys = {
            "DifficultyMode", "BaseSuccessRate",
            "EnduranceCostMultiplier", "EnableHealthCheck",
        }
        for _, key in ipairs(sandboxKeys) do
            -- Sandbox file defines it
            assert.is_truthy(
                sandboxOpts:find("option ClimbableBoxes%." .. key),
                "Sandbox missing: " .. key
            )

            -- Lua references it via SandboxVars.ClimbableBoxes.Key
            local luaPattern = "SandboxVars%.ClimbableBoxes%." .. key
            local found = luaISClimbBox:find(luaPattern) or luaClimbBox:find(luaPattern)
            assert.is_truthy(found, "Lua not referencing: " .. key)
        end
    end)

    it("getText keys in Lua match translation file", function()
        -- Find all getText calls in Lua files
        local luaContextMenu = readFile(BASE .. "lua/client/ClimbBoxContextMenu.lua")
        local luaConfig = readFile(BASE .. "lua/client/ClimbBoxConfig.lua")

        local allLua = (luaClimbBox or "") .. (luaISClimbBox or "") ..
                       (luaContextMenu or "") .. (luaConfig or "")

        for key in allLua:gmatch('getText%("([^"]+)"%)') do
            assert.is_truthy(
                uiEN:find(key),
                "getText key not in UI_EN.txt: " .. key
            )
        end
    end)

    it("mod.info id is consistent", function()
        local modInfo42_13 = readFile("Climbable Boxes B42/Contents/mods/ClimbableBoxes/42.13/mod.info")
        if modInfo42_13 then
            assert.is_truthy(modInfo42_13:find("id="))
        end

        -- Also check the root mod.info
        local modInfoRoot = readFile("Climbable Boxes B42/mod.info")
        if modInfoRoot then
            assert.is_truthy(modInfoRoot:find("id="))
        end
    end)

    it("require statements reference real files", function()
        -- Check that require paths in ClimbBox.lua resolve to actual files
        local requires = {
            { pattern = 'require "ClimbBoxConfig"', file = "lua/client/ClimbBoxConfig.lua" },
            { pattern = 'require "ClimbBoxHealth"', file = "lua/client/ClimbBoxHealth.lua" },
            { pattern = 'require "Actions/ISClimbBox"', file = "lua/shared/Actions/ISClimbBox.lua" },
        }

        local lfs = require("lfs")
        for _, req in ipairs(requires) do
            assert.is_truthy(luaClimbBox:find(req.pattern, 1, true), "Missing require: " .. req.pattern)
            local attr = lfs.attributes(BASE .. req.file)
            assert.is_not_nil(attr, "Required file missing: " .. req.file)
        end
    end)
end)
