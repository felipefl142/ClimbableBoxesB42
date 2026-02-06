-- Structural: validate animation XML files

local BASE = "Climbable Boxes B42/Contents/mods/ClimbableBoxes/42.13/media/AnimSets/player/actions/"

local function readFile(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local content = f:read("*a")
    f:close()
    return content
end

local function xmlGet(content, tag)
    return content:match("<" .. tag .. ">(.-)</" .. tag .. ">")
end

local function xmlGetAll(content, tag)
    local results = {}
    for match in content:gmatch("<" .. tag .. ">(.-)</" .. tag .. ">") do
        table.insert(results, match)
    end
    return results
end

local function countPattern(content, pattern)
    local count = 0
    for _ in content:gmatch(pattern) do
        count = count + 1
    end
    return count
end

describe("Animation XML validation", function()
    local xmlSpecs = {
        {
            file = "ClimbBoxStart.xml",
            name = "ClimbBoxStart",
            animName = "Bob_ClimbFence_Start",
            loop = "false",
            eventName = "ClimbBoxStart",
            eventCount = 2,
            eventTimes = {"0.30", "0.90"},
        },
        {
            file = "ClimbBoxSuccess.xml",
            name = "ClimbBoxSuccess",
            animName = "Bob_ClimbFence_Success",
            loop = "false",
            eventName = "ClimbBoxSuccess",
            eventCount = 1,
            eventTimes = {"0.95"},
        },
        {
            file = "ClimbBoxStruggle.xml",
            name = "ClimbBoxStruggle",
            animName = "Bob_ClimbFence_Struggle",
            loop = "false",
            eventName = "ClimbBoxStruggle",
            eventCount = 1,
            eventTimes = {"0.95"},
        },
        {
            file = "ClimbBoxFail.xml",
            name = "ClimbBoxFail",
            animName = "Bob_ClimbFence_Fail",
            loop = "false",
            eventName = "ClimbBoxFail",
            eventCount = 1,
            eventTimes = {"0.95"},
        },
        {
            file = "ClimbBoxEnd.xml",
            name = "ClimbBoxEnd",
            animName = "Bob_ClimbFence_End",
            loop = "false",
            eventName = "ClimbBoxEnd",
            eventCount = 1,
            eventTimes = {"0.95"},
        },
    }

    for _, spec in ipairs(xmlSpecs) do
        describe(spec.file, function()
            local content

            setup(function()
                content = readFile(BASE .. spec.file)
                assert.is_not_nil(content, "Could not read " .. spec.file)
            end)

            it("has correct m_Name", function()
                assert.are.equal(spec.name, xmlGet(content, "m_Name"))
            end)

            it("has correct m_AnimName", function()
                assert.are.equal(spec.animName, xmlGet(content, "m_AnimName"))
            end)

            it("has m_Loop set to false", function()
                assert.are.equal(spec.loop, xmlGet(content, "m_Loop"))
            end)

            it("has PerformingAction condition", function()
                local condName = content:match("<m_Conditions>.-<m_Name>(.-)</m_Name>")
                assert.are.equal("PerformingAction", condName)
            end)

            it("has correct condition value", function()
                local condValue = content:match("<m_Conditions>.-<m_Value>(.-)</m_Value>")
                assert.are.equal(spec.name, condValue)
            end)

            it("has correct event name(s)", function()
                local eventNames = xmlGetAll(content, "name")
                -- First <name> is m_Name, subsequent are event names
                -- Use m_CustomEvents context instead
                local customEventCount = countPattern(content, "<m_CustomEvents>")
                assert.are.equal(spec.eventCount, customEventCount)
            end)

            it("has correct event time(s)", function()
                local times = xmlGetAll(content, "time")
                assert.are.equal(#spec.eventTimes, #times)
                for i, expectedTime in ipairs(spec.eventTimes) do
                    assert.are.equal(expectedTime, times[i])
                end
            end)

            if spec.eventCount == 2 then
                it("ClimbBoxStart has events at 30% and 90%", function()
                    local times = xmlGetAll(content, "time")
                    assert.are.equal(2, #times)
                    assert.are.equal("0.30", times[1])
                    assert.are.equal("0.90", times[2])
                end)
            end
        end)
    end
end)
