# Retrieve the canonical `-march` string given a set of valid compiler flags.
# We do this by compiling a simple C file and parsing llvm-readelf's output
# to get the canonical arch string.
# 
# We require the following arguments:
# - `compiler_path` is expected to contain the path to the compiler to use to
#    build the test C file.
# - `build_args` is expected to be a CMake list (';' separated) of the compiler
#   commands to use (typically `--target=`, `-march=`, etc.). These arguments
#   are expected to all be valid and be sufficient to determine the correct set
#   of extensions.
# - `march_out` should contain the variable to be used to return the
#   canonicalized arch string.
function(get_canonical_riscv_march compiler_path build_args march_out)
    set(simple_source ${CMAKE_BINARY_DIR}${CMAKE_FILES_DIRECTORY}/simple.c)
    file(WRITE ${simple_source} "int main(void) {}\n")

    set(simple_obj_file ${CMAKE_BINARY_DIR}${CMAKE_FILES_DIRECTORY}/simple.o)
    set(command_args ${simple_source} ${build_args} "-c" "-o" ${simple_obj_file})
    execute_process(
        COMMAND ${compiler_path}
        ${command_args}
        RESULT_VARIABLE return_val
    )
    if(NOT return_val EQUAL 0)
        message(FATAL_ERROR "Unable to compile C file to normalize `-march` string")
    endif()
    execute_process(
        COMMAND ${LLVM_BINARY_DIR}/bin/llvm-readelf${CMAKE_EXECUTABLE_SUFFIX}
        -A ${simple_obj_file}
        RESULT_VARIABLE return_val
        OUTPUT_VARIABLE readelf_output
    )
    if(NOT return_val EQUAL 0)
        message(FATAL_ERROR "Unable retrieve canonicalized `-march` string from llvm-readelf")
    endif()
    string(REGEX MATCH
            "Tag: 5[ \t\r\n]+TagName: arch[ \t\r\n]+Value: ([A-Za-z0-9_]+)"
            out_var "${readelf_output}"
    )

    set(${march_out} ${CMAKE_MATCH_1} PARENT_SCOPE)
endfunction()
