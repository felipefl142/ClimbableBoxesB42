-- Unit tests for ClimbBox.isHealthInhibitingClimb

local MockFactory = require("tests.mocks.pz_classes")
local helpers = require("tests.mocks.mock_helpers")

describe("ClimbBox.isHealthInhibitingClimb", function()
    local ClimbBox

    setup(function()
        resetAllMocks()
        require("ClimbBoxConfig")
        require("ClimbBoxHealth")
        require("ISClimbBox")
        require("ClimbBox")
        ClimbBox = _G.ClimbBox
    end)

    it("returns false when all body parts are healthy", function()
        local player = MockFactory.createPlayer({ bodyParts = helpers.allHealthyParts() })
        assert.is_false(ClimbBox.isHealthInhibitingClimb(player))
    end)

    it("returns false when bodyDamage is nil", function()
        local player = MockFactory.createPlayer({})
        player.getBodyDamage = function() return nil end
        assert.is_false(ClimbBox.isHealthInhibitingClimb(player))
    end)

    -- Fracture
    it("returns true for fracture in upper body", function()
        local player = helpers.createPlayerWithInjury(BodyPartType.Hand_L, "fracture")
        assert.is_true(ClimbBox.isHealthInhibitingClimb(player))
    end)

    -- Deep wound
    it("returns true for deep wound in upper body", function()
        local player = helpers.createPlayerWithInjury(BodyPartType.ForeArm_R, "deepWound")
        assert.is_true(ClimbBox.isHealthInhibitingClimb(player))
    end)

    -- Low health
    it("returns true when health < 50", function()
        local player = helpers.createPlayerWithInjury(BodyPartType.Torso_Upper, "lowHealth")
        assert.is_true(ClimbBox.isHealthInhibitingClimb(player))
    end)

    -- Health boundary
    it("returns false when health is exactly 50", function()
        local parts = helpers.allHealthyParts()
        parts[BodyPartType.Torso_Upper] = MockFactory.createBodyPart({ health = 50.0 })
        local player = MockFactory.createPlayer({ bodyParts = parts })
        assert.is_false(ClimbBox.isHealthInhibitingClimb(player))
    end)

    -- High stiffness
    it("returns true when stiffness >= 50", function()
        local player = helpers.createPlayerWithInjury(BodyPartType.UpperArm_L, "stiffness")
        assert.is_true(ClimbBox.isHealthInhibitingClimb(player))
    end)

    -- Stiffness boundary
    it("returns false when stiffness is 49.9", function()
        local parts = helpers.allHealthyParts()
        parts[BodyPartType.UpperArm_L] = MockFactory.createBodyPart({ stiffness = 49.9 })
        local player = MockFactory.createPlayer({ bodyParts = parts })
        assert.is_false(ClimbBox.isHealthInhibitingClimb(player))
    end)

    -- All upper body parts checked
    describe("checks all upper body parts", function()
        local upperParts = {
            "Hand_L", "Hand_R", "ForeArm_L", "ForeArm_R",
            "UpperArm_L", "UpperArm_R", "Torso_Upper", "Torso_Lower",
        }
        for _, partName in ipairs(upperParts) do
            it("detects injury on " .. partName, function()
                local player = helpers.createPlayerWithInjury(BodyPartType[partName], "fracture")
                assert.is_true(ClimbBox.isHealthInhibitingClimb(player))
            end)
        end
    end)

    -- All leg parts checked
    describe("checks all leg parts", function()
        local legParts = {
            "UpperLeg_L", "UpperLeg_R", "LowerLeg_L", "LowerLeg_R",
            "Foot_L", "Foot_R",
        }
        for _, partName in ipairs(legParts) do
            it("detects injury on " .. partName, function()
                local player = helpers.createPlayerWithInjury(BodyPartType[partName], "fracture")
                assert.is_true(ClimbBox.isHealthInhibitingClimb(player))
            end)
        end
    end)

    -- Unchecked parts
    it("ignores injury on Head (not in checked parts)", function()
        local player = helpers.createPlayerWithInjury(BodyPartType.Head, "fracture")
        assert.is_false(ClimbBox.isHealthInhibitingClimb(player))
    end)
end)
