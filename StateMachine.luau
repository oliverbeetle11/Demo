local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local StateEnums = require(script.StateEnums)

local PRIORITY = {
	Dead = 1000,
	Stunned = 900,
	Attack = 100,
	Sprint = 50,
	Idle = 10,
}

local StateMachine = {}
StateMachine.__index = StateMachine

local function getPriority(name)
	return PRIORITY[name] or 0
end

function StateMachine.new(entity, data, buffs)
	local stateMachine = setmetatable({
		data = data,
		buffs = buffs, 
		entity = entity, -- entity object
		states = StateEnums, -- state enums
		activeState = nil, -- current active state enum
		charConnections = {}, -- connections related to character
		connections = {}, -- connections related to the statemachine
		stateName = nil, -- current active state's name
		stack = {}, -- stack of states
		cache = {},
	}, StateMachine)

	if table.find(Players:GetPlayers(), entity) then
		stateMachine.isPlayer = true
	end

	return stateMachine
end

function StateMachine:bindCharacter(char)
	if self.charConnections then
		for _, c in ipairs(self.charConnections) do c:Disconnect() end
		table.clear(self.charConnections)
	else
		self.charConnections = {}
	end

	self.entity.Character = char
	char.Parent = workspace.Live

	if char then
		--char:SetAttribute("CurrentState", self.stateName or "Idle")
		--char:SetAttribute("Health", math.floor(self.entity.Vitals.HP))
		--char:SetAttribute("MaxHealth", self.entity.Stats.final.MaxHP)
	end
end

function StateMachine:canPush(state)
	local activeState = self.activeState
	local newState = StateEnums[state]

	if StateEnums.__universalTransitions[state] then
		local universal = StateEnums.__universalTransitions[state]
		local newPriority = universal.priority or getPriority(state)
		local currentPriority = getPriority(self.stateName)
		return newPriority >= currentPriority
	end

	local currentTags = activeState and activeState.tags or {}
	local newTags = newState and newState.tags or {}

	if currentTags.Lock and state ~= "Dead" then return false end

	if newTags.Attack and currentTags.Movement then return true end

	local allowed = activeState and activeState.transitions
	return allowed and table.find(allowed, state) ~= nil
end

function StateMachine:setState(state, ...)
	local newState = self.states and self.states[state]
	if not newState then warn(`[StateMachine] State {state} not found`) return end

	if self.activeState and self.activeState.exit then self.activeState.exit(self) end

	self.stateName = state
	self.activeState = newState

	local char = self.isPlayer and self.entity and self.entity.Character
	if char then char:SetAttribute("CurrentState", state) end

	if self.activeState.enter then self.activeState.enter(self, ...) end
end

function StateMachine:push(name, ...)
	if self:canPush(name) then
		table.insert(self.stack, self.stateName)
		self:setState(name, ...)
	else
		warn(`Blocked transition {self.stateName} -> {name}`)
	end
end

function StateMachine:pushForced(name, ...)
	table.insert(self.stack, self.stateName)
	self:setState(name, ...)
end

function StateMachine:pop(...)
	local prev = table.remove(self.stack)
	if prev then self:setState(prev, ...) end
	if not prev then self:setState("Idle") end
end

function StateMachine:clearStack()
	table.clear(self.stack)
	self.stack = {}
end

function StateMachine:trigger(actionName, ...)
	local universalAction = StateEnums.__universalActions[actionName]
	if universalAction then return universalAction(self, ...) end
	
	if self.activeState and self.activeState.tags and self.activeState.tags.cantTrigger then
		return
	end
	
	local action = self.activeState and self.activeState[actionName]
	if action then action(self, ...) end
end

function StateMachine:update(dt)
	if self.activeState and self.activeState.update then
		self.activeState.update(self, dt)
	end
end

function StateMachine:destroy()
	self:clearStack()
	
	if self.activeState and self.activeState.exit then self.activeState.exit(self, true) end
	
	if self.charConnections then
		for _, c in ipairs(self.charConnections) do c:Disconnect() end
		self.charConnections = nil
	end
	
	if self.connections then
		for _, c in ipairs(self.connections) do c:Disconnect() end
		self.connections = nil
	end

	if self.cache then
		table.clear(self.cache)
		self.cache = nil
	end

	self.activeState, self.states, self.entity, self.stateName, self.stack, self.isPlayer = nil, nil, nil, nil, nil, nil
end

return StateMachine
