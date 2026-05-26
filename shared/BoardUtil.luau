local BoardUtil = {}
BoardUtil.__index = BoardUtil

function BoardUtil.index_to_square(index: number)
    local rank = math.floor(index / 8)
    local file = index % 8
    return rank, file 
end

function BoardUtil.square_to_index(rank: number, file: number)
    return rank * 8 + file
end

return BoardUtil
