cmake_minimum_required(VERSION 2.8)

project(pird)

# Build deb and rpm packages.
set(CPACK_GENERATOR DEB;RPM)

set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "a simple cd ripper written in D")
set(CPACK_PACKAGE_DESCRIPTION ${CPACK_PACKAGE_DESCRIPTION_SUMMARY})
set(CPACK_PACKAGE_VERSION_MAJOR 0)
set(CPACK_PACKAGE_VERSION_MINOR 2)
set(CPACK_PACKAGE_VERSION_PATCH 4)

set(CPACK_DEBIAN_PACKAGE_DEPENDS "libcdio-dev (>= 0.81-4), libcdio-cdda-dev (>= 0.81-4), libcdio-paranoia-dev (>= 0.81-4)" )
set(CPACK_DEBIAN_PACKAGE_MAINTAINER "Karsten Heinze <karsten@sidenotes.de>")

set(CPACK_RPM_PACKAGE_REQUIRES "libcdio-dev >= 0.81-4, libcdio-cdda-dev >= 0.81-4, libcdio-paranoia-dev >= 0.81-4" )
set(CPACK_RPM_PACKAGE_VENDOR "Karsten Heinze <karsten@sidenotes.de>" )
set(CPACK_RPM_PACKAGE_LICENSE "GPLv3")

include(CPack)

# Find all source files *.d
file(GLOB_RECURSE SOURCE_FILES ${CMAKE_CURRENT_SOURCE_DIR}/src *.d)
# Same again but relative to src directory.
file(GLOB_RECURSE SOURCE_FILES_RELATIVE RELATIVE ${CMAKE_CURRENT_SOURCE_DIR}/src *.d)
# Usage information (related to parsers) are in this directory.
set(USAGE_DIR_RELATIVE "usages")
# Object files are stored here.
set(OBJECTS_DIR ${CMAKE_CURRENT_BINARY_DIR}/objects)

# Build string containing object files.
foreach(SOURCE_FILE ${SOURCE_FILES_RELATIVE})
  get_filename_component(FILE_BASENAME ${SOURCE_FILE} NAME_WE)
  get_filename_component(FILE_PATH ${SOURCE_FILE} PATH)
  set(OBJECT_FILE "${OBJECTS_DIR}/${FILE_PATH}/${FILE_BASENAME}.o")
  string(REPLACE "//" "/" OBJECT_FILE ${OBJECT_FILE})
  set(OBJECT_FILES "${OBJECT_FILES} ${OBJECT_FILE}")
endforeach()

# We want to build pird.
add_executable(pird ${SOURCE_FILES})
install(TARGETS pird DESTINATION bin)

if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE "Release")
endif()

message("CMAKE_BUILD_TYPE is ${CMAKE_BUILD_TYPE}")
set(DMD_COMPILE_FLAGS -w -c)
if(${CMAKE_BUILD_TYPE} STREQUAL "Release")
  set(DMD_COMPILE_FLAGS ${DMD_COMPILE_FLAGS} -release)
elseif(${CMAKE_BUILD_TYPE} STREQUAL "Debug")
  set(DMD_COMPILE_FLAGS ${DMD_COMPILE_FLAGS} -g -version=devel -unittest)
endif()

# Before linking, build object files.
add_custom_command(
  TARGET pird PRE_LINK 
  COMMAND cd ${CMAKE_CURRENT_SOURCE_DIR}/src &&
  dmd ${SOURCE_FILES_RELATIVE} -J${USAGE_DIR_RELATIVE}
  -od${CMAKE_CURRENT_BINARY_DIR}/objects -op
  ${DMD_COMPILE_FLAGS}
)

# Tell cmake its a C project (no D support yet).
set_target_properties(pird PROPERTIES LINKER_LANGUAGE C)
set(CMAKE_C_SOURCE_FILE_EXTENSTIONS .d)
# Get rid of -rdynamic
set(CMAKE_SHARED_LIBRARY_LINK_C_FLAGS "")
# How to compile.
set(CMAKE_C_COMPILE_OBJECT "dmd <FLAGS> -of<OBJECT> -c <SOURCE>")
# How to link.
# NOTE: <OBJECTS> is empty, how to use?
#set(CMAKE_C_LINK_EXECUTABLE "dmd <FLAGS> <CMAKE_C_LINK_FLAGS> <OBJECTS> -of<TARGET> <LINK_LIBRARIES>")
set(CMAKE_C_LINK_EXECUTABLE "dmd ${OBJECT_FILES} -of<TARGET> <LINK_LIBRARIES>")
# Linking is down using -L-l<library>
set(CMAKE_LINK_LIBRARY_FLAG "-L-l")

# Link pird against this libraries.
find_library(LIBCDIO cdio)
find_library(LIBCDIO_CDDA cdio_cdda)
find_library(LIBCDIO_PARANOIA cdio_paranoia)
target_link_libraries(pird ${LIBCDIO} ${LIBCDIO_CDDA} ${LIBCDIO_PARANOIA})
