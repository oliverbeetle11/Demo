local BuffController = {}
BuffController.__index = BuffController

local function now() return os.clock() end

local function passesFilters(trigger, context)
	if trigger.when then
		for k, v in pairs(trigger.when) do
			if context[k] ~= v then return false end
		end
	end
	if trigger.requireTags then
		local t = context.tags or {}
		for tag, _ in pairs(trigger.requireTags) do if not t[tag] then return false end end
	end
	if trigger.forbidTags then
		local t = context.tags or {}
		for tag, _ in pairs(trigger.forbidTags) do if t[tag] then return false end end
	end
	return true
end

function BuffController.new(entityData)
	local self = setmetatable({
		entityData = entityData,
		entity = entityData.entity,
		data = entityData.data,
		listeners = {},
		active = {},
	}, BuffController)
	
	local p = self.data and self.data._private or {}
	p.moveSpeedBase = p.moveSpeedBase or 0
	p.moveSpeedMult = p.moveSpeedMult or 1
	self.data._private = p
	
	return self
end

function BuffController:applyPrivateMultiplier(buffData, key, multiplier)
	local p = self.data.private
	p[key] = (p[key] or 1) * multiplier
	buffData.applied = buffData.applied or {}
	table.insert(buffData.applied, {type = "multiplier", key = key, multiplier = multiplier})
end

function BuffController:applyPrivateAdd(buffData, key, amount)
	local p = self.data.private
	p[key] = (p[key] or 1) + amount
	buffData.applied = buffData.applied or {}
	table.insert(buffData.applied, {type = "add", key = key, amount = amount })
end

function BuffController:revertPrivateMods(buffData)
	if not buffData.applied then return end
	local p = self.data.private
	for i = #buffData.applied, 1, -1 do
		local mod = buffData.applied[i]
		if mod.type == "multiplier" then
			p[mod.key] = (p[mod.key] or 1) / mod.multiplier
		elseif mod.type == "add" then
			p[mod.key] = (p[mod.key] or 0) - mod.amount
		end
		buffData.applied[i] = nil
	end
end

function BuffController:registerTriggers(buffData)
	local buff = buffData.buff
	if not buff.triggers then return end
	
	for event, _ in pairs(buff.triggers) do
		self.listeners[event] = self.listeners[event] or {}
		table.insert(self.listeners[event], buffData)
	end
end

function BuffController:unregisterTriggers(buffData)
	local buff = buffData.buff
	if not buff.triggers then return end
	
	for event, _ in pairs(buff.triggers) do
		local list = self.listeners[event]
		if not list then continue end
		
		for i = #list, 1, -1 do
			if list[i] == buffData then table.remove(list, i) break end
		end
		
		if #list == 0 then self.listeners[event] = nil end
	end
end

function BuffController:apply(buff, context)
	if not buff or not buff.id then warn("Buff missing method or id") return end
	
	local id = buff.id
	local list = self.active[id] or {}
	self.active[id] = list
	
	local stacking = buff.stacking or "ignore"
	local t = now()
	
	if stacking == "refresh" and #list > 0 then
		local buffData = list[1]
		if buff.duration then buffData.expiresAt = t + buff.duration end
		buffData.context = context or buffData.context
		return buffData
	end
	
	if stacking == "ignore" and #list > 0 and buff.type == "Passive" then
		return list[1]
	end
	
	local newBuffData = {
		buff = buff,
		context = context,
		createdAt = t,
		expiresAt = buff.duration and (t + buff.duration) or math.huge,
		nextTickAt = buff.interval and (t + buff.interval) or math.huge,
		stacks = 1,
		cooldownEnd = {}
	}
	
	table.insert(list, newBuffData)
	
	if buff.onApply then buff.onApply(self, newBuffData) end
	self:registerTriggers(newBuffData)
	
	return newBuffData
end

function BuffController:remove(id)
	local list = self.active[id]
	if not list then return end

	for i = #list, 1, -1 do
		local buffData = list[i]
		self:unregisterTriggers(buffData)
		if buffData.buff.onRemove then buffData.buff.onRemove(self, buffData) end
		table.remove(list, i)
	end

	if #list == 0 then self.active[id] = nil end
end

function BuffController:fire(event, context)
	local listeners = self.listeners[event]
	if not listeners then return end
	
	local random = Random.new()
	for i = 1, #listeners do
		local buffData = listeners[i]
		local buff = buffData.buff
		local trigger = buffData.triggers[event]
		if not trigger then continue end
		
		local cooldown = trigger.cooldown
		if cooldown then
			local ends = buffData.cooldownEnd[event] or 0
			if now() < ends then continue end
		end
		
		if not passesFilters(trigger, context or {}) then continue end
		
		local chanceToProc = trigger.chance or 1
		if chanceToProc < 1 and random:NextNumber() > chanceToProc then continue end
		
		if trigger.action then trigger.action(self, buffData, context or {}) end
		if cooldown then buffData.cooldownEnd[event] = now() + cooldown end
	end
	
end

function BuffController:update(dt)
	local t = now()

	for id, list in pairs(self.active) do
		for i = #list, 1, -1 do
			local buffData = list[i]
			local buff = buffData.buff

			if buff.interval and t >= buffData.nextTickAt then
				buffData.nextTickAt = t + buff.interval
				if buff.onInterval then buff.onInterval(self, buffData) end
			end

			if buff.duration and t >= buffData.expiresAt then
				self:unregisterTriggers(buffData)
				if buff.onRemove then buff.onRemove(self, buffData) end
				table.remove(list, i)
			end
		end
		if #list == 0 then self.active[id] = nil end
	end
end

return BuffController
