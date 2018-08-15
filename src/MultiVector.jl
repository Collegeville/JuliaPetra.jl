export MultiVector
export localLength, globalLength, numVectors
export scale, scale!
export getVectorView, getVectorCopy, getLocalArray
export commReduce

using LinearAlgebra

# otherwise, the use is forced to import LinearAlgebra
export dot, norm, copyto!

# need to add methods to these functions
import LinearAlgebra: dot, norm
import Base: copyto!

"""
Required methods:

    getMap(::MultiVector)
    numVectors(::MultiVector)
    getLocalArray(::MultiVector{Data})::AbstractMatrix{Data}
    similar(::MultiVector{Data})

`commReduce(::MultiVector)` may need to be overridden if `getLocallArray(multiVector)` doesn't return a type useable by `sumAll`.
"""
abstract type MultiVector{Data <: Number, GID <: Integer, PID <: Integer, LID <: Integer} <: AbstractArray{Data, 2}
end


"""
    globalLength(::MultiVector{Data, GID, PID, LID})::GID

Returns the global length of the vectors in the mutlivector
"""
globalLength(mVect::MultiVector) = numGlobalElements(getMap(mVect))

"""
    localLength(::MultiVector{Data, GID, PID, LID})::LID

Returns the local length of the vectors in the MultiVector
"""
localLength(mVect::MultiVector) = numMyElements(getMap(mVect))

function Base.fill!(mVect::MultiVector, values)
    fill!(getLocalArray(mVect), values)
    mVect
end

function scale!(mVect::MultiVector, alpha::Number)
    rmul!(getLocalArray(mVect), alpha)
    mVect
end

function scale!(mVect::MultiVector{Data, GID, PID, LID}, alpha::AbstractArray{<:Number, 1}) where {Data, GID, PID, LID}
    for v in LID(1):numVectors(mVect)
        @inbounds getVectorView(mVect, v)[:] *= alpha[v]
    end
    mVect
end

function dot(vect1::MultiVector{Data, GID, PID, LID}, vect2::MultiVector{Data, GID, PID, LID}
        )::AbstractArray{Data, 2} where {Data, GID, PID, LID}
    numVects = numVectors(vect1)
    length = localLength(vect1)
    @boundscheck if numVects != numVectors(vect2)
        throw(InvalidArgumentError("MultiVectors must have the same number of vectors to take the dot product of them"))
    end
    @boundscheck if length != localLength(vect2)
        throw(InvalidArgumentError("Vectors must have the same length to take the dot product of them"))
    end
    dotProducts = Array{Data, 2}(undef, 1, numVects)

    data1 = getLocalArray(vect1)
    data2 = getLocalArray(vect2)

    @inbounds for vect in LID(1):numVects
        sum = Data(0)
        for i = LID(1):length
            sum += data1[i, vect]*data2[i, vect]
        end
        dotProducts[vect] = sum
    end

    sumAll(getComm(vect1), dotProducts)::Array{Data, 2}
end

function norm(mVect::MultiVector{Data, GID, PID, LID}, n::Real) where {Data, GID, PID, LID}
    numVects = numVectors(mVect)
    localVectLength = localLength(mVect)
    norms = Array{Data, 2}(undef, 1, numVects)

    data = getLocalArray(mVect)

    if n == 2
        @inbounds for vect in LID(1):numVects
            sum = Data(0)
            for i = LID(1):localVectLength
                val = data[i, vect]
                sum += val*val
            end
            norms[vect] = sum
        end

        norms = sumAll(getComm(getMap(mVect)), norms)::Matrix{Data}
        @. norms = sqrt(norms)
    else
        @inbounds for vect in LID(1):numVects
            sum = Data(0)
            for i = LID(1):localVectLength
                sum += data[i, vect]^n
            end
            norms[vect] = sum
        end

        norms = sumAll(getComm(getMap(mVect)), norms)::Matrix{Data}
        @. norms = norms^(1/n)
    end
end

