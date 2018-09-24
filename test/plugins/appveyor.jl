user = gitconfig["github.user"]
t = Template(; user=me)
temp_dir = mktempdir()
pkg_dir = joinpath(temp_dir, test_pkg)

@testset "AppVeyor" begin
    @testset "Plugin creation" begin
        p = AppVeyor()
        @test isempty(p.gitignore)
        @test p.src == joinpath(PkgTemplates.DEFAULTS_DIR, "appveyor.yml")
        @test p.dest == ".appveyor.yml"
        @test p.badges == [
            Badge(
                "Build Status",
                "https://ci.appveyor.com/api/projects/status/github/{{USER}}/{{PKGNAME}}.jl?svg=true",
                "https://ci.appveyor.com/project/{{USER}}/{{PKGNAME}}-jl",
            ),
        ]
        @test isempty(p.view)
        p = AppVeyor(; config_file=nothing)
        @test p.src === nothing
        p = AppVeyor(; config_file=test_file)
        @test p.src == test_file
        @test_throws ArgumentError AppVeyor(; config_file=fake_path)
    end

    @testset "Badge generation" begin
        p = AppVeyor()
        @test badges(p, user, test_pkg) == ["[![Build Status](https://ci.appveyor.com/api/projects/status/github/$user/$test_pkg.jl?svg=true)](https://ci.appveyor.com/project/$user/$test_pkg-jl)"]
    end

    @testset "File generation" begin
        # Without a coverage plugin in the template, there should be no post-test step.
        p = AppVeyor()
        @test gen_plugin(p, t, temp_dir, test_pkg) == [".appveyor.yml"]
        @test isfile(joinpath(pkg_dir, ".appveyor.yml"))
        appveyor = read(joinpath(pkg_dir, ".appveyor.yml"), String)
        @test !occursin("coverage=true", appveyor)
        @test !occursin("after_test", appveyor)
        @test !occursin("Codecov.submit", appveyor)
        @test !occursin("Coveralls.submit", appveyor)
        rm(joinpath(pkg_dir, ".appveyor.yml"))

        # Generating the plugin with CodeCov in the template should create a post-test step.
        t.plugins[CodeCov] = CodeCov()
        gen_plugin(p, t, temp_dir, test_pkg)
        delete!(t.plugins, CodeCov)
        appveyor = read(joinpath(pkg_dir, ".appveyor.yml"), String)
        @test occursin("coverage=true", appveyor)
        @test occursin("after_test", appveyor)
        @test occursin("Codecov.submit", appveyor)
        @test !occursin("Coveralls.submit", appveyor)
        rm(joinpath(pkg_dir, ".appveyor.yml"))

        # Coveralls should do the same.
        t.plugins[Coveralls] = Coveralls()
        gen_plugin(p, t, temp_dir, test_pkg)
        delete!(t.plugins, Coveralls)
        appveyor = read(joinpath(pkg_dir, ".appveyor.yml"), String)
        @test occursin("coverage=true", appveyor)
        @test occursin("after_test", appveyor)
        @test occursin("Coveralls.submit", appveyor)
        @test !occursin("Codecov.submit", appveyor)
        rm(joinpath(pkg_dir, ".appveyor.yml"))

        p = AppVeyor(; config_file=nothing)
        @test isempty(gen_plugin(p, t, temp_dir, test_pkg))
        @test !isfile(joinpath(pkg_dir, ".appveyor.yml"))
    end
end

rm(temp_dir; recursive=true)
