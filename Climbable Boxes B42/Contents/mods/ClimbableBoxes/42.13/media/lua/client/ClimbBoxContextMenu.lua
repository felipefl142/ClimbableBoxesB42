require "ClimbBox"
require "ClimbBoxConfig"
require "ClimbBoxHealth"

local function onClimbBox(player, targetSquare, targetBox)
    ISTimedActionQueue.add(ISClimbBox:new(player, targetSquare, targetBox))
end

local function onFillWorldObjectContextMenu(playerNum, context, worldobjects, test)
    print("[ClimbBox] Context menu called, objects: " .. #worldobjects)
    local player = getSpecificPlayer(playerNum)
    if not player then return end
    if player:hasTimedActions() then return end

    for _, v in ipairs(worldobjects) do
        local obj = v
        -- Handle wrapped objects
        if type(v) == "table" and v.object then
            obj = v.object
        end
        print("[ClimbBox] Checking object: " .. tostring(obj))
        if obj and obj.getSprite then
            print("[ClimbBox] Object has sprite: " .. tostring(obj:getSprite()))
        end
        if ClimbBox.isClimbableBox(obj) then
            print("[ClimbBox] Found climbable box!")
            local square = obj:getSquare()
            if square then
                local pSquare = player:getSquare()
                if pSquare and ClimbBox.isAdjacent(pSquare, square) then
                    -- Health check (if enabled)
                    if SandboxVars.ClimbableBoxes.EnableHealthCheck then
                        if ClimbBox.isHealthInhibitingClimb(player) then
                            break
                        end
                    end

                    context:addOption(
                        getText("ContextMenu_ClimbBox"),
                        player, onClimbBox, square, obj
                    )
                    break
                end
            end
        end
    end
end

Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)
