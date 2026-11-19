# Builds prebuilt tree-sitter grammar libraries for all supported platforms,
# packages them as the platform-specific `tree-sitter-grammars` artifacts and
# binds them in `Artifacts.toml`.
#
# Run it through `build.sh` (Linux container with zig), never on the host:
# artifact tree hashes depend on file permissions, which Windows cannot represent.
#
# The produced tarballs in `deps/grammars/out/` must be uploaded to
# `<URL_BASE>/` (by default the `grammars/` folder of ParSitter.jl_artifacts).

using Pkg.Artifacts
using Base.BinaryPlatforms
using SHA

const PKG_ROOT = dirname(dirname(@__DIR__))
const ARTIFACTS_TOML = joinpath(PKG_ROOT, "Artifacts.toml")
const OUT_DIR = joinpath(@__DIR__, "out")
const URL_BASE = get(
    ENV, "PARSITTER_GRAMMARS_URL",
    "https://github.com/zgornel/ParSitter.jl_artifacts/raw/master/grammars"
)
const ZIG = get(ENV, "ZIG", "zig")
const SOURCES_URL = "https://github.com/zgornel/ParSitter.jl_artifacts/raw/master/languages"

# Grammar sources: tree-sitter language name => (source tarball, sha256).
# The library for language `name` exports `tree_sitter_<name>` and is
# shipped as `<name>.<ext>`; ParSitter passes `--lang-name <name>`.
const GRAMMARS = [
    "r" => ("$SOURCES_URL/tree-sitter-r.tar.gz", "8da16f8a7c9aaab257c49a53c52acb7121389ff4a16bc12ac114a685bb28c72d"),
    "python" => ("$SOURCES_URL/tree-sitter-python.tar.gz", "7bce887eb2f33e94bf74a69645cf5138d4096720e54fd3269a6124c06b93c584"),
    "julia" => ("$SOURCES_URL/tree-sitter-julia.tar.gz", "edc0a6edcbaa6d183a0fc002319312dcbc3d04d86ffb9d6cfb6f83502b1b3e08"),
    "c" => ("$SOURCES_URL/tree-sitter-c.tar.gz", "f3a2cdfbca39c79f60baf2ef62b42084c609782c76485de457ba36ff65d51baf"),
    "c_sharp" => ("$SOURCES_URL/tree-sitter-c-sharp.tar.gz", "d7e9db699ad8ebd234cb6922d285efe128a408db3737d4fa0bab6c668e0fc5e6"),
]

# Platforms matching the `tree-sitter` CLI artifact: (platform, zig target, library extension)
const TARGETS = [
    (Platform("x86_64", "linux"), "x86_64-linux-gnu.2.17", "so"),
    (Platform("aarch64", "linux"), "aarch64-linux-gnu.2.17", "so"),
    (Platform("x86_64", "macos"), "x86_64-macos", "dylib"),
    (Platform("aarch64", "macos"), "aarch64-macos", "dylib"),
    (Platform("x86_64", "windows"), "x86_64-windows-gnu", "dll"),
]

function fetch_sources(workdir)
    srcdirs = Dict{String, String}()
    for (name, (url, sha)) in GRAMMARS
        tarball = joinpath(workdir, "$name.tar.gz")
        run(`curl -fsSL -o $tarball $url`)
        actual = bytes2hex(open(sha256, tarball))
        actual == sha || error("sha256 mismatch for $url: $actual != $sha")
        dir = mkpath(joinpath(workdir, name))
        run(`tar -xzf $tarball -C $dir`)
        srcdirs[name] = joinpath(dir, "src")
    end
    return srcdirs
end

function compile(srcdir, name, target, ext, destdir)
    sources = filter(isfile, joinpath.(srcdir, ["parser.c", "scanner.c"]))
    pic = ext == "dll" ? String[] : ["-fPIC"]
    return mktempdir() do tmp
        lib = joinpath(tmp, "$name.$ext")
        run(`$ZIG cc -target $target -shared $pic -O2 -std=c11 -I $srcdir $sources -o $lib`)
        cp(lib, joinpath(destdir, "$name.$ext"))  # leave .lib/.pdb side files behind
    end
end

function main()
    mkpath(OUT_DIR)
    return mktempdir() do workdir
        srcdirs = fetch_sources(workdir)
        for (platform, target, ext) in TARGETS
            @info "Building grammars for $(triplet(platform))"
            hash = create_artifact() do dir
                for (name, _) in GRAMMARS
                    compile(srcdirs[name], name, target, ext, dir)
                end
            end
            tarball_name = "tree-sitter-grammars-$(triplet(platform)).tar.gz"
            tarball = joinpath(OUT_DIR, tarball_name)
            archive_artifact(hash, tarball)
            sha = bytes2hex(open(sha256, tarball))
            bind_artifact!(
                ARTIFACTS_TOML, "tree-sitter-grammars", hash;
                platform, download_info = [("$URL_BASE/$tarball_name", sha)], force = true
            )
            @info "  $tarball_name" hash sha
        end
    end
end

main()
