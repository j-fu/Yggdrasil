# Note that this script can accept some limited command-line arguments, run
# `julia build_tarballs.jl --help` to see a usage message.
using BinaryBuilder
import Pkg: PackageSpec
import Pkg.Types: VersionSpec

const name = "libsingular_julia"
const version = VersionNumber(0, 3, julia_version.minor)

# Collection of sources required to build libsingular-julia
const sources = [
    GitSource("https://github.com/oscar-system/libsingular-julia", "b63a76c1634dc680485f5b7d4c81235e39d714bd"),
]

# Bash recipe for building across all platforms
const script = raw"""
cmake libsingular-j*/ -B build \
   -DJulia_PREFIX="$prefix" \
   -DSingular_PREFIX="$prefix" \
   -DCMAKE_INSTALL_PREFIX="$prefix" \
   -DCMAKE_FIND_ROOT_PATH="$prefix" \
   -DCMAKE_TOOLCHAIN_FILE="${CMAKE_TARGET_TOOLCHAIN}" \
   -DCMAKE_CXX_STANDARD=14 \
   -DCMAKE_BUILD_TYPE=Release

VERBOSE=ON cmake --build build --config Release --target install -- -j${nproc}

install_license libsingular-j*/LICENSE.md
"""

# These are the platforms we will build for by default, unless further
# platforms are passed in on the command line
platforms = supported_platforms()

# skip i686 musl builds (not supported by libjulia_jll)
filter!(p -> !(Sys.islinux(p) && libc(p) == "musl" && arch(p) == "i686"), platforms)

# skip PowerPC builds in Julia 1.3 (not supported by libjulia_jll)
if julia_version < v"1.4"
    filter!(p -> !(Sys.islinux(p) && arch(p) == "powerpc64le"), platforms)
end

platforms = filter!(!Sys.iswindows, platforms) # Singular does not support Windows
platforms = expand_cxxstring_abis(platforms)

# The products that we will ensure are always built
const products = [
    LibraryProduct("libsingular_julia", :libsingular_julia),
]

# Dependencies that must be installed before this package can be built
const dependencies = [
    BuildDependency(PackageSpec(name="libjulia_jll", version=julia_version)),
    Dependency("libcxxwrap_julia_jll"),
    Dependency(PackageSpec(name="Singular_jll", version=VersionSpec("401.390"))), # require 4.1.4-DEV snapshot
    BuildDependency(PackageSpec(name="GMP_jll", version=v"6.1.2")),
    BuildDependency(PackageSpec(name="MPFR_jll", version=v"4.0.2")),
]

# Build the tarballs, and possibly a `build.jl` as well.
build_tarballs(ARGS, name, version, sources, script, platforms, products, dependencies;
    preferred_gcc_version=v"8",
    julia_compat = "$(julia_version.major).$(julia_version.minor)")
