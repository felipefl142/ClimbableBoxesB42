-- Mock PZ class factories for busted tests

local MockFactory = {}

function MockFactory.createGridSquare(x, y, z, opts)
    opts = opts or {}
    local objects = opts.objects or {}
    local square = {
        _x = x or 0,
        _y = y or 0,
        _z = z or 0,
        _hasStairs = opts.hasStairs or false,
        _objects = objects,
        _flags = opts.flags or {},
    }
    function square:getX() return self._x end
    function square:getY() return self._y end
    function square:getZ() return self._z end
    function square:HasStairs() return self._hasStairs end
    function square:has(flag) return self._flags[flag] or false end
    function square:getObjects()
        local list = {
            _items = self._objects,
        }
        function list:size() return #self._items end
        function list:get(i) return self._items[i + 1] end
        return list
    end
    return square
end

function MockFactory.createSprite(name, properties)
    properties = properties or {}
    local sprite = {
        _name = name,
        _properties = properties,
    }
    function sprite:getName() return self._name end
    function sprite:getProperties()
        local props = {
            _data = self._properties,
        }
        function props:has(key) return self._data[key] ~= nil end
        function props:get(key) return self._data[key] end
        return props
    end
    return sprite
end

function MockFactory.createIsoObject(opts)
    opts = opts or {}
    local obj = {
        _name = opts.name,
        _sprite = opts.sprite,
        _square = opts.square,
        _className = opts.className or "IsoObject",
    }
    function obj:getName() return self._name end
    function obj:getSprite() return self._sprite end
    function obj:getSquare() return self._square end
    return obj
end

function MockFactory.createBodyPart(opts)
    opts = opts or {}
    local part = {
        _fractureTime = opts.fractureTime or 0.0,
        _deepWounded = opts.deepWounded or false,
        _health = opts.health or 100.0,
        _stiffness = opts.stiffness or 0.0,
    }
    function part:getFractureTime() return self._fractureTime end
    function part:isDeepWounded() return self._deepWounded end
    function part:getHealth() return self._health end
    function part:getStiffness() return self._stiffness end
    return part
end

function MockFactory.createPlayer(opts)
    opts = opts or {}
    local player = {
        _square = opts.square,
        _dir = opts.dir or IsoDirections.N,
        _cell = opts.cell,
        _traits = opts.traits or {},
        _perkLevels = opts.perkLevels or {},
        _moodleLevels = opts.moodleLevels or {},
        _bodyParts = opts.bodyParts or {},
        _attackedBy = opts.attackedBy,
        _targetSeenCount = opts.targetSeenCount or 0,
        _hasTimedActions = opts.hasTimedActions or false,
        _className = "IsoPlayer",
    }

    function player:getSquare() return self._square end
    function player:getDir() return self._dir end
    function player:getCell() return self._cell end

    function player:hasTrait(trait)
        for _, t in ipairs(self._traits) do
            if t == trait then return true end
        end
        return false
    end

    function player:getPerkLevel(perk)
        return self._perkLevels[perk] or 0
    end

    function player:getMoodles()
        local moodles = {
            _levels = self._moodleLevels,
        }
        function moodles:getMoodleLevel(moodleType)
            return self._levels[moodleType] or 0
        end
        return moodles
    end

    function player:getBodyDamage()
        local bd = {
            _parts = self._bodyParts,
        }
        function bd:getBodyPart(partType)
            return self._parts[partType] or MockFactory.createBodyPart()
        end
        return bd
    end

    function player:getAttackedBy() return self._attackedBy end
    function player:getTargetSeenCount() return self._targetSeenCount end
    function player:hasTimedActions() return self._hasTimedActions end

    function player:getStats()
        local stats = {
            _removed = {},
        }
        function stats:remove(stat, amount)
            table.insert(self._removed, { stat = stat, amount = amount })
        end
        return stats
    end

    return player
end

function MockFactory.createCell(gridSquares)
    gridSquares = gridSquares or {}
    local cell = {
        _squares = gridSquares,
    }
    function cell:getGridSquare(x, y, z)
        local key = x .. "," .. y .. "," .. z
        return self._squares[key]
    end
    return cell
end

return MockFactory
