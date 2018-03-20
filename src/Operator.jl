export apply!, apply


"""
Operator is a description of all types that have a specific set of methods.

All Operator types must implement the following methods (with Op standing in for the Operator):

apply!(Y::MultiVector{Data, GID, PID, LID}, operator::Op{Data, GID, PID, LID}, X::MultiVector{Data, GID, PID, LID}, mode::TransposeMode, alpha::Data, beta::Data)
    Computes ``Y = α\cdot A^{mode}\cdot X + β\cdot Y``, with the following exceptions
        If beta == 0, apply MUST overwrite Y, so that any values in Y (including NaNs) are ignored.
        If alpha == 0, apply MAY short-circuit the operator, so that any values in X (including NaNs) are ignored


getDomainMap(operator::Op{Data, GID, PID, LID})::BlockMap{GID, PID, LID}
    Returns the BlockMap associated with the domain of this operation

getRangeMap(operator::Op{Data, GID, PID, LID})::BlockMap{GID, PID, LID}
    Returns the BlockMap associated with the range of this operation
"""
const Operator = Any #allow Operator to be documented


"""
    apply!(Y::MultiVector, operator, X::MultiVector, mode::TransposeMode=NO_TRANS, alpha=1, beta=0)
    apply!(Y::MultiVector, operator, X::MultiVector, alpha=1, beta=0)

Computes ``Y = α\cdot A^{mode}\cdot X + β\cdot Y``, with the following exceptions:
* If beta == 0, apply MUST overwrite Y, so that any values in Y (including NaNs) are ignored.
* If alpha == 0, apply MAY short-circuit the operator, so that any values in X (including NaNs) are ignored
"""
function apply! end


function apply!(Y::MultiVector{Data, GID, PID, LID}, operator::Any, X::MultiVector{Data, GID, PID, LID}, mode::TransposeMode=TransposeMode.NO_TRANS, alpha::Data=1) where {Data <: Number, GID <: Integer, PID <: Integer, LID <: Integer}
    apply!(Y, operator, X, mode, alpha, 0)
end

function apply!(Y::MultiVector{Data, GID, PID, LID}, operator::Any, X::MultiVector{Data, GID, PID, LID}, alpha::Data, beta::Data=0) where {Data <: Number, GID <: Integer, PID <: Integer, LID <: Integer}
    apply!(Y, operator, X, NO_TRANS, alpha, beta)
end

"""
    apply(Y::MultiVector,operator, X::MultiVector,  mode::TransposeMode=NO_TRANS, alpha=1, beta=0)
    apply(Y::MultiVector, operator, X::MultiVector, alpha=1, beta=0)

As `apply!` except returns a new array for the results
"""
function apply(Y::MultiVector{Data, GID, PID, LID}, operator::Any, X::MultiVector{Data, GID, PID, LID}, mode::TransposeMode=NO_TRANS, alpha::Data=1, beta=0)::MultiVector{Data, GID, PID, LID} where {Data <: Number, GID <: Integer, PID <: Integer, LID <: Integer}
    Y = copy(Y)
    apply!(Y, operator, X, mode, alpha, beta)
    Y
end

function apply(Y::MultiVector{Data, GID, PID, LID}, operator::Any, X::MultiVector{Data, GID, PID, LID}, alpha::Data, beta=0)::MultiVector{Data, GID, PID, LID} where {Data <: Number, GID <: Integer, PID <: Integer, LID <: Integer}
    apply(Y, operator, X, NO_TRANS, alpha, beta)
end
