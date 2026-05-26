local PositionParser = {}
local BoardUtil = require(script.Parent.BoardUtil)

function PositionParser.parse_position(fen: string)
	local parts = string.split(fen, " ")
	local board_part = parts[1]

	local pieces = {}
	local rank = 8 
	local file = 1 

	for i = 1, #board_part do
		local char = board_part:sub(i, i)
		if char == "/" then
			rank = rank - 1
			file = 1
		elseif char:match("%d") then
			file = file + tonumber(char)
		else
			local square_index = BoardUtil.square_to_index(rank - 1, file - 1) + 1
			pieces[square_index] = char
			file = file + 1
		end
	end

	return pieces
end

return PositionParser
