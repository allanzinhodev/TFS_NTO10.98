-- Attack Animation Script using onAttack event
-- This event fires every time the player lands a physical attack

local config = {
	attackOutfit = {lookType = 24, lookHead = 0, lookBody = 0, lookLegs = 0, lookFeet = 0, lookAddons = 0},
	duration = 700, -- milliseconds
	maxDistance = 1, -- only trigger when adjacent to target
	lockDirection = true -- turn to face the target
}

local animationData = {}

-- Calculate direction from one position to another
local function getDirectionTo(fromPos, toPos)
	local dx = toPos.x - fromPos.x
	local dy = toPos.y - fromPos.y
	
	if math.abs(dx) > math.abs(dy) then
		if dx > 0 then
			return DIRECTION_EAST
		else
			return DIRECTION_WEST
		end
	else
		if dy > 0 then
			return DIRECTION_SOUTH
		else
			return DIRECTION_NORTH
		end
	end
end

-- Calculate distance between two positions
local function getDistanceBetween(fromPos, toPos)
	local dx = math.abs(fromPos.x - toPos.x)
	local dy = math.abs(fromPos.y - toPos.y)
	return math.max(dx, dy)
end

function onAttack(creature, target)
	print("[LUA onAttack] Called! Creature: " .. (creature and creature:getName() or "nil") .. " Target: " .. (target and target:getName() or "nil"))
	
	if not creature or not target then
		return
	end
	
	local playerId = creature:getId()
	local creaturePos = creature:getPosition()
	local targetPos = target:getPosition()
	
	-- Check if on same floor
	if creaturePos.z ~= targetPos.z then
		return
	end
	
	-- Check distance
	local distance = getDistanceBetween(creaturePos, targetPos)
	if distance > config.maxDistance then
		return
	end
	
	-- Check if already in animation
	if animationData[playerId] then
		return
	end
	
	-- Save original data
	animationData[playerId] = {
		outfit = creature:getOutfit(),
		direction = creature:getDirection()
	}
	
	-- Turn to face target
	if config.lockDirection then
		local directionToTarget = getDirectionTo(creaturePos, targetPos)
		creature:setDirection(directionToTarget)
	end
	
	-- Apply attack outfit (keep mount)
	local newOutfit = {
		lookType = config.attackOutfit.lookType,
		lookHead = config.attackOutfit.lookHead,
		lookBody = config.attackOutfit.lookBody,
		lookLegs = config.attackOutfit.lookLegs,
		lookFeet = config.attackOutfit.lookFeet,
		lookAddons = config.attackOutfit.lookAddons,
		lookMount = animationData[playerId].outfit.lookMount or 0
	}
	creature:setOutfit(newOutfit)
	
	-- Schedule revert
	addEvent(function(pid)
		local p = Player(pid)
		if p then
			local data = animationData[pid]
			if data then
				p:setOutfit(data.outfit)
			end
		end
		animationData[pid] = nil
	end, config.duration, playerId)
end