"""
    commReduce(::MultiVector)

Elementwise reduces the content of the MultiVector across all processes.
Note that the MultiVector cannot be distributed globally.
"""
function commReduce(mVect::MultiVector{Data}) where Data
    #can only reduce locally replicated mutlivectors
    if distributedGlobal(mVect)
        throw(InvalidArgumentError("Cannot reduce distributed MultiVector"))
    end
    view = getLocalArray(mVect)::AbstractMatrix{Data}
    view .= sumAll(getComm(mVect), view)
end

"""
    getVectorView(::DenseMultiVector{Data}, columns)::AbstractArray{Data}

Gets a view of the requested column vector(s) in this DenseMultiVector
"""
getVectorView(mVect::MultiVector, column) = view(getLocalArray(mVect), :, column)

"""
    getVectorCopy(::MultiVector{Data}, columns)::Array{Data}

Gets a copy of the requested column vector(s) in this MultiVector
"""
function getVectorCopy(mVect::MultiVector{Data}, column)::Array{Data} where {Data}
    view = getVectorView(mVect, column)
    copyto!(Array{Data}(undef, size(view)), view)
end

#### DistObject Interface ####

function checkSizes(source::MultiVector{Data, GID, PID, LID},
        target::MultiVector{Data, GID, PID, LID})::Bool where {
            Data <: Number, GID <: Integer, PID <: Integer, LID <: Integer}
    (numVectors(source) == numVectors(target)
        && globalLength(source) == globalLength(target))
end

function copyAndPermute(source::MultiVector{Data, GID, PID, LID},
        target::MultiVector{Data, GID, PID, LID}, numSameIDs::LID,
        permuteToLIDs::AbstractArray{LID, 1}, permuteFromLIDs::AbstractArray{LID, 1}
        ) where {Data <: Number, GID <: Integer, PID <: Integer, LID <: Integer}
    numPermuteIDs = length(permuteToLIDs)
    sourceData = getLocalArray(source)
    targetData = getLocalArray(target)
    @inbounds for vect in LID(1):numVectors(source)
        for i in LID(1):numSameIDs
            targetData[i, vect] = sourceData[i, vect]
        end

        #don't need to sort permute[To/From]LIDs, since the orders match
        for i in LID(1):numPermuteIDs
            targetData[permuteToLIDs[i], vect] = sourceData[permuteFromLIDs[i], vect]
        end
    end
end

function packAndPrepare(source::MultiVector{Data, GID, PID, LID},
        target::MultiVector{Data, GID, PID, LID}, exportLIDs::AbstractArray{LID, 1},
        distor::Distributor{GID, PID, LID})::Array where {
            Data <: Number, GID <: Integer, PID <: Integer, LID <: Integer}
    exports = Array{Array{Data, 1}}(undef, length(exportLIDs))
    sourceData = getLocalArray(source)
    for i in LID(1):length(exports)
        @inbounds exports[i] = Vector{Data}(undef, numVectors(source))
        for vect in LID(1):numVectors(source)
            @inbounds exports[i][vect] = sourceData[exportLIDs[i], vect]
        end
    end
    exports
end

function unpackAndCombine(target::MultiVector{Data, GID, PID, LID},
        importLIDs::AbstractArray{LID, 1}, imports::AbstractArray,
        distor::Distributor{GID, PID, LID},cm::CombineMode) where {
            Data <: Number, GID <: Integer, PID <: Integer, LID <: Integer}
    targetData = getLocalArray(target)
    for i = LID(1):length(importLIDs)
        for vect in LID(1):numVectors(target)
            @inbounds targetData[importLIDs[i], vect] = imports[i][vect]
        end
    end
end



### Julia Array API ###

Base.eltype(::MultiVector{Data}) where Data = Data

Base.size(A::MultiVector) = (Int(globalLength(A)), Int(numVectors(A)))

#TODO this might break for funky maps, however indices needs to return a unit range
Base.axes(A::MultiVector) = (minMyGID(A.map):maxMyGID(A.map), 1:numVectors(A))

