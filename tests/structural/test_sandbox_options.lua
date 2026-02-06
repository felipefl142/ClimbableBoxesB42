-- Structural: verify sandbox-options.txt has all 4 options with correct types

local function readFile(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local content = f:read("*a")
    f:close()
    return content
end

describe("Sandbox options", function()
    local content

    setup(function()
        content = readFile("Climbable Boxes B42/Contents/mods/ClimbableBoxes/42.13/media/sandbox-options.txt")
        assert.is_not_nil(content, "Could not read sandbox-options.txt")
    end)

    it("defines DifficultyMode as enum with default 1", function()
        assert.is_truthy(content:find("option ClimbableBoxes%.DifficultyMode"))
        assert.is_truthy(content:find("type = enum"))
        assert.is_truthy(content:find("default = 1,"))
    end)

    it("defines BaseSuccessRate as integer with default 90", function()
        assert.is_truthy(content:find("option ClimbableBoxes%.BaseSuccessRate"))
        assert.is_truthy(content:find("type = integer"))
        assert.is_truthy(content:find("default = 90,"))
    end)

    it("defines EnduranceCostMultiplier as double with default 1.0", function()
        assert.is_truthy(content:find("option ClimbableBoxes%.EnduranceCostMultiplier"))
        assert.is_truthy(content:find("type = double"))
        assert.is_truthy(content:find("default = 1%.0,"))
    end)

    it("defines EnableHealthCheck as boolean with default true", function()
        assert.is_truthy(content:find("option ClimbableBoxes%.EnableHealthCheck"))
        assert.is_truthy(content:find("type = boolean"))
        assert.is_truthy(content:find("default = true,"))
    end)

    it("all options have translation keys", function()
        local options = { "DifficultyMode", "BaseSuccessRate", "EnduranceCostMultiplier", "EnableHealthCheck" }
        for _, opt in ipairs(options) do
            assert.is_truthy(
                content:find("translation = ClimbableBoxes_" .. opt),
                "Missing translation for " .. opt
            )
        end
    end)
end)
