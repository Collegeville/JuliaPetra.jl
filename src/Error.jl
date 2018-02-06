
export InvalidArgumentError, InvalidStateError

"""
    InvalidArgumentError(msg)

The values passed as arguments are not valid.  Argument `msg`
is a descriptive error string.
"""
struct InvalidArgumentError <: Exception
    msg::AbstractString
end


"""
    InvalidStateError(msg)

An object is not in a valid state for this method.  Argument `msg`
is a descriptive error string.
"""
struct InvalidStateError <: Exception
    msg::AbstractString
end