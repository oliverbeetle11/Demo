local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")

Players.CharacterAutoLoads = false

local Modules = ServerStorage.Modules
local Remotes = ReplicatedStorage.Remotes

local ActionHandler = require(Modules.Handlers.ActionHandler)
local EntityManager = require(Modules.Managers.EntityManager)

task.spawn(function()
	ContentProvider:PreloadAsync({ReplicatedStorage.Assets.Animations})
end)

local function onPlayerAdded(player)
	EntityManager:createEntity(player)
end

local function onPlayerRemoving(player)
	EntityManager:cleanupEntity(player)
end

Players.PlayerRemoving:Connect(onPlayerRemoving)
Players.PlayerAdded:Connect(onPlayerAdded)
