export translate_resp!, translate_resp, remove_resp!, remove_resp

# =====================================================================

@doc """
    translate_resp!(S, resp_new[, C=cha, wl=γ])
    translate_resp(S, resp_new[, C=cha, wl=γ])

Translate the instrument response of seismic data channels `cha` in `S` to
`resp_new`. Replaces field `:resp` with `resp_new` for all affected channels.

    remove_resp!(S, C=cha, wl=γ])
    remove_resp(S, C=cha, wl=γ])

Remove (flatten to DC) the instrument response of seismic data channels `cha`
in `S`. Replaces field `:resp` with the appropriate (all-pass) response.

    translate_resp!(Ch, resp_new[, wl=γ])
    translate_resp(Ch, resp_new[, wl=γ])

Translate the instrument response of seismic data in SeisChannel object `Ch` to
`resp_new`. Replaces field `:resp` with `resp_new`.

    remove_resp!(Ch, wl=γ])
    remove_resp(Ch, wl=γ])

Remove (flatten to DC) the instrument response of seismic data in `Ch`.
Replaces field `:resp` with the appropriate (all-pass) response.

Keywords:
* **C=cha** restricts response translation to channel(s) `cha`. C can be an
Integer, UnitRange, or Array{Int64,1}. By default, all seismic data channels
have their responses translated to `resp_new`.
* **wl=γ** sets the waterlevel to γ (default: `γ` = eps(Float32) ≈ ~1f-7)
""" translate_resp!
function translate_resp!(S::GphysData,
                    resp_new::Union{PZResp, PZResp64};
                    C::Union{Integer, UnitRange, Array{Int64,1}}=Int64[],
                    wl::Float32=eps(Float32))

  # first ensure that there is something to do
  if C == Int64[]
    C = 1:S.n
  end
  @inbounds for i in C
    if S.resp[i] != resp_new
      break
    end
    if i == last(C)
      @info(string(timestamp(), ": nothing done (no valid responses to translate)."))
      return nothing
    end
  end

  # initialize complex "work" vectors to the largest size we need
  Nx      = nx_max(S, C)
  N2      = nextpow(2, Nx)
  Xw      = Array{Complex{Float32},1}(undef, N2)
  ff_old  = Array{Complex{Float32},1}(undef, N2)
  ff_new  = Array{Complex{Float32},1}(undef, N2)
  f       = Array{Float32,1}(undef, N2)

  GRPS = get_unique(S, ["fs", "resp", "units"], chans=C)
  for grp in GRPS

    # get fs, resp
    j = grp[1]

    # no translating instrument responses unless we're dealing with seismometers
    uu = lowercase(S.units[j])
    uu in ("m/s", "m/s2", "m") || continue
    # TO DO: add control to prevent erroneous response tranlsation of GPS data

    # onward
    resp_old = deepcopy(S.resp[j])
    fs = Float32(S.fs[j])

    # for accelerometers, working *in* acceleration units, we check: are there any poles below the nyquist?
    if uu == "m/s2"
      P = resp_old.p
      k = trues(length(P))
      for (i,p) in enumerate(P)
        if abs(p)/pi ≤ fs # equivalent to abs(p)/2pi ≤ fn/2 which is the true condition
          k[i] = false
        end
      end
      deleteat!(P, k)

      # Most accelerometers have two complex zeros at the origin, but many XML resp files don't show it.
      if isempty(resp_old.z)
        resp_old.z = map(eltype(resp_old.z), [0.0 + 0.0im, 0.0 - 0.0im])
      end
    end

    if fs > 0.0f0 && resp_old != resp_new
      # get views to segments from each target channel
      (L,X) = get_views(S, grp)

      # initialize Nx, N2, xre
      Nx = first(L)
      N2 = nextpow(2, Nx)
      xfl, xre = update_resp_vecs!(Xw, f, ff_old, ff_new, N2)
      update_resp!(f, ff_old, ff_new, N2, fs, resp_old, resp_new, wl)

      j = 0
      while j < length(L)
        j = j + 1
        if L[j] != Nx
          Nx = L[j]
          N2 = nextpow(2, Nx)
          xfl, xre = update_resp_vecs!(Xw, f, ff_old, ff_new, N2)
          update_resp!(f, ff_old, ff_new, N2, fs, resp_old, resp_new, wl)
        end

        # copy X[j] to Xw and compute FFT
        fill!(Xw, zero(Complex{Float32}))
        copyto!(Xw, 1, X[j], 1, Nx)
        fft!(Xw)
        broadcast!(*, Xw, Xw, ff_new)
        ifft!(Xw)
        copyto!(X[j], 1, xre, 1, Nx)
      end
      for k in grp
        setindex!(S.resp, deepcopy(resp_new), k)
      end
    end
  end
 return nothing
