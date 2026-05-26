local MoveOffsets = {
	King = {-9, -8, -7, -1, 1, 7, 8, 9},
	Queen = {-9, -8, -7, -1, 1, 7, 8, 9},
	Rook = {-8, -1, 1, 8},
	Bishop = {-9, -7, 7, 9},
	Knight = {-17, -15, -10, -6, 6, 10, 15, 17},
	WhitePawn = {-8},
	WhitePawnDouble = {-16},
	BlackPawn = {8}, 
	BlackPawnDouble = {16}, 
}

return MoveOffsets
