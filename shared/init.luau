local Chess = {}
Chess.__index = Chess

local Interface = require(script.Interface)
local Types = require(script.Types)
local Timer = require(script.Timer)

function Chess.new(game_settings: Types.game_settings)
    local self = setmetatable(Chess, {})

    self.main_game = Interface.new()
    self.times_per_side = {
        white = Timer.new(game_settings.time_per_side),
        black = Timer.new(game_settings.time_per_side)
    }

    return self
end

return Chess