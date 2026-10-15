# Placeholder project so the pipeline has something real to build; replace with Visible's code.
cmake_minimum_required(VERSION 3.16)
project(visible C)

add_library(visible_core src/visible.c)
target_include_directories(visible_core PUBLIC src)
target_compile_options(visible_core PRIVATE -Wall -Wextra)

add_executable(visible src/main.c)
target_link_libraries(visible PRIVATE visible_core)

enable_testing()
add_executable(test_visible tests/test_visible.c)
target_link_libraries(test_visible PRIVATE visible_core)
add_test(NAME test_visible COMMAND test_visible)
