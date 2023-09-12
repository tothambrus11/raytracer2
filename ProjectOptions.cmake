include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


macro(raytracer2_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)
    set(SUPPORTS_UBSAN ON)
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    set(SUPPORTS_ASAN ON)
  endif()
endmacro()

macro(raytracer2_setup_options)
  option(raytracer2_ENABLE_HARDENING "Enable hardening" ON)
  option(raytracer2_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    raytracer2_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    raytracer2_ENABLE_HARDENING
    OFF)

  raytracer2_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR raytracer2_PACKAGING_MAINTAINER_MODE)
    option(raytracer2_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(raytracer2_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(raytracer2_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(raytracer2_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(raytracer2_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(raytracer2_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(raytracer2_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(raytracer2_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(raytracer2_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(raytracer2_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(raytracer2_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(raytracer2_ENABLE_PCH "Enable precompiled headers" OFF)
    option(raytracer2_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(raytracer2_ENABLE_IPO "Enable IPO/LTO" ON)
    option(raytracer2_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(raytracer2_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(raytracer2_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(raytracer2_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(raytracer2_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(raytracer2_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(raytracer2_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(raytracer2_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(raytracer2_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(raytracer2_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(raytracer2_ENABLE_PCH "Enable precompiled headers" OFF)
    option(raytracer2_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      raytracer2_ENABLE_IPO
      raytracer2_WARNINGS_AS_ERRORS
      raytracer2_ENABLE_USER_LINKER
      raytracer2_ENABLE_SANITIZER_ADDRESS
      raytracer2_ENABLE_SANITIZER_LEAK
      raytracer2_ENABLE_SANITIZER_UNDEFINED
      raytracer2_ENABLE_SANITIZER_THREAD
      raytracer2_ENABLE_SANITIZER_MEMORY
      raytracer2_ENABLE_UNITY_BUILD
      raytracer2_ENABLE_CLANG_TIDY
      raytracer2_ENABLE_CPPCHECK
      raytracer2_ENABLE_COVERAGE
      raytracer2_ENABLE_PCH
      raytracer2_ENABLE_CACHE)
  endif()

  raytracer2_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (raytracer2_ENABLE_SANITIZER_ADDRESS OR raytracer2_ENABLE_SANITIZER_THREAD OR raytracer2_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(raytracer2_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(raytracer2_global_options)
  if(raytracer2_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    raytracer2_enable_ipo()
  endif()

  raytracer2_supports_sanitizers()

  if(raytracer2_ENABLE_HARDENING AND raytracer2_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR raytracer2_ENABLE_SANITIZER_UNDEFINED
       OR raytracer2_ENABLE_SANITIZER_ADDRESS
       OR raytracer2_ENABLE_SANITIZER_THREAD
       OR raytracer2_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${raytracer2_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${raytracer2_ENABLE_SANITIZER_UNDEFINED}")
    raytracer2_enable_hardening(raytracer2_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(raytracer2_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(raytracer2_warnings INTERFACE)
  add_library(raytracer2_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  raytracer2_set_project_warnings(
    raytracer2_warnings
    ${raytracer2_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(raytracer2_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    configure_linker(raytracer2_options)
  endif()

  include(cmake/Sanitizers.cmake)
  raytracer2_enable_sanitizers(
    raytracer2_options
    ${raytracer2_ENABLE_SANITIZER_ADDRESS}
    ${raytracer2_ENABLE_SANITIZER_LEAK}
    ${raytracer2_ENABLE_SANITIZER_UNDEFINED}
    ${raytracer2_ENABLE_SANITIZER_THREAD}
    ${raytracer2_ENABLE_SANITIZER_MEMORY})

  set_target_properties(raytracer2_options PROPERTIES UNITY_BUILD ${raytracer2_ENABLE_UNITY_BUILD})

  if(raytracer2_ENABLE_PCH)
    target_precompile_headers(
      raytracer2_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(raytracer2_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    raytracer2_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(raytracer2_ENABLE_CLANG_TIDY)
    raytracer2_enable_clang_tidy(raytracer2_options ${raytracer2_WARNINGS_AS_ERRORS})
  endif()

  if(raytracer2_ENABLE_CPPCHECK)
    raytracer2_enable_cppcheck(${raytracer2_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(raytracer2_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    raytracer2_enable_coverage(raytracer2_options)
  endif()

  if(raytracer2_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(raytracer2_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(raytracer2_ENABLE_HARDENING AND NOT raytracer2_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR raytracer2_ENABLE_SANITIZER_UNDEFINED
       OR raytracer2_ENABLE_SANITIZER_ADDRESS
       OR raytracer2_ENABLE_SANITIZER_THREAD
       OR raytracer2_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    raytracer2_enable_hardening(raytracer2_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
