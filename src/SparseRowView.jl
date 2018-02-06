
export SparseRowView, vals, cols

"""
    SparseRowView(vals::AbstractArray{Data}, cols::AbstractArray{IndexType}, count::Integer=length(vals), start::Integer=1, stride::Integer=1)

Creates a view of a sparse row
"""
struct SparseRowView{Data, IndexType <: Integer}
    vals::AbstractArray{Data}
    cols::AbstractArray{IndexType}

    function SparseRowView(vals::AbstractArray{Data}, cols::AbstractArray{IndexType}
            ) where {Data, IndexType}
        if length(vals) != length(cols)
            throw(InvalidArgumentError("length(vals) = $(length(vals)) "
                    * "!= length(cols) = $(length(cols))"))
        end
        new{Data, IndexType}(vals, cols)
    end
end

function SparseRowView(vals::AbstractArray{Data}, cols::AbstractArray{IndexType},
        count::Integer, start::Integer=1, stride::Integer=1) where {Data, IndexType}
    SparseRowView(view(vals, range(start, stride, count)),
        view(cols, range(start, stride, count)))
end
   
function Base.nnz(row::SparseRowView{Data, IndexType}) where{Data, IndexType} 
    IndexType(length(row.vals))
end

"""
    vals(::SparseRowView{Data, IndexType})::AbstractArray{Data, 1}

Gets the values of the row
"""
vals(row::SparseRowView) = row.vals

"""
    cols(::SparseRowView{Data, IndexType})::AbstractArray{IndexType, 1}

Gets the column indices of the row
"""
cols(row::SparseRowView) = row.cols