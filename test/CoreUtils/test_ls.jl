printstyled("  safe_isfile\n", color=:light_green)
@test safe_isfile("runtests.jl") == true
@test safe_isfile("foo.jl") == false

printstyled("  safe_isdir\n", color=:light_green)
@test safe_isdir("SampleFiles") == true
@test safe_isdir("Roms") == false

printstyled("  ls\n", color=:light_green)

cfile = path*"/SampleFiles/Restricted/03_02_27_20140927.euc.ch"
@test any([occursin("test", i) for i in ls()])

S = [
      "CoreUtils/",
      "CoreUtils/test_ls.jl",
      "CoreUtils/poo",
      "SampleFiles/UW/*W",
      "SampleFiles/UW/02*o",
      "CoreUtils/test_*"
    ]
S_expect =  [
              ["test_calculus.jl", "test_ls.jl", "test_poly.jl", "test_time.jl", "test_typ2code.jl"],
              ["test_ls.jl"],
              String[],
              ["00012502123W", "99011116541W"],
              ["02062915175o", "02062915205o"],
              ["test_calculus.jl", "test_ls.jl", "test_poly.jl", "test_time.jl", "test_typ2code.jl"],
            ]

# Test that ls returns the same files as `ls -1`
for (n,v) in enumerate(S)
  files = String[splitdir(i)[2] for i in ls(v)]
  # if Sys.iswindows() == false
    expected = S_expect[n]
    @test files == expected
  # end
  [@test isfile(f) for f in ls(v)]
end
# Test that ls invokes find_regex under the right circumstances
@test change_sep(ls(S[5])) == change_sep(regex_find("SampleFiles/", r"02.*o$"))

if safe_isfile(cfile)
  T = path .* [
                "/SampleFiles/Restricted/*.cnt",
                "/SampleFiles/*",
                "/SampleFiles/Restricted/2014092709*cnt"
              ]
  T_expect =  [63, 535, 60]
  if safe_isfile(path .* "/SampleFiles/restricted.tar.gz")
    T_expect[2] += 1
  end

  # Test that ls finds the same number of files as bash `ls -1`
  for (n,v) in enumerate(T)
    files = ls(v)
    @test (isempty(files) == false)
    @test (length(files) == T_expect[n])
    [@test isfile(f) for f in files]
  end

  # Test that ls invokes find_regex under the right circumstances
  @test change_sep(ls(T[2])) == change_sep(regex_find("SampleFiles", r".*$"))
  @test change_sep(ls(T[3])) == change_sep(regex_find("SampleFiles", r"Restricted/2014092709.*cnt$"))
else
  printstyled("  extended ls tests skipped. (files not found; is this Appveyor?)\n", color=:green)
end

if Sys.iswindows()
  @test safe_isfile("http://google.com") == false
  @test safe_isdir("http://google.com") == false
end
