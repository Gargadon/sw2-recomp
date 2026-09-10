# samurai_warriors_2 - ReXGlue Recompiled Project
#
# SDK boilerplate lives in generated/rexglue.cmake.

cmake_minimum_required(VERSION 3.25)
project(samurai_warriors_2 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

include(generated/rexglue.cmake)

# Sources
set(SAMURAIWARRIORS2_SOURCES
    src/main.cpp
    src/heap_diagnostics.cpp
    src/event_fix.cpp
    src/input_diagnostics.cpp
)

if(WIN32)
    add_executable(samurai_warriors_2 WIN32 ${SAMURAIWARRIORS2_SOURCES})
else()
    add_executable(samurai_warriors_2 ${SAMURAIWARRIORS2_SOURCES})
endif()

rexglue_setup_target(samurai_warriors_2 GPU_PLUGINS xenos)

# Retain native function addresses for diagnosing Windows crash dumps.
if(WIN32)
    target_link_options(samurai_warriors_2 PRIVATE "-Wl,/MAP")
endif()
