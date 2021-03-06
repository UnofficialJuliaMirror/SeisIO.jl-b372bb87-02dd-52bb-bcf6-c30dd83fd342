export nanfill!

"""
  nanfill!(S::SeisData)
  nanfill!(C::SeisChannel)

Replace NaNs in `:x` with mean of non-NaN values.
"""
function nanfill!(S::GphysData)
  for i = 1:S.n
    if !isempty(S.x[i])
      nanfill!(S.x[i])
      note!(S, i, "nanfill!")
    end
  end
  return nothing
end
nanfill!(C::GphysChannel) = (nanfill!(C.x); note!(C, "nanfill!"))
