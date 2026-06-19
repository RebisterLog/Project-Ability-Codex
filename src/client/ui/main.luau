local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local Proxy = require(ReplicatedStorage.shared.packages.Proxy)
local PlayerData = require(ReplicatedStorage.shared.schemas.PlayerData)
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local Fusion = require(ReplicatedStorage.shared.packages.Fusion)
local OnEvent = require(ReplicatedStorage.shared.packages.Fusion.Instances.OnEvent)
local peek = require(ReplicatedStorage.shared.packages.Fusion.State.peek)
local RegionComponent = require(script.Parent.components.RegionComponent)

local Children = Fusion.Children
local peek = Fusion.peek
local OnEvent = Fusion.OnEvent
local OnChange = Fusion.OnChange
type UsedAs<T> = Fusion.UsedAs<T>

local Button = require(script.Parent.utils.Button)
local Shadow = require(script.Parent.utils.Shadow)
local MixedText = require(script.Parent.utils.MixedText)
local GameData = require(ReplicatedStorage.shared.schemas.GameData)

local Children = Fusion.Children
local scoped = Fusion.scoped

local scope = scoped(Fusion, {
	Button = Button,
	Shadow = Shadow,
	MixedText = MixedText,
})

local MainGui = function(playerProxy: Proxy.ProxyTab<PlayerData.PlayerData>, gameProxy: Proxy.ProxyTab<GameData.GameData>)
	if RunService:IsStudio() then task.wait(3) end

	local currentPage = scope:Value("None")
	
	return scope:New "ScreenGui" {
		Name = "Main",

		IgnoreGuiInset = true,
		Parent = PlayerGui,
		ResetOnSpawn = false,

		[Children] = {
			RegionComponent(scope, playerProxy, gameProxy),
		}
	}
end

return MainGui