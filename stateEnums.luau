local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Animations = ReplicatedStorage.Assets.Animations
local Modules = ServerStorage.Modules

local AnimationHandler = require(ReplicatedStorage.Modules.Shared.AnimationHandler)
local BuffController = require(Modules.Controllers.BuffController)
local CombatHandler = require(Modules.Handlers.CombatHandler)
local BuffEffects = require(Modules.Misc.BuffEffects)

local StateEnums = {}
StateEnums.__universalTransitions = {
	Stunned = { priority = 100, reason = "CC" },
	Dead    = { priority = 200, reason = "Fatal" },
}
StateEnums.__universalActions = {
	stun = function(self, duration)
		self:pushForced("Stunned", duration)
	end,
	interrupt = function(self)
		local activeState = self.activeState
		if activeState and activeState.tags and activeState.tags.Interruptible then self:pop() end
	end,
	cancel = function(self)
		local activeState = self.activeState
		if activeState and activeState.tags and activeState.tags.Cancellable then self:pop() end
	end,
	hit = function(self, attackData)
		self.data.public.health = math.max(self.data._public.health - attackData.damage, 0)
		self.data:setPrivateRaw("combo", 1)
		
		self:trigger("stun", attackData.stun)
	end,
}

StateEnums.Idle = {
	transitions = {"Attack", "Stunned", "Sprint"},
	tags = {Movement = true},
	
	enter = function(self) end,
	update = function(self, dt) 
		self.data.public.stamina = math.min(self.data._public.stamina + (dt * 16), self.data._public.maxStamina)
	end,
	lightAttack = function(self)
		self:push("Attack", "lightAttack")
	end,
}

StateEnums.Sprint = {
	transitions = { "Idle", "Attack" },
	tags = {Movement=true, Interruptible=true},
	
	enter = function(self)	
		local char = self.entity.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not hum then return end

		self.cache.humanoid = hum
		self.buffs:apply(BuffEffects.Sprint)

		self.cache.runAnimId = Animations.Movement.Running.AnimationId
		self.cache.running = false
	end,
	update = function(self, dt)
		local hum = self.cache.humanoid
		if not hum or hum.Parent == nil then return end

		local moving = hum.MoveDirection.Magnitude > 0
		if moving and not self.cache.running then
			AnimationHandler.loadAnimation(hum.Parent, "Movement", self.cache.runAnimId)
			self.cache.running = true
		elseif not moving and self.cache.running then
			AnimationHandler.stopAnimation(hum.Parent, "Movement", self.cache.runAnimId)
			self.cache.running = false
		end

		local stamina = self.data:getPublicRaw("stamina")
		local maxStamina = self.data:getPublicRaw("maxStamina")

		if moving then
			stamina = math.max(stamina - dt * 20, 0)
			self.data.public.stamina = stamina
			if stamina <= 0 then
				self.buffs:apply(BuffEffects.Exhaust)
				self:pop()
			end
		else
			self.data.public.stamina = math.clamp(stamina + dt * 12, 0, maxStamina)
		end
	end,
	exit = function(self)
		local char = self.entity.Character
		if char and self.cache.runAnimId then
			AnimationHandler.stopAnimation(char, "Movement", self._runAnimId)
		end
		
		self.buffs:remove("sprint")
		self.cache.humanoid, self.cache.running, self.cache.runAnimId = nil, nil, nil
	end,
}

StateEnums.Attack = { -- Weapon attacks
	tags = {Attack = true, Interruptible = true, cantTrigger = true},
	enter = function(self, action)		
		local char = self.entity.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not hum then return end
		
		if self.activeState and self.activeState[action] then
			self.activeState[action](self)
		end
	end,
	exit = function(self) end,
	lightAttack = function(self)
		CombatHandler.handleWeaponAttack("lightAttack", self)
	end,
	heavyAttack = function(self)
		CombatHandler.handleWeaponAttack("heavyAttack", self)
	end,
}

StateEnums.Dash = {
	enter = function(self)
		print("Dash Enter")
	end,
	exit = function(self) end,
}

StateEnums.Stunned = {
	enter = function(self, duration)
		task.delay(duration, function() -- make it update stun if already exists, maybe even with buffs.
			self:pop()
		end)
	end,
	update = function(self, dt) end,
}

return StateEnums
