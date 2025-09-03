-- Rework the system a bit so the entity isnt defined under player's instace. Allows to create npcs without requiring extra steps

local ServerStorage = game:GetService("ServerStorage")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local Modules = ServerStorage.Modules

local AppearanceHandler = require(Modules.Handlers.AppearanceHandler)
local InventoryHandler = require(Modules.Handlers.InventoryHandler)
local BuffController = require(Modules.Controllers.BuffController)
local PrivateCallbacks = require(script.Data.PrivateCallbacks)
local StateMachine = require(script.StateMachine)
local Data = require(script.Data)

local dataOptions = {
	publicData = {
		maxStamina = 100,
		stamina = 100,
		maxHealth = 100,
		health = 100,
	},
	privateData = {
		combo = 1,	
	},
	publicCallback = function(self, key, value, old)
		if not self.entity.Character then return end
		self.entity.Character:SetAttribute(key, value) -- throttle this call so it wouldnt spam for stamina, 10hz
	end,
	privateCallback = function(self, key, value, old)
		if not self.entity.Character then return end
		if PrivateCallbacks[key] then
			PrivateCallbacks[key](self, value, old)
		end
	end,
}

local EntityManager = {}
EntityManager.byEntity = {}
EntityManager.entities = {}

local function respawn(entityData)	
	local oldCharacter = entityData.entity.Character
	if oldCharacter then
		oldCharacter:Destroy()
		oldCharacter = nil
	end
	
	local newCharacter = AppearanceHandler.createCharacter(entityData.entity)
	entityData.stateMachine:bindCharacter(newCharacter)
	entityData.data:syncAttributes(newCharacter)
	entityData.stateMachine:clearStack()
	entityData.stateMachine:setState("Idle")

	newCharacter:SetAttribute("EntityId", entityData.id)
	
	newCharacter.Humanoid.Died:Once(function()
		task.delay(3, function()
			if EntityManager.byEntity[entityData.entity] then 
				respawn(entityData)
			end
		end)
	end)
end

function EntityManager:getEntity(entityId)
	return EntityManager.entities[entityId]
end

function EntityManager:createEntity(entity)
	local isNPC = not (entity and entity:IsA("Player"))
	local entityId = HttpService:GenerateGUID(false)

	local entityData = {
		inventory = InventoryHandler.new(nil),
		data = Data.new(entity, dataOptions),
		connections = {},
		entity = entity,
		id = entityId,
	}

	if isNPC then
		entityData.entity = {}
		--create npc appearance and set it to character entityData.entity.Character = AppearanceHandler.createCharacter(entityData.entity)
	else
		entity:SetAttribute("EntityId", entityId)
		entityData.entity = entity
	end

	entityData.buffs = BuffController.new(entityData)

	local stateMachine = StateMachine.new(entity, entityData.data, entityData.buffs)
	entityData.stateMachine = stateMachine

	if isNPC then
		--[[ set character to live and pivot them to pos, or wtv
		entityData.stateMachine:bindCharacter(newCharacter)
		entityData.data:syncAttributes(newCharacter)
		entityData.stateMachine:clearStack()
		entityData.stateMachine:setState("Idle")
		]]
	else
		respawn(entityData)
	end

	EntityManager.byEntity[entity] = entityId
	EntityManager.entities[entityId] = entityData
	
	return EntityManager.entities[entityId]
end

function EntityManager:cleanupEntity(entity)
	local entityId
	if typeof(entity) == "string" then
		entityId = entity
	else
		entityId = EntityManager.byEntity[entity]
	end

	if not entityId then warn(`[EntityManager] Entity: {entity} not found.`) return end
	
	local entityData = EntityManager.entities[entityId]
	if not entityData then return end

	if entityData.data then
		entityData.data:destroy()
		entityData.data = nil
	end

	for _, connection in entityData.connections do
		connection:Disconnect()
	end
	table.clear(entityData.connections)

	entityData.stateMachine:destroy()
	EntityManager.entities[entityId] = nil
	EntityManager.byEntity[entity] = nil
end

-- StateMachine methods.
function EntityManager:setState(entityId, state, ...)
	local entityData = EntityManager.entities[entityId]
	if not entityData then warn(`[EntityManager] Entity {entityId} not found`) return end
	entityData.stateMachine:setState(state, ...)
end

function EntityManager:push(entityId, state, ...)
	local entityData = EntityManager.entities[entityId]
	if not entityData then warn(`[EntityManager] Entity {entityId} not found`) return end
	entityData.stateMachine:push(state, ...)
end

function EntityManager:pushForced(entityId, state, ...)
	local entityData = EntityManager.entities[entityId]
	if not entityData then warn(`[EntityManager] Entity {entityId} not found`) return end
	entityData.stateMachine:pushForced(state, ...)
end

function EntityManager:pop(entityId, ...)
	local entityData = EntityManager.entities[entityId]
	if not entityData then warn(`[EntityManager] Entity {entityId} not found`) return end
	entityData.stateMachine:pop(...)
end

function EntityManager:trigger(entityId, actionName, ...)
	local entityData = EntityManager.entities[entityId]
	if not entityData then warn(`[EntityManager] Entity {entityId} not found`) return end
	entityData.stateMachine:trigger(actionName, ...)
end

function EntityManager:clearstack(entityId)
	local entityData = EntityManager.entities[entityId]
	if not entityData then warn(`[EntityManager] Entity {entityId} not found`) return end
	entityData.stateMachine:clearStack()
end

RunService.Heartbeat:Connect(function(dt)
	for _, entityData in pairs(EntityManager.entities) do
		entityData.buffs:update(dt)

		local stateMachine = entityData.stateMachine
		local state = stateMachine.activeState
		if state and state.update then
			stateMachine:update(dt)
		end
	end
end)


script.Invoke.Event:Connect(function(method, ...)
	if EntityManager[method] then
		EntityManager[method](EntityManager, ...)
	end
end)

return EntityManager
