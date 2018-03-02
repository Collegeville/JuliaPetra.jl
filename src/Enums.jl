export CombineMode, ADD, INSERT, REPLACE, ABSMAX, ZERO
export TransposeMode, NO_TRANS, TRANS, CONJ_TRANS
export ProfileType, STATIC_PROFILE, DYNAMIC_PROFILE
export IndexType, LOCAL_INDICES, GLOBAL_INDICES
export StorageStatus, STORAGE_2D, STORAGE_1D_UNPACKED, STORAGE_1D_PACKED

"""
Tells petra how to combine data received from other processes with existing data on the calling process for specific import or export options.

Here is the list of combine modes:
  * ADD: Sum new values into existing values
  * INSERT: Insert new values that don't currently exist
  * REPLACE: REplace existing values with new values
  * ABSMAX: If ``x_{old}`` is the old value and ``x_{new}`` the incoming new value, replace ``x_{old}`` with ``\\max(x_{old}, x_{new})``
  * ZERO: Replace old values with zero
"""
@enum CombineMode ADD=1 INSERT=2 REPLACE=3 ABSMAX=4 ZERO=5



"""
Tells petra whether to use the transpose or conjugate transpose of the matrix
"""
@enum TransposeMode NO_TRANS=1 TRANS=2 CONJ_TRANS=3

"""
    isTransposed(mode::TransposeMode)::Bool

Checks whether the given TransposeMode is transposed
"""
@inline isTransposed(mode::TransposeMode) = mode != NO_TRANS


function applyConjugation(mode::TransposeMode, val)
    if mode == CONJ_TRANS
        conj(val)
    else
        val
    end
end

applyConjugation(mode::TransposeMode, val::Real) = val


"""
Allocation profile for matrix/graph entries
"""
@enum ProfileType STATIC_PROFILE DYNAMIC_PROFILE


"""
Can be used to differentiate global and local indices
"""
@enum IndexType LOCAL_INDICES GLOBAL_INDICES


"""
Status of the graph's or matrix's storage, when not in
a fill-complete state.
"""
@enum StorageStatus STORAGE_2D STORAGE_1D_UNPACKED STORAGE_1D_PACKED
