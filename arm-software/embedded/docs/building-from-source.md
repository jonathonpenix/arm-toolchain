# Building from source

## Host platforms

Arm Toolchain for Embedded is built and tested on Linux Ubuntu, macOS and Windows.

Please refer to the _Host Platforms_ section in the [README](https://github.com/arm/arm-toolchain/blob/arm-software/arm-software/embedded/README.md#host-platforms), for details.

## Installing prerequisites

### Building

The build requires the following software to be installed: 
* [Software required by LLVM](https://llvm.org/docs/GettingStarted.html#software)
* [Meson](https://mesonbuild.com/Getting-meson.html)
* [Git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
* [Ninja](https://ninja-build.org/)

### Testing

Library testing requires:
* [QEMU](https://www.qemu.org/download/)

Testing with QEMU is enabled by default, but can be disabled using the 
`-DENABLE_QEMU_TESTING=OFF` CMake option if testing is not required or QEMU is
not installed.

## Customizing

To build additional library variants, add the JSON configuration under
[arm-multilib/json/variants](../arm-multilib/json/variants/) and register it in
[multilib.json](../arm-multilib/json/multilib.json).

To build additional LLVM tools, edit the `CMakeLists.txt` by adding required
tools to the `LLVM_DISTRIBUTION_COMPONENTS` CMake list.

## Building

The commands in the sections below assume you are in the `arm-toolchain/arm-software/embedded` directory.

The toolchain can be built directly with CMake.

```
export CC=clang
export CXX=clang++
mkdir build
cd build
cmake .. -GNinja -DFETCHCONTENT_QUIET=OFF
ninja llvm-toolchain
```

To make it easy to get started, the above command checks out and patches the picolibc Git repo automatically.
If you prefer you can check out and patch the repos manually and use those, see commands below.

Note, the patching of the llvm-project fork is not done automatically. See [Divergences from upstream](#Divergences-from-upstream)

If you check out repos manually then it is your responsibility to ensure that the correct revisions are checked out - see `versions.json` to identify these - and to apply the necessary patches from the [patches](../patches) folder.

```
export CC=clang
export CXX=clang++
mkdir repos
git -C repos clone https://github.com/picolibc/picolibc.git
git -C repos/picolibc am -k "$PWD"/patches/picolibc/*.patch
git -C ../.. am -k "$PWD"/patches/llvm-project/*.patch
mkdir build
cd build
cmake .. -GNinja -DFETCHCONTENT_SOURCE_DIR_PICOLIBC=../repos/picolibc
ninja llvm-toolchain
```

### Testing the toolchain

```
ninja check-llvm-toolchain
```

### Packaging the toolchain

After building, create a zip or tar.xz file as appropriate for the platform:
```
ninja package-llvm-toolchain
```

## Known limitations
* Depending on the state of the sources, build errors may occur when
  the latest revisions of the llvm-project & picolibc repos are used.
* Undefined `__aeabi_mem*` symbols with `-nostdlib`
  When the `COMPILER_RT_EXCLUDE_LIBC_PROVIDED_ARM_AEABI_BUILTINS` flag is enabled,
  the following ARM AEABI memory builtins are excluded from the ATFE `compiler-rt` build:
  ```
    __aeabi_memcmp
    __aeabi_memset
    __aeabi_memcpy
    __aeabi_memmove
  ```
  This flag `COMPILER_RT_EXCLUDE_LIBC_PROVIDED_ARM_AEABI_BUILTINS` is enabled by default when
  using picolibc and newlib as these functions are provided by the C library in both cases.
  However, if the toolchain is used with `-nostdlib` and the C library is not linked in, users relying
  solely on `compiler-rt` will have undefined symbol errors for these AEABI functions. To prevent the
  generation of these AEABI function calls by the compiler, pass the following option to the compiler:
  ```
  -meabi gnu
  ```

## Divergences from upstream

See the [patches](../patches) directory for the current set of differences from upstream.

The patches for `llvm-project` and `picolibc` are generally required for building and
successfully running all tests.

The `newlib` patches are required to build `newlib`.

If not already applied, these must be done so manually before building, like below:
```
git -C arm-toolchain am -k "$PWD"/patches/llvm-project/*.patch
git -C repos/picolibc am -k "$PWD"/patches/picolibc/*.patch
```

## Building individual library variants

When working on library code, it may be useful to build a library variant
without having to rebuild the entire toolchain.

Each variant is built using the `arm-runtimes` sub-project, and can be
configured and built directly if you provide a path to a LLVM build or install.

The default CMake arguments to build a particular variant are stored in a JSON
format in the `arm-multilib/json/variants` folder, which can be loaded at
configuration with the `-DVARIANT_JSON` setting. Any additional options
provided on the command line will override values from the JSON. `-DC_LIBRARY`
will be required to set which library to build, and `-DLLVM_BINARY_DIR` should
point to the top-level directory of a build or install of LLVM.

(The actual binaries, such as `clang`, are expected to be in
`$LLVM_BINARY_DIR/bin`, not `$LLVM_BINARY_DIR` itself. For example, if you're
using the results of a full build of this toolchain itself in another
directory, then you should set `LLVM_BINARY_DIR` to point at the `llvm`
subdirectory of the previous build tree, not the `llvm/bin` subdirectory.)

For example, to build the `armv7a_soft_nofp` variant using `picolibc`, using
an existing LLVM build and source checkouts:

```
cd arm-software/embedded
mkdir build-lib
cd build-lib
cmake ../arm-runtimes -G Ninja \
  -DVARIANT_JSON=../arm-multilib/json/variants/armv7a_soft_nofp.json \
  -DC_LIBRARY=picolibc \
  -DLLVM_BINARY_DIR=/path/to/llvm \
  -DFETCHCONTENT_SOURCE_DIR_PICOLIBC=/path/to/picolibc
ninja
```

If enabled and the required test executor available, tests can be run with
using specific test targets:
`ninja check-picolibc`
`ninja check-compiler-rt`
`ninja check-cxx`
`ninja check-cxxabi`
`ninja check-unwind`

Alternatively, `ninja check-all` runs all enabled tests. 

## Building sets of libraries

As well as individual libraries, it is also possible to build a set of
libraries without rebuilding the entire toolchain. The `arm-multilib`
sub-project builds and collects multiple libraries, and generates a
`multilib.yaml` file to map compile flags to variants.

The `arm-multilib/multilib.json` file defines which variants are built and
their order in the mapping. This can be used to configure the project directly

For example, building the picolibc variants using an existing LLVM build and
source checkouts:
```
cd arm-software/embedded
mkdir build-multilib
cd build-multilib
cmake ../arm-multilib -G Ninja \
  -DMULTILIB_JSON=../arm-multilib/json/multilib.json \
  -DC_LIBRARY=picolibc \
  -DLLVM_BINARY_DIR=/path/to/llvm \
  -DFETCHCONTENT_SOURCE_DIR_PICOLIBC=/path/to/picolibc
ninja
```
To only build a subset of the variants defined in the JSON file,
the `-DENABLE_VARIANTS` option controls which variants to build.
E.g, `-DENABLE_VARIANTS="aarch64a;armv7a_soft_nofp"` only builds the two 
variants of `aarch64a` and `armv7a_soft_nofp`.

If enabled and the required test executor available, tests can be run with
using specific test targets:

`ninja check-picolibc`
`ninja check-compiler-rt`
`ninja check-cxx`
`ninja check-cxxabi`
`ninja check-unwind`

Alternatively, `ninja check-all` runs all enabled tests.
`ninja check-<VARIANT_NAME>` runs all the tests for that specific variant.