end

@doc (@doc translate_resp!)
function translate_resp( S::GphysData,
                    resp_new::Union{PZResp, PZResp64};
                    C::Union{Integer, UnitRange, Array{Int64,1}}=Int64[],
                    wl::Float32=eps(Float32))

  U = deepcopy(S)
  translate_resp!(U, resp_new, C=C, wl=wl)
  return U
end

@doc (@doc translate_resp!)
function translate_resp!(C::GphysChannel,
                    resp_new::Union{PZResp, PZResp64};
                    wl::Float32=eps(Float32))

  # first ensure that there is something to do
  uu = lowercase(C.units)
  fs = Float32(C.fs)
  if ((C.resp == resp_new) || ((uu in ("m/s", "m/s2", "m")) == false) || (fs ≤ 0.0f0))
    @info(string(timestamp(), ": nothing done (no valid responses to translate)."))
    return nothing
  end

  # initialize complex "work" vectors to the largest size we need
  Nx      = nx_max(C)
  N2      = nextpow(2, Nx)
  Xw      = zeros(Complex{Float32}, N2)
  ff_old  = Array{Complex{Float32},1}(undef, N2)
  ff_new  = Array{Complex{Float32},1}(undef, N2)
  f       = Array{Float32,1}(undef, N2)

  # for accelerometers, working *in* acceleration units, we check: are there any poles below the nyquist?
  if uu == "m/s2"
    P = C.resp.p
    k = trues(length(P))
    for (i,p) in enumerate(P)
      if abs(p)/pi ≤ fs # equivalent to abs(p)/2pi ≤ fn/2 which is the true condition
        k[i] = false
      end
    end
    deleteat!(P, k)

    # Most accelerometers have two complex zeros at the origin, but many XML resp files don't show it.
    if isempty(C.resp.z)
      C.resp.z = map(eltype(C.resp.z), [0.0 + 0.0im, 0.0 - 0.0im])
    end
  end

  # Get views
  if size(C.t,1) == 2
    xfl, xre = update_resp_vecs!(Xw, f, ff_old, ff_new, N2)
    update_resp!(f, ff_old, ff_new, N2, fs, C.resp, resp_new, wl)

    # copy X[j] to Xw and compute FFT
    copyto!(Xw, 1, C.x, 1, Nx)
    fft!(Xw)
    broadcast!(*, Xw, Xw, ff_new)
    ifft!(Xw)
    copyto!(C.x, 1, xre, 1, Nx)
  else
    (L,X) = get_views(C)
    xfl = reinterpret(Float32, Xw)
    xre = view(xfl, 1:2:2*N2-1)
    update_resp!(f, ff_old, ff_new, N2, fs, C.resp, resp_new, wl)

    j = 0
    while j < length(L)
      j = j + 1

      if L[j] != Nx
        Nx = L[j]
        N2 = nextpow(2, Nx)
        xfl, xre = update_resp_vecs!(Xw, f, ff_old, ff_new, N2)
        update_resp!(f, ff_old, ff_new, N2, fs, C.resp, resp_new, wl)
      end

      if j > 1
        fill!(Xw, zero(Complex{Float32}))
      end

      copyto!(Xw, 1, X[j], 1, Nx)
      fft!(Xw)
      broadcast!(*, Xw, Xw, ff_new)
      ifft!(Xw)
      copyto!(X[j], 1, xre, 1, Nx)
    end
  end
  C.resp = deepcopy(resp_new)
  return nothing
end

@doc (@doc translate_resp!)
function translate_resp(C::GphysChannel,
                        resp_new::Union{PZResp, PZResp64};
                        wl::Float32=eps(Float32))

  U = deepcopy(C)
  translate_resp!(U, resp_new, wl=wl)
  return U
end

@doc (@doc translate_resp!)
remove_resp!(S::GphysData;
             C::Union{Integer, UnitRange, Array{Int64,1}}=Int64[],
             wl::Float32=eps(Float32)) = translate_resp!(S, flat_resp, C=C, wl=wl)

@doc (@doc translate_resp!)
remove_resp(S::GphysData;
            C::Union{Integer, UnitRange, Array{Int64,1}}=Int64[],
            wl::Float32=eps(Float32)) = translate_resp(S, flat_resp, C=C, wl=wl)

@doc (@doc translate_resp!)
remove_resp!(Ch::GphysChannel;
             wl::Float32=eps(Float32)) = translate_resp!(Ch, flat_resp, wl=wl)

@doc (@doc translate_resp!)
remove_resp(Ch::GphysChannel;
            wl::Float32=eps(Float32)) = translate_resp(Ch, flat_resp, wl=wl)
