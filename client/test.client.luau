local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared

local Players = game:GetService("Players")
local PlayerGui = Players.LocalPlayer.PlayerGui

function MakeChess()
	local Chess = require(Shared.Chess)
	local Main_Game = Chess.new({
		time_per_side = 99999,
	})
end

PlayerGui:WaitForChild("Controls"):WaitForChild("ResetEverything").MouseButton1Click:Connect(function()
    PlayerGui.Chess:Destroy()
    MakeChess()
end)

MakeChess()
