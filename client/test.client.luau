-- # This is just an example on how you can implement it. Delete this script if you want

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared --> Module folder location 

local Players = game:GetService("Players")
local PlayerGui = Players.LocalPlayer.PlayerGui

function MakeChess()
	local Chess = require(Shared.Chess)
	local Main_Game = Chess.new({
		time_per_side = 99999,
	})
end

MakeChess()
