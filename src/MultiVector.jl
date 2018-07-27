export MultiVector
export localLength, globalLength, numVectors
export scale
export getVectorView, getVectorCopy
export commReduce, norm2



"""
MultiVector represents a dense multi-vector.  Note that all the vectors in a single MultiVector are the same size
"""
type MultiVector{Data <: Number, GID <: Integer, PID <: Integer, LID <: Integer} <: AbstractArray{Data, 2}
    data::Array{Data, 2} # data[1, 2] is the first element of the second vector
    localLength::LID
    globalLength::GID
    numVectors::LID

    map::BlockMap{GID, PID, LID}
end

## Constructors ##

"""
    MultiVector{Data, GID, PID, LID}(::BlockMap{GID, PID, LID}, numVecs::Integer, zeroOut=true)

Creates a new MultiVector based on the given map
"""
function MultiVector{Data, GID, PID, LID}(map::BlockMap{GID, PID, LID}, numVecs::Integer, zeroOut=true) where {Data <: Number, GID <: Integer, PID <: Integer, LID <: Integer}
    localLength = numMyElements(map)
    if zeroOut
        data = zeros(Data, (localLength, numVecs))
    else
        data = Array{Data, 2}(localLength, numVecs)
    end
    MultiVector{Data, GID, PID, LID}(data, localLength, numGlobalElements(map), numVecs, map)
end

"""
    MultiVector{Data, GID, PID, LID}(map::BlockMap{GID, PID, LID}, data::AbstractArray{Data, 2})

Creates a new MultiVector wrapping the given array.  Changes to the MultiVector or Array will affect the other
"""
function MultiVector(map::BlockMap{GID, PID, LID}, data::AbstractArray{Data, 2}) where {Data <: Number, GID <: Integer, PID <: Integer, LID <: Integer}
    localLength = numMyElements(map)
    if size(data, 1) != localLength
        throw(InvalidArgumentError("Length of vectors does not match local length indicated by map"))
    end
    MultiVector{Data, GID, PID, LID}(data, localLength, numGlobalElements(map), size(data, 2), map)
end

## External methods ##

"""
    copy(::MutliVector{Data, GID, PID, LID})::MultiVector{Data, GID, PID, LID}
Returns a copy of the multivector
"""
function Base.copy(vect::MultiVector{Data, GID, PID, LID})::MultiVector{Data, GID, PID, LID} where {Data <: Number, GID <: Integer, PID <: Integer, LID <: Integer}
    MultiVector{Data, GID, PID, LID}(copy(vect.data), vect.localLength, vect.globalLength, vect.numVectors, vect.map)
end

function Base.copy!(dest::MultiVector{Data, GID, PID, LID}, src::MultiVector{Data, GID, PID, LID})::MultiVector{Data, GID, PID, LID} where {Data, GID, PID, LID}
    copy!(dest.data, src.data)
    dest.localLength = src.localLength
    dest.globalLength = src.globalLength
    dest.numVectors = src.numVectors
    dest.map = src.map

    dest
end

"""
    localLength(::MutliVector{Data, GID, PID, LID})::LID

Returns the local length of the vectors in the multivector
"""
function localLength(vect::MultiVector{Data, GID, PID, LID})::LID where {Data <: Number, GID <: Integer, PID <: Integer, LID <: Integer}
    vect.localLength
end

"""
    globalLength(::MultiVector{Data, GID, PID, LID})::GID

Returns the global length of the vectors in the mutlivector
"""
function globalLength(vect::MultiVector{Data, GID})::GID where {Data <: Number, GID <: Integer}
    vect.globalLength
end

"""
    numVectors(::MultiVector{Data, GID, PID, LID})::LID

Returns the number of vectors in this multivector
"""
function numVectors(vect::MultiVector{Data, GID, PID, LID})::LID where {Data <: Number, GID <: Integer, PID <: Integer, LID <: Integer}
    vect.numVectors
end

"""
    getMap(::MultiVector{Data, GID, PID, LID})::BlockMap{GID, PID, LID}

Returns the BlockMap used by this multivector
"""
function getMap(vect::MultiVector{Data, GID, PID, LID})::BlockMap{GID, PID, LID} where {Data <: Number, GID <: Integer, PID <: Integer, LID <: Integer}
    vect.map
