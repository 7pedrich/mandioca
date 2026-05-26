--!nocheck
local Interface = {}
Interface.__index = Interface

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local SFX = SoundService.SFX

local BoardUtil = require(script.Parent.BoardUtil)
local TextureRegistry = require(script.Parent.TextureRegistry)
local PositionParser = require(script.Parent.PositionParser)
local MoveGenerator = require(script.Parent.MoveGenerator)
local __repr__ = require(script.Parent.__repr__)

local SQUARE_SIZE = 64
local ALPHABET = "abcdefghijklmnopqrstuvwxyz"

function Interface.new()
	local self = setmetatable({}, Interface)

	assert(RunService:IsClient(), "You should run this on the client.")
	local localPlayer = Players.LocalPlayer

	local playerGui = localPlayer.PlayerGui

	self.screen_gui = Instance.new("ScreenGui", playerGui)
	self.screen_gui.Name = "Chess"
	self.screen_gui.IgnoreGuiInset = true
	self.current_position = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
	self.board_state = {}

	self.board_frame = Instance.new("Frame", self.screen_gui)
	self.board_frame.Name = "Board"
	self.board_frame.AnchorPoint = Vector2.new(0.5, 0.5)
	self.board_frame.Size = UDim2.new(0, 512, 0, 512)
	self.board_frame.Position = UDim2.new(0.5, 0, 0.5, 0)
	self.board_frame.BackgroundTransparency = 1
	self.board_frame.BorderSizePixel = 0
	self.original_square_colors = {}
	self.square_movement_binds = {}
	self.temporary_movement_hitboxes = {}
	self.game_constants = {
		en_passant_square = nil,
		en_passant_pawn_square = nil,
		last_move_pgn = "",
		turn_to_move = "White",
	}

	self.pieces = {}

	local function createSquare(board: Frame, square_index: number)
		local square = Instance.new("Frame")
		square.Name = tostring(square_index)
		square.BorderSizePixel = 0

		local rank, file = BoardUtil.index_to_square(square_index - 1)
		local row = math.floor((square_index - 1) / 8)
		local col = (square_index - 1) % 8
		local is_dark = (row + col) % 2 == 0

		local original_color = if is_dark then Color3.fromRGB(181, 136, 99) else Color3.fromRGB(240, 217, 181)
		square.BackgroundColor3 = original_color

		self.original_square_colors[square_index] = original_color

		square.Size = UDim2.new(0, SQUARE_SIZE, 0, SQUARE_SIZE)

		local x_position = file * SQUARE_SIZE
		local y_position = (7 - rank) * SQUARE_SIZE

		square.Position = UDim2.new(0, x_position, 0, y_position)
		square.Parent = board

		return square
	end

	local function createSquares()
		local squares = {}
		for square_index = 1, 64 do
			squares[square_index] = createSquare(self.board_frame, square_index)
		end
		return squares
	end

	self.board_squares = createSquares()
	self.file_indicators = Instance.new("Folder", self.board_frame)
	self.rank_indicators = Instance.new("Folder", self.board_frame)

	self.file_indicators.Name = "file_indicators"
	self.rank_indicators.Name = "rank_indicators"

	local function create_file_indicators()
		for i = 1, 8 do
			local indicator = Instance.new("TextLabel", self.file_indicators)
			indicator.Font = Enum.Font.GothamBold
			indicator.TextStrokeTransparency = 1
			indicator.Size = UDim2.new(0, 64, 0, 64)
			indicator.BackgroundTransparency = 1
			indicator.BorderSizePixel = 0
			indicator.TextColor3 = Color3.new(1, 1, 1)
			indicator.TextSize = 35

			local stroke = Instance.new("UIStroke", indicator)
			stroke.Thickness = 2

			indicator.Text = string.sub(ALPHABET, i, i)
			indicator.Position = self.board_squares[i].Position + UDim2.new(0, 0, 0, 64)
		end
	end

	local function create_rank_indicators()
		for i = 1, 8 do
			local side_cell_indices = {
				1,
				9,
				17,
				25,
				33,
				41,
				49,
				57,
			}

			local indicator = Instance.new("TextLabel", self.rank_indicators)
			indicator.Font = Enum.Font.GothamBold
			indicator.TextStrokeTransparency = 1
			indicator.Size = UDim2.new(0, 64, 0, 64)
			indicator.BackgroundTransparency = 1
			indicator.BorderSizePixel = 0
			indicator.TextColor3 = Color3.new(1, 1, 1)
			indicator.TextSize = 35

			local stroke = Instance.new("UIStroke", indicator)
			stroke.Thickness = 2

			indicator.Text = i
			indicator.Position = self.board_squares[side_cell_indices[i]].Position - UDim2.new(0, 64, 0, 0)
		end
	end

	create_file_indicators()
	create_rank_indicators()

	local function clear_highlights()
		for square_index, original_color in pairs(self.original_square_colors) do
			local square = self.board_squares[square_index]
			if square then
				square.BackgroundColor3 = original_color
			end
		end
	end

	local function highlight_square(square_index: number, color: Color3)
		local square = self.board_squares[square_index]
		if square then
			square.BackgroundColor3 = color
		end
	end

	local function reset_hitboxes()
		for _, movement_hitbox in self.temporary_movement_hitboxes do
			movement_hitbox:Destroy()
		end
		table.clear(self.temporary_movement_hitboxes)
	end

	local function create_temporary_hitbox(square_index: number, bind_to_click)
		local square = self.board_squares[square_index]
		local hitbox = Instance.new("TextButton")

		hitbox.Size = UDim2.new(1, 0, 1, 0)
		hitbox.Text = ""
		hitbox.Name = "hitbox"
		hitbox.BorderSizePixel = 0
		hitbox.BackgroundTransparency = 1
		hitbox.ZIndex = 3

		self.temporary_movement_hitboxes[#self.temporary_movement_hitboxes + 1] = hitbox
		hitbox.MouseButton1Click:Once(function()
			reset_hitboxes()
			return bind_to_click()
		end)

		if square then
			hitbox.Parent = square
		end
	end

	local function get_position_from_square_index(square_index: number)
		local square = self.board_squares[square_index]
		if square then
			return square.Position
		else
			return nil
		end
	end

	local function smooth_tween(instance: GuiObject, properties: {})
		local smooth_info = TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 0, false, 0)
		local newTween = TweenService:Create(instance, smooth_info, properties)

		newTween:Play()
	end

	local function is_adjacent(square1: number, square2: number)
		if square1 == nil or square2 == nil then return false end
		local adjacency_check = math.abs(square1 - square2)

		return adjacency_check == 7 or adjacency_check == 9 or square1 == square2
	end

	local function execute_move(piece, piece_index, square_index)
		if piece.Name:lower() ~= "p" then
			self.game_constants.en_passant_square = nil
			self.game_constants.en_passant_pawn_square = nil
		end

		local is_move_white = piece.Name:lower() ~= piece.Name
		local is_castling = false

		local castling_squares = {
			[63] = "blahblahblah",
			[59] = "blehblehbleh",
			[3] = "bluhbluhbluh",
			[7] = "blohblohbloh",
		}
		if piece.Name:lower() == "k" and math.abs(square_index - piece_index) == 2 then
			is_castling = true
		end

		if is_castling then
			local castling_side_per_square_index = {
				[63] = "kr",
				[59] = "kq",
				[3] = "KQ",
				[7] = "KR",
			}

			local castling_side = castling_side_per_square_index[square_index]

			local rooknames_per_castling_side = {
				kr = "rk",
				KR = "RK",
				kq = "rq",
				KQ = "RQ",
			}

			local rook_destination_square = {
				kr = 62,
				KR = 6,
				KQ = 4,
				kq = 60,
			}

			local default_rook_placements = {
				kr = 64,
				kq = 57,
				KR = 8,
				KQ = 1,
			}

			local rook = self.board_frame[rooknames_per_castling_side[castling_side]]
			if rook then
				smooth_tween(
					rook,
					{ Position = get_position_from_square_index(rook_destination_square[castling_side]) }
				)
				self.pieces[default_rook_placements[castling_side]] = nil
				self.board_state[default_rook_placements[castling_side]] = nil
				self.pieces[rook_destination_square[castling_side]] = rook
				rook:SetAttribute("PieceSquare", rook_destination_square[castling_side])
			end
		end

		local is_en_passant_capture = false
		local is_normal_capture = false

		local condition_1 = self.game_constants.en_passant_square ~= nil
		local condition_2 = self.game_constants.en_passant_pawn_square ~= nil
		local condition_3 = piece.Name:lower() == "p"
		local condition_4 = square_index == self.game_constants.en_passant_square

		if condition_1 and condition_2 and condition_3 and condition_4 then
			is_en_passant_capture = true
		else
			is_en_passant_capture = false
		end

		local is_double_pawn_move = false
		if piece.Name:lower() == "p" then
			if math.abs(square_index - piece_index) > 14 then
				is_double_pawn_move = true
			end
		end

		if is_en_passant_capture then
			local captured_pawn_square = self.game_constants.en_passant_pawn_square
			local captured_pawn = self.pieces[captured_pawn_square]

			if captured_pawn then
				captured_pawn:Destroy()
				self.pieces[captured_pawn_square] = nil
				self.board_state[captured_pawn_square] = nil
				SFX.SacreBleu:Play()
			end

			self.game_constants.en_passant_square = nil
			self.game_constants.en_passant_pawn_square = nil
		else
			local captured_piece = self.pieces[square_index]
			if captured_piece then
				captured_piece:Destroy()
				is_normal_capture = true
				SFX.Capture:Play()
				if not is_double_pawn_move then
					self.game_constants.en_passant_square = nil
					self.game_constants.en_passant_pawn_square = nil
				end
			end
		end

		if is_double_pawn_move then
			local is_black_piece = piece.Name:lower() == piece.Name
			self.game_constants.en_passant_square = (if is_black_piece then square_index + 8 else square_index - 8)
			self.game_constants.en_passant_pawn_square = square_index
		else
			if piece.Name:lower() ~= "p" then
				self.game_constants.en_passant_square = nil
				self.game_constants.en_passant_pawn_square = nil
			else
				if not is_normal_capture then
					self.game_constants.en_passant_square = nil
					self.game_constants.en_passant_pawn_square = nil
				end
			end
		end

		self.pieces[square_index] = piece
		self.pieces[piece_index] = nil

		self.board_state[square_index] = piece:GetAttribute("PieceType")
		self.board_state[piece_index] = nil

		piece:SetAttribute("PieceSquare", square_index)

		smooth_tween(piece, { Position = get_position_from_square_index(square_index) })

		local function get_square_from_square_index(sq_index: number)
			local sq = self.board_squares[sq_index]
			if sq then
				return sq
			else
				return "blahblahblah"
			end
		end

		local moves = MoveGenerator.generate_moves_for_piece(
			piece,
			get_square_from_square_index(piece:GetAttribute("PieceSquare")),
			self.board_state,
			self.game_constants
		)

		local is_check = false
		local checked_king_square_index = 0

		for _, move_index in pairs(moves) do
			if self.pieces[move_index] and self.pieces[move_index].Name:upper() == "K" then
				local king_color = self.pieces[move_index]:GetAttribute("PieceColor")
				if king_color ~= self.game_constants.turn_to_move then
					is_check = true
					checked_king_square_index = move_index
					break
				else
					
				end
			end
		end

		if not is_check then
			SFX.Move:Play()
		else

			SFX.Check:Play()
		end

		-- Flip turns after successful move
		if self.game_constants.turn_to_move == "White" then
			self.game_constants.turn_to_move = "Black"
		else
			self.game_constants.turn_to_move = "White"
		end

		-- Clear highlights
		if not is_check then
			clear_highlights()
		else
			clear_highlights()
			highlight_square(checked_king_square_index, Color3.fromRGB(255, 0, 0))
		end
	end

	local function add_square_movement_bind(square_index: number, piece_index: number)
		local square = self.board_squares[square_index]

		if square then
			for bind_index, bind: RBXScriptConnection in self.square_movement_binds do
				bind:Disconnect()
				self.square_movement_binds[bind_index] = nil
			end

			local function bind_to_click()
				local piece = self.pieces[piece_index]
				if not piece then
					return
				end

				execute_move(piece, piece_index, square_index)
			end

			create_temporary_hitbox(square_index, bind_to_click)
		end
	end

	local function get_square_from_square_index(square_index: number)
		local square = self.board_squares[square_index]
		if square then
			return square
		else
			return "blahblahblah"
		end
	end

	local function create_piece(piece_type: string, square_index: number)
		local square = self.board_squares[square_index]
		local piece_texture = TextureRegistry[piece_type]

		local image_button = Instance.new("ImageButton", self.board_frame)
		image_button:SetAttribute("PieceType", piece_type)
		image_button:SetAttribute("PieceSquare", square_index)
		image_button:SetAttribute("PieceColor", if piece_type:lower() == piece_type then "Black" else "White")

		local rook_types = {
			[1] = "Q",
			[8] = "K",
			[64] = "k",
			[57] = "q",
		}

		if piece_type:lower() == "k" then
			image_button:SetAttribute("KingMoved", false)
		end
		if piece_type:lower() == "r" then
			image_button:SetAttribute("RookMoved", false)
			image_button.Name = piece_type .. rook_types[square_index]
		else
			image_button.Name = piece_type
		end

		image_button:SetAttribute("PieceType", piece_type)
		image_button.Position = square.Position
		image_button.BackgroundTransparency = 1
		image_button.Image = "rbxassetid://" .. piece_texture
		image_button.Size = square.Size
		image_button.ZIndex = 2
		image_button.AutoButtonColor = false

		image_button.MouseButton1Click:Connect(function()
			local piece_color = image_button:GetAttribute("PieceColor")

			-- Check if it's the correct player's turn
			if
				(piece_color == "White" and self.game_constants.turn_to_move ~= "White")
				or (piece_color == "Black" and self.game_constants.turn_to_move ~= "Black")
			then
				return
			end

			if image_button.Name:lower() == "p" then
				image_button:SetAttribute("PawnMoved", true)
			end

			clear_highlights()
			reset_hitboxes()

			highlight_square(image_button:GetAttribute("PieceSquare"), Color3.fromRGB(100, 100, 255))

			local moves = MoveGenerator.generate_moves_for_piece(
				image_button,
				get_square_from_square_index(image_button:GetAttribute("PieceSquare")),
				self.board_state,
				self.game_constants
			)

			for _, move_index in pairs(moves) do
				if move_index >= 1 and move_index <= 64 then
					highlight_square(move_index, Color3.fromRGB(0, 255, 0))
					add_square_movement_bind(move_index, image_button:GetAttribute("PieceSquare"))
				end
			end
		end)

		self.pieces[square_index] = image_button
		return image_button
	end

	local function load_current_position()
		self.board_state = PositionParser.parse_position(self.current_position)

		for square_index, piece_type in pairs(self.board_state) do
			if piece_type then
				create_piece(piece_type, square_index)
			end
		end
	end

	load_current_position()

	return self
end

return Interface
