const μs = 1.0e-6

u2d(k::Real) = Dates.unix2datetime(k)
d2u(k::DateTime) = Dates.datetime2unix(k)

"""
    t = tzcorr()

Fast fix for timezone in Libc.strftime assuming local, not UTC. Returns a time
zone correction in seconds; when calling Libc.strftime, add tzcorr() to an epoch
time to obtain output in UTC.
"""
tzcorr() = (t = Libc.strftime("%z",time()); return -3600*parse(t[1:3])-60*parse(t[4:5]))

"""
  m,d = j2md(y,j)

Convert Julian day j of year y to month m, day d
"""
function j2md(y::Integer, j::Integer)
   if j > 31
      D = [31,28,31,30,31,30,31,31,30,31,30,31]
      ((y%400 == 0) || (y%4 == 0 && y%100 != 0)) && (D[2]+=1)
      m = 0
      while j > 0
         d = j
         m += 1
         j -= D[m]
      end
   else
      m = 1
      d = j
   end
   return m, d
end

"""
  j = md2j(y,m,d)

Convert month `m`, day `d` of year `y` to Julian day (day of year)
"""
function md2j(y::Integer,m::Integer,d::Integer)
  D = [31,28,31,30,31,30,31,31,30,31,30,31]
  ((y%400 == 0) || (y%4 == 0 && y%100 != 0)) && (D[2]+=1)
  return (sum(D[1:m-1]) + d)
end

"""
    t = sac2epoch(S)

Generate epoch time `t` from SAC dictionary `S`. `S` must contain all relevant
time headers (NZYEAR, NZJDAY, NZHOUR, NZMIN, NZSEC, NSMSEC).
"""
function sac2epoch(S::Dict{String,Any})
  y = convert(Int64,S["nzyear"])
  j = convert(Int64,S["nzjday"])
  m,d = j2md(y,j)
  b = [convert(Int64,i) for i in [S["nzhour"] S["nzmin"] S["nzsec"] S["nzmsec"]]]
  return d2u(DateTime(y,m,d,b[1],b[2],b[3],b[4]))
end

"""
    d0, d1 = parsetimewin(s, t)

Convert times `s` and `t` to DateTime objects and sorts s.t. d0 < d1.
"""
function parsetimewin(s::DateTime, t::DateTime)
  if s < t
    return (string(s), string(t))
  else
    return (string(t), string(s))
  end
end
parsetimewin(s::DateTime, t::String) = parsetimewin(s, DateTime(t))
parsetimewin(s::DateTime, t::Real) = parsetimewin(s, u2d(d2u(s)+t))
parsetimewin(s::Real, t::DateTime) = parsetimewin(t, u2d(d2u(t)+s))
parsetimewin(s::String, t::Union{Real,DateTime}) = parsetimewin(DateTime(s), t)
parsetimewin(s::Union{Real,DateTime}, t::String) = parsetimewin(s, DateTime(t))
parsetimewin(s::String, t::String) = parsetimewin(DateTime(s), DateTime(t))
parsetimewin(s::Real, t::Real) = parsetimewin(u2d(60*floor(Int, time()/60) + s), t)

"""
    T = t_expand(t, fs)

Expand sparse delta-encoded time stamp representation t to full time stamps.
Returns integer time stamps in microseconds. fs should be in Hz.
"""
function t_expand(t::Array{Int64,2}, fs::Real)
  fs == 0 && return cumsum(t[:,1])
  dt = round(Int, 1/(fs*μs))
  tt = dt.*ones(Int64, t[end,1])
  tt[t[:,1]] += t[:,2]
  return cumsum(tt)
end

"""
    t = t_collapse(T, fs)

Collapse full time stamp representation T to sparse-difference representation t.
Time stamps in T should be in integer microseconds. fs should be in Hz.
"""
function t_collapse(tt::Array{Int64,1}, fs::Real)
  fs == 0 && return reshape([tt[1]; diff[tt]], length(tt), 1)
  dt = round(Int, 1/(fs*μs))
  ts = [dt; diff(tt)]
  L = length(tt)
  i = find(ts .!= dt)
  t = [[1 tt[1]]; [i ts[i]-dt]]
  (isempty(i) || i[end] != L) && (t = cat(1, t, [L 0]))
  return t
end

function xtmerge(t1::Array{Int64,2}, x1::Array{Float64,1},
                 t2::Array{Int64,2}, x2::Array{Float64,1}, fs::Float64)
  t = [t_expand(t1, fs); t_expand(t2, fs)]
  x = [x1; x2]

  # Sort
  i = sortperm(t)
  t1 = t[i]
  x1 = x[i]

  half_samp = fs == 0 ? 0 : round(Int, 0.5/(fs*μs))
  if minimum(diff(t1)) < half_samp
    xtjoin!((t1,x1),half_samp)
  end
  if half_samp > 0
    t1 = t_collapse(t1, fs)
  end
  return (t1, x1)
end

function xtjoin!(tx,half_samp)
  t1 = tx[1]
  x1 = tx[2]
  J0 = find(diff(t1) .< half_samp)
  while !isempty(J0)
    J1 = J0.+1
    K = [isnan(x1[J0]) isnan(x1[J1])]

    # Average points that are either both NaN or neither Nan
    ii = find(K[:,1]+K[:,2].!=1)
    i0 = J0[ii]
    i1 = J1[ii]
    t1[i0] = round(Int, 0.5*(t1[i0]+t1[i1]))
    x1[i0] = 0.5*(x1[i0]+x1[i1])

    # Delete pairs with only one NaN (and delete i1, while we're here)
    i3 = find(K[:,1].*!K[:,2])
    i4 = find(!K[:,1].*K[:,2])
    II = sort([J0[i3]; J1[i4]; i1])
    deleteat!(t1, II)
    deleteat!(x1, II)

    J0 = find(diff(t1) .< half_samp)
  end
  #tx[1] = t1; tx[2] = x1
  return (t1, x1)
end