end


 function Base.scale!(vect::MultiVector, alpha::Number)
    scale!(vect.data, alpha)
    vect
 end

"""
    scale(::MultiVector{Data, GID, PID, LID}, ::Number)::MultiVector{Data, GID, PID, LID}

Scales a copy of the mulitvector and returns the copy
"""
function scale(vect::MultiVector, alpha::Number)
    scale!(copy(vect), alpha)
end


function Base.scale!(vect::MultiVector, alpha::AbstractArray{<:Number})
    for v = 1:vect.numVectors
        @inbounds vect.data[:, v] *= alpha[v]
    end
    vect
end

"""
    scale(::MultiVector{Data, GID, PID, LID}, ::AbstractArray{<:Number})::MultiVector{Data, GID, PID, LID}

Scales each column of a copy of the mulitvector and returns the copy
"""
function scale(vect::MultiVector, alpha::T) where T <: AbstractArray{<:Number}
    scale!(copy(vect), alpha)
end


function Base.dot(vect1::MultiVector{Data, GID, PID, LID}, vect2::MultiVector{Data, GID, PID, LID}
        )::AbstractArray{Data, 2} where {Data, GID, PID, LID}
    numVects = numVectors(vect1)
    length = localLength(vect1)
    if numVects != numVectors(vect2)
        throw(InvalidArgumentError("MultiVectors must have the same number of vectors to take the dot product of them"))
    end
    if length != localLength(vect2)
        throw(InvalidArgumentError("Vectors must have the same length to take the dot product of them"))
    end
    dotProducts = Array{Data, 2}(1, numVects)

    data1 = vect1.data
    data2 = vect2.data

    for vect in 1:numVects
        sum = Data(0)
        for i = 1:length
            sum += data1[i, vect]*data2[i, vect]
        end
        dotProducts[vect] = sum
    end

    dotProducts = sumAll(getComm(vect1), dotProducts)::Array{Data, 2}

    dotProducts
end

"""
    getVectorView(::MultiVector{Data}, columns)::AbstractArray{Data}

Gets a view of the requested column vector(s) in this multivector
"""
function getVectorView(mVect::MultiVector{Data}, column)::AbstractArray{Data}  where {Data}
    view(mVect.data, :, column)
end

"""
    getVectorCopy(::MultiVector{Data}, columns)::Array{Data}

Gets a copy of the requested column vector(s) in this multivector
"""
function getVectorCopy(mVect::MultiVector{Data}, column)::Array{Data} where {Data}
    mVect.data[:, column]
end

function Base.fill!(mVect::MultiVector, values)
    fill!(mVect.data, values)
    mVect
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

    mVect.data = sumAll(getComm(mVect), mVect.data)::Matrix{Data}
end

#TODO implement this as Base.norm(vect, n)
"""
Handles the non-infinate norms
"""
macro normImpl(mVect, Data, normType)
    quote
        const numVects = numVectors($(esc(mVect)))
        const localVectLength = localLength($(esc(mVect)))
        norms = Array{$(esc(Data)), 2}(1, numVects)
        for i = 1:numVects
            sum = $(esc(Data))(0)
            for j = 1:localVectLength
                $(if normType == 2
                    quote
                        val = $(esc(mVect)).data[j, i]
                        sum += val*val
                    end
                else
                    :(sum += $(esc(Data))($(esc(mVect)).data[j, i]^$normType))
                end)
            end
            norms[i] = sum
        end

        norms = sumAll(getComm(getMap($(esc(mVect)))), norms)::Array{$(esc(Data)), 2}

        $(if normType == 2
            :(@. norms = sqrt(norms))
        else
            :(@. norms = norms^(1/$normType))
        end)
        norms
    end
end


function norm2(mVect::MultiVector{Data})::AbstractArray{Data} where Data
    @normImpl mVect Data 2
end


## DistObject interface ##

