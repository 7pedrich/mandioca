local MoveGenerator = {}
MoveGenerator.__index = MoveGenerator

local MoveOffsets = require(script.Parent.MoveOffsets)
local BoardUtil = require(script.Parent.BoardUtil)
local __repr__ = require(script.Parent.__repr__)

function get_piece_from_index(board_frame: Frame, piece_index: number)
	local piece = nil

	for _, v in board_frame:GetChildren() do 
		if v:IsA("ImageButton") and v:GetAttribute("PieceSquare") == piece_index then
			piece = v
		end
	end

	return piece
end

function is_piece_being_attacked(piece: ImageButton, board_state: {}, game_constants: { en_passant_square: number, turn_to_move: string }, square: Frame)
	local moves = MoveGenerator.generate_moves_for_piece(
		piece,
		square,
		board_state,
		game_constants,
		true
	)

	local board_frame = square.Parent
	local is_being_attacked = false

	for _, move_index in pairs(moves) do
		if get_piece_from_index(board_frame, move_index) then
			local piece_color = get_piece_from_index(board_frame, move_index):GetAttribute("PieceColor")
			if piece_color ~= game_constants.turn_to_move then
				is_being_attacked = true
				break
			end
		end
	end

	return is_being_attacked
end

function MoveGenerator.generate_moves_for_piece(
	piece: ImageButton,
	square: Frame,
	board_state: {},
	game_constants: { en_passant_square: number, turn_to_move: string },
	internal_simulation: boolean
)	

	local piece_type = piece.Name:sub(1, 1)
	local square_index = tonumber(square.Name)

	local en_passant_square = game_constants.en_passant_square
	local board_frame = square.Parent

	local moves = {}

	if piece_type:lower() == "p" then
		return MoveGenerator._generate_pawn_moves(piece_type, square_index, board_state, en_passant_square)
	end

	-- handle castling availability
	local whiteKingsideAvailability = true
	local blackKingsideAvailability = true
	local whiteQueensideAvailability = true
	local blackQueensideAvailability = true

	local white_king = board_frame.K
	local black_king = board_frame.k

	local in_check = false

	if not in_check then
		if white_king:GetAttribute("KingMoved") == true then
			whiteKingsideAvailability = false
			whiteQueensideAvailability = false
		else
			local kingside_rook = board_frame.RK
			local queenside_rook = board_frame.RQ

			if kingside_rook:GetAttribute("RookMoved") == true then
				whiteKingsideAvailability = false
			end

			if queenside_rook:GetAttribute("RookMoved") == true then
				whiteQueensideAvailability = false
			end

			local pieces_kingside_inbetween = {
				board_state[6],
				board_state[7],
			}

			local pieces_queenside_inbetween = {
				board_state[2],
				board_state[3],
				board_state[4],
			}

			for _, v in pieces_kingside_inbetween do
				if v ~= nil then
					whiteKingsideAvailability = false
					break
				end
			end

			for _, v in pieces_queenside_inbetween do
				if v ~= nil then
					whiteQueensideAvailability = false
					break
				end
			end
		end

		if black_king:GetAttribute("KingMoved") == true then
			blackKingsideAvailability = false
			blackQueensideAvailability = false
		else
			local kingside_rook = board_frame.rk
			local queenside_rook = board_frame.rq

			if kingside_rook:GetAttribute("RookMoved") == true then
				blackKingsideAvailability = false
			end

			if queenside_rook:GetAttribute("RookMoved") == true then
				blackQueensideAvailability = false
			end

			local pieces_kingside_inbetween = {
				board_state[63],
				board_state[62],
			}

			local pieces_queenside_inbetween = {
				board_state[58],
				board_state[59],
				board_state[60],
			}

			for _, v in pieces_kingside_inbetween do
				if v ~= nil then
					blackKingsideAvailability = false
					break
				end
			end

			for _, v in pieces_queenside_inbetween do
				if v ~= nil then
					blackQueensideAvailability = false
					break
				end
			end
		end
	else
		blackKingsideAvailability = false
		blackQueensideAvailability = false
		whiteKingsideAvailability = false
		whiteQueensideAvailability = false
	end

	local offsets = {}
	if piece_type:lower() == "k" then
		offsets = MoveOffsets.King
		piece:SetAttribute("KingMoved", true)
		if piece_type:lower() == piece_type then
			-- king is black
			if blackKingsideAvailability then
				offsets[#offsets + 1] = 2
			end
			if blackQueensideAvailability then
				offsets[#offsets + 1] = -2
			end
		else
			-- king is white
			if whiteKingsideAvailability then
				offsets[#offsets + 1] = 2
			end
			if whiteQueensideAvailability then
				offsets[#offsets + 1] = -2
			end
		end
	elseif piece_type:lower() == "q" then
		offsets = MoveOffsets.Queen
	elseif piece_type:lower() == "r" then
		piece:SetAttribute("RookMoved", true)
		offsets = MoveOffsets.Rook
	elseif piece_type:lower() == "b" then
		offsets = MoveOffsets.Bishop
	elseif piece_type:lower() == "n" then
		offsets = MoveOffsets.Knight
	end

	if piece_type:lower() == "q" or piece_type:lower() == "r" or piece_type:lower() == "b" then
		for _, offset in ipairs(offsets) do
			local current_index = square_index
			while true do
				current_index = current_index + offset

				if current_index < 1 or current_index > 64 then
					break
				end

				local prev_rank = math.floor((current_index - offset - 1) / 8)
				local curr_rank = math.floor((current_index - 1) / 8)

				if math.abs(offset) == 1 then
					if prev_rank ~= curr_rank then
						break
					end

				elseif math.abs(offset) == 8 then

				elseif math.abs(offset) == 7 or math.abs(offset) == 9 then
					local prev_file = (current_index - offset - 1) % 8
					local curr_file = (current_index - 1) % 8

					if math.abs(curr_rank - prev_rank) ~= 1 or math.abs(curr_file - prev_file) ~= 1 then
						break
					end
				end

				if board_state[current_index] then
					if MoveGenerator._is_enemy_piece(current_index, piece_type, board_state) then
						table.insert(moves, current_index)
					end
					break
				else
					table.insert(moves, current_index)
				end
			end
		end
	elseif piece_type:lower() ~= "k" then
		for _, offset in ipairs(offsets) do
			local target_index = square_index + offset
			if MoveGenerator._is_valid_square(target_index, square_index, offset) then
				if
					not board_state[target_index]
					or MoveGenerator._is_enemy_piece(target_index, piece_type, board_state)
				then
					table.insert(moves, target_index)
				end
			end
		end
	else
				for _, offset in ipairs(offsets) do
			local target_index = square_index + offset
			if MoveGenerator._is_valid_square(target_index, square_index, offset) then
				if
					not board_state[target_index]
					or MoveGenerator._is_enemy_piece(target_index, piece_type, board_state)
				then
					table.insert(moves, target_index)
				end
			end
		end
	end


	return moves
end

function MoveGenerator._generate_pawn_moves(
	piece_type: string,
	square_index: number,
	board_state: {},
	en_passant_square: number
)
	local moves = {}
	local is_white = piece_type:upper() == piece_type

	local forward_offset = is_white and 8 or -8
	local forward_index = square_index + forward_offset
	if
		MoveGenerator._is_valid_square(forward_index, square_index, forward_offset)
		and not board_state[forward_index]
	then
		table.insert(moves, forward_index)
		local is_starting_rank = (is_white and square_index >= 9 and square_index <= 16)
			or (not is_white and square_index >= 49 and square_index <= 56)
		if is_starting_rank then
			local double_forward_index = forward_index + forward_offset
			if
				MoveGenerator._is_valid_square(double_forward_index, forward_index, forward_offset)
				and not board_state[double_forward_index]
			then
				table.insert(moves, double_forward_index)
			end
		end
	end

	local capture_offsets = is_white and { 9, 7 } or { -9, -7 }
	for _, offset in ipairs(capture_offsets) do
		local capture_index = square_index + offset
		if
			MoveGenerator._is_valid_square(capture_index, square_index, offset)
			and board_state[capture_index]
			and MoveGenerator._is_enemy_piece(capture_index, piece_type, board_state)
		then
			table.insert(moves, capture_index)
		end
	end
	-- handle en-passant
	if en_passant_square ~= nil then
		local adjacency_check = math.abs(square_index - en_passant_square)

		if adjacency_check == 7 or adjacency_check == 9 then
			moves[#moves + 1] = en_passant_square
		end
	end

	return moves
end

function MoveGenerator._is_valid_square(index: number, from_index: number, offset: number): boolean
	if index < 1 or index > 64 then
		return false
	end

	local from_file = (from_index - 1) % 8
	local to_file = (index - 1) % 8

	if math.abs(from_file - to_file) > 2 then
		return false
	end

	return true
end

function MoveGenerator._is_enemy_piece(index: number, piece_type: string, board_state: {}): boolean
	if not board_state[index] then
		return false
	end

	local target_piece = board_state[index]
	if typeof(target_piece) == "Instance" then
		target_piece = target_piece.Name
	end
	local is_target_white = string.upper(target_piece) == target_piece
	local is_source_white = string.upper(piece_type) == piece_type
	return is_target_white ~= is_source_white -- Different colors
end

return MoveGenerator
