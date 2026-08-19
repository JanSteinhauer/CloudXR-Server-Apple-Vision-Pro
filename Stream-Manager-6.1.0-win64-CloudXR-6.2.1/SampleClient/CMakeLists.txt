cmake_minimum_required(VERSION 3.14)
project(SampleNvStreamManagerClient)

# Set C++ standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Include the directory containing the header file
include_directories(${CMAKE_CURRENT_SOURCE_DIR})

# Define the executable
add_executable(SampleNvStreamManagerClient 
    SampleNvStreamManagerClient.cpp
)

# Set target properties
set_target_properties(SampleNvStreamManagerClient PROPERTIES
  CXX_STANDARD 17
  CXX_STANDARD_REQUIRED ON)

# Copy the DLL to the output directory after build
add_custom_command(TARGET SampleNvStreamManagerClient POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "${CMAKE_CURRENT_SOURCE_DIR}/NvStreamManagerClient.dll"
        "$<TARGET_FILE_DIR:SampleNvStreamManagerClient>/NvStreamManagerClient.dll"
    COMMENT "Copying NvStreamManagerClient.dll to output directory")