function Base.getindex(A::MultiVector, row::Integer, col::Integer)
    @boundscheck begin
        if !(1<=col<=numVectors(A))
            throw(BoundsError(A, (row, col)))
        end
    end

    lRow = lid(getMap(A), row)

    @boundscheck begin
        if lRow < 1
            throw(BoundsError(A, (row, col)))
        end
    end

    @inbounds value = getLocalArray(A)[lRow, col]
    value
end

function Base.getindex(A::MultiVector, i::Integer)
    if numVectors(A) != 1
        throw(ArgumentError("Can only use single index if there is just 1 vector"))
    end

    lRow = lid(getMap(A), i)

    @boundscheck begin
        if lRow < 1
            throw(BoundsError(A, I))
        end
    end

    @inbounds value = getLocalArray(A)[lRow, 1]
    value
end

function Base.setindex!(A::MultiVector, v, row::Integer, col::Integer)
    @boundscheck begin
        if !(1<=col<=A.numVectors)
            throw(BoundsError(A, (row, col)))
        end
    end

    lRow = lid(getMap(A), row)

    @boundscheck begin
        if lRow < 1
            throw(BoundsError(A, (row, col)))
        end
    end

    @inbounds setEntry(A, lRow, col, v)
    v
end

function Base.setindex!(A::MultiVector, v, i::Integer)
    if A.numVectors != 0
        throw(ArgumentError("Can only use single index if there is just 1 vector"))
    end

    lRow = lid(getMap(A), i)

    @boundscheck begin
        if lRow < 1
            throw(BoundsError(A, I))
        end
    end

    @inbounds setEntry(A, lRow, 1, v)
    v
end

import Base: ==

function ==(A::MultiVector, B::MultiVector)
    localEquality = localLength(A) == localLength(B) &&
                    numVectors(A) == numVectors(B) &&
                    getLocalArray(A) == getLocalArray(B) &&
                    sameAs(getMap(A), getMap(B))
    minAll(getComm(A), localEquality)
end

struct MultiVectorBroadcastStyle <: Broadcast.AbstractArrayStyle{2} end
Base.BroadcastStyle(::Type{<:MultiVector}) = MultiVectorBroadcastStyle()
Base.BroadcastStyle(::MultiVectorBroadcastStyle, ::Broadcast.AbstractArrayStyle) = MultiVectorBroadcastStyle


function Base.similar(bc::Broadcast.Broadcasted{MultiVectorBroadcastStyle}, ::Type{ElType}) where ElType
    mv = find_mv(bc)
    #TODO support other MultiVectors to broadcast into?
    #TODO support mixed Data
    DenseMultiVector{eltype(mv)}(getMap(mv), numVectors(mv), false)
end

"`A = find_mv(As)` returns the first MultiVector among the arguments."
find_mv(bc::Base.Broadcast.Broadcasted) = find_mv(bc.args)
find_mv(args::Tuple) = find_mv(find_mv(args[1]), Base.tail(args))
find_mv(x) = x
find_mv(a::MultiVector, rest) = a
find_mv(::Any, rest) = find_mv(rest)


@inline function copyto!(dest::MultiVector, bc::Broadcast.Broadcasted{MultiVectorBroadcastStyle})
    flattened = Broadcast.flatten(bc)
    args = map(mv->if isa(mv, MultiVector) getLocalArray(mv) else mv end, flattened.args)
    broadcast!(flattened.f, args)
    flattened.args[1]
end




#### Required Method documentation stubs ####

"""
    numVectors(::MultiVector{Data, GID, PID, LID})::LID

Returns the number of vectors in this `MultiVector`
"""
function numVectors end

"""
    getMap(::MultiVector{Data, GID, PID, LID})::BlockMap{GID, PID, LID}

Returns the `BlockMap` used by this `MultiVector`
"""
function getMap end

"""
    getLocalArray(::MultiVector{Data})::AbstractMatrix{Data}

Returns the array holding the `MultiVector`'s local elements.
Changes to the array content are be reflected in the `MultiVector`
"""
function getLocalArray end