function checkSizes(source::MultiVector{Data, GID, PID, LID},
        target::MultiVector{Data, GID, PID, LID})::Bool where {
            Data <: Number, GID <: Integer, PID <: Integer, LID <: Integer}
    (source.numVectors == target.numVectors
        && source.globalLength == target.globalLength
        )#&& source.localLength == target.localLength)
end


function copyAndPermute(source::MultiVector{Data, GID, PID, LID},
        target::MultiVector{Data, GID, PID, LID}, numSameIDs::LID,
        permuteToLIDs::AbstractArray{LID, 1}, permuteFromLIDs::AbstractArray{LID, 1}
        ) where {Data <: Number, GID <: Integer, PID <: Integer, LID <: Integer}
    numPermuteIDs = length(permuteToLIDs)
    @inbounds for j in 1:numVectors(source)
        for i in 1:numSameIDs
            target.data[i, j] = source.data[i, j]
        end

        #don't need to sort permute[To/From]LIDs, since the orders match
        for i in 1:numPermuteIDs
            target.data[permutToLIDs[i], j] = source.data[permuteFromLIDs[i], j]
        end
    end
end

function packAndPrepare(source::MultiVector{Data, GID, PID, LID},
        target::MultiVector{Data, GID, PID, LID}, exportLIDs::AbstractArray{LID, 1},
        distor::Distributor{GID, PID, LID})::Array where {
            Data <: Number, GID <: Integer, PID <: Integer, LID <: Integer}
    exports = Array{Array{Data, 1}}(length(exportLIDs))
    for i = 1:length(exports)
        exports[i] = source.data[exportLIDs[i], :]
    end
    exports
end

function unpackAndCombine(target::MultiVector{Data, GID, PID, LID},
        importLIDs::AbstractArray{LID, 1}, imports::AbstractArray,
        distor::Distributor{GID, PID, LID},cm::CombineMode) where {
            Data <: Number, GID <: Integer, PID <: Integer, LID <: Integer}
    for i = 1:length(importLIDs)
        target.data[importLIDs[i], :] = imports[i]
    end
end



### Julia Array API ###

Base.size(A::MultiVector) = (Int(A.globalLength), Int(A.numVectors))

#TODO this might break for funky maps, however indices needs to return a unit range
Base.indices(A::MultiVector) = (minMyGID(A.map):maxMyGID(A.map), 1:A.numVectors)

function Base.getindex(A::MultiVector, row::Integer, col::Integer)
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

    @inbounds value = A.data[lRow, col]
    value
end

function Base.getindex(A::MultiVector, i::Integer)
    if A.numVectors != 0
        throw(ArgumentError("Can only use single index if there is just 1 vector"))
    end

    lRow = lid(getMap(A), i)

    @boundscheck begin
        if lRow < 1
            throw(BoundsError(A, I))
        end
    end

    @inbounds A.data[lRow, 1]
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

    @inbounds value = (A.data[lRow, col] = v)
    value
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

    @inbounds A.data[lRow, 1] = v
end

import Base: ==

function ==(A::MultiVector, B::MultiVector)
    localEquality = A.localLength == B.localLength &&
                    A.numVectors == B.numVectors &&
                    A.data == B.data &&
                    sameAs(A.map, B.map)

    minAll(getComm(A), localEquality)
end


function Base.Broadcast.promote_containertype(::Type{<: MultiVector}, ::Type{<: MultiVector})
    MultiVector
end
function Base.Broadcast.promote_containertype(::Type{Any}, ::Type{<: MultiVector})
    MultiVector
end
function Base.Broadcast.promote_containertype(::Type{<: MultiVector}, ::Type{Any})
    MultiVector
end

function Base.Broadcast._containertype(::Type{<:MultiVector})
    MultiVector
end
function Base.Broadcast.broadcast_indices(::Type{<: MultiVector}, vect)
    indices(vect.data)
end
@inline function Base.Broadcast.broadcast_c(f, ::Type{<:MultiVector}, a...)
    Base.Broadcast_c(f, Array, map(mv->mv.data, a)...)
end
@inline function Base.Broadcast.broadcast!(f, C::MultiVector, A...)
    broadcast!(f, C.data, map(a->if isa(a, MultiVector) a.data else a end, A)...)
end
