local PrivateCallbacks = {}

local function setSpeed(self, value, old)	
	local character = self.entity.Character
	if not character then return end

	local humanoid = character.Humanoid
	if not humanoid then return end
	
	local speedBase = self:getPrivateRaw("moveSpeedBase")
	local multiplier = self:getPrivateRaw("moveSpeedMult")
	
	local base = 14
	humanoid.WalkSpeed = (base + speedBase) * multiplier
end

PrivateCallbacks.moveSpeedMult = function(self, value, old)
	setSpeed(self, value, old)
end

PrivateCallbacks.moveSpeedBase = function(self, value, old)
	setSpeed(self, value, old)
end

return PrivateCallbacks
