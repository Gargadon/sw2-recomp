# samurai_warriors_2 - ReXGlue Recompiled Project
#
# SDK boilerplate lives in generated/rexglue.cmake.

cmake_minimum_required(VERSION 3.25)
project(samurai_warriors_2 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(SW2_PGO "OFF" CACHE STRING "PGO mode: OFF, GENERATE, or USE")
set_property(CACHE SW2_PGO PROPERTY STRINGS OFF GENERATE USE)
set(SW2_PGO_PROFILE "${CMAKE_CURRENT_SOURCE_DIR}/pgo/sw2.profdata" CACHE FILEPATH
    "Merged Clang instrumentation profile used when SW2_PGO=USE")

include(generated/rexglue.cmake)

# Sources
set(SAMURAIWARRIORS2_SOURCES
    src/main.cpp
    src/heap_diagnostics.cpp
    src/event_fix.cpp
    src/input_diagnostics.cpp
    src/dlc_installer.cpp
)

if(WIN32)
    add_executable(samurai_warriors_2 WIN32 ${SAMURAIWARRIORS2_SOURCES})
else()
    add_executable(samurai_warriors_2 ${SAMURAIWARRIORS2_SOURCES})
endif()

rexglue_setup_target(samurai_warriors_2 GPU_PLUGINS xenos)

# The installed SDK toolchain leaves CMAKE_CXX_FLAGS_RELEASE empty. Generated
# guest code is prohibitively slow without compiler optimization, affecting
# video playback, simulation speed, and how often the game polls input.
foreach(sw2_target IN ITEMS
        samurai_warriors_2
        samurai_warriors_2_recomp
        samurai_warriors_2_SW2XL_US)
    if(TARGET ${sw2_target})
        target_compile_options(${sw2_target} PRIVATE
            $<$<CONFIG:Release>:-O3>
            $<$<CONFIG:Release>:-DNDEBUG>
            $<$<CONFIG:Release>:-flto=thin>
        )
        if(SW2_PGO STREQUAL "GENERATE")
            target_compile_options(${sw2_target} PRIVATE -fprofile-instr-generate)
            target_link_options(${sw2_target} PRIVATE -fprofile-instr-generate)
        elseif(SW2_PGO STREQUAL "USE")
            if(NOT EXISTS "${SW2_PGO_PROFILE}")
                message(FATAL_ERROR "PGO profile not found: ${SW2_PGO_PROFILE}")
            endif()
            target_compile_options(${sw2_target} PRIVATE
                "-fprofile-instr-use=${SW2_PGO_PROFILE}")
            target_link_options(${sw2_target} PRIVATE
                "-fprofile-instr-use=${SW2_PGO_PROFILE}")
        elseif(NOT SW2_PGO STREQUAL "OFF")
            message(FATAL_ERROR "SW2_PGO must be OFF, GENERATE, or USE")
        endif()
    endif()
endforeach()

foreach(sw2_link_target IN ITEMS samurai_warriors_2 samurai_warriors_2_SW2XL_US)
    if(TARGET ${sw2_link_target})
        target_link_options(${sw2_link_target} PRIVATE
            $<$<CONFIG:Release>:-flto=thin>
            $<$<CONFIG:Release>:-Wl,/OPT:REF>
            $<$<CONFIG:Release>:-Wl,/OPT:ICF>
        )
    endif()
endforeach()

if(WIN32 AND TARGET samurai_warriors_2_SW2XL_US)
    target_sources(samurai_warriors_2_SW2XL_US PRIVATE src/event_fix.cpp)
    add_custom_target(sw2_patch_xl_codegen
        COMMAND powershell -NoProfile -ExecutionPolicy Bypass
            -File "${CMAKE_CURRENT_SOURCE_DIR}/patch-xl-codegen.ps1"
        DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/generated/sw2xl_us/samurai_warriors_2_init.cpp"
        VERBATIM
    )
    add_dependencies(samurai_warriors_2_SW2XL_US sw2_patch_xl_codegen)
endif()

# Retain native function addresses for diagnosing Windows crash dumps.
if(WIN32)
    target_link_options(samurai_warriors_2 PRIVATE "-Wl,/MAP")
    if(TARGET samurai_warriors_2_SW2XL_US)
        target_link_options(samurai_warriors_2_SW2XL_US PRIVATE
            "-Wl,/MAP:${CMAKE_CURRENT_BINARY_DIR}/samurai_warriors_2_SW2XL_US.map")
    endif()
endif()
