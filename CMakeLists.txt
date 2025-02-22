cmake_minimum_required(VERSION 3.10)

project(pird)

# Build deb and rpm packages.
set(CPACK_GENERATOR DEB;RPM)

set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "a simple cd ripper written in D")
set(CPACK_PACKAGE_DESCRIPTION ${CPACK_PACKAGE_DESCRIPTION_SUMMARY})
set(CPACK_PACKAGE_VERSION_MAJOR 0)
set(CPACK_PACKAGE_VERSION_MINOR 11)
set(CPACK_PACKAGE_VERSION_PATCH 1)
set(CPACK_PACKAGE_REVISION 1)

set(CPACK_DEBIAN_PACKAGE_DEPENDS "libcdio-dev (>= 0.81-4), libcdio-cdda-dev (>= 0.81-4), libcdio-paranoia-dev (>= 0.81-4)" )
set(CPACK_DEBIAN_PACKAGE_MAINTAINER "Karsten Heinze <karsten@sidenotes.de>")

set(CPACK_RPM_PACKAGE_REQUIRES "libcdio-dev >= 0.81-4, libcdio-cdda-dev >= 0.81-4, libcdio-paranoia-dev >= 0.81-4" )
set(CPACK_RPM_PACKAGE_VENDOR "Karsten Heinze <karsten@sidenotes.de>" )
set(CPACK_RPM_PACKAGE_LICENSE "GPLv3")

# Set package name.
find_program(DPKG_PROGRAM dpkg DOC "dpkg program of Debian-based systems") 
if(DPKG_PROGRAM) 
  execute_process( 
    COMMAND ${DPKG_PROGRAM} --print-architecture 
      OUTPUT_VARIABLE CPACK_PACKAGE_ARCHITECTURE 
      OUTPUT_STRIP_TRAILING_WHITESPACE 
    ) 
else()
  set(CPACK_PACKAGE_ARCHITECTURE "arch")
endif() 

# Base name of package.
set(CPACK_PACKAGE_FILE_NAME "pird")
# Name of the deb package.
set(CPACK_PACKAGE_FILE_NAME_DEB "pird_${CPACK_PACKAGE_VERSION_MAJOR}.${CPACK_PACKAGE_VERSION_MINOR}.${CPACK_PACKAGE_VERSION_PATCH}-${CPACK_PACKAGE_REVISION}_${CPACK_PACKAGE_ARCHITECTURE}")
# Name of the rpm package.
set(CPACK_PACKAGE_FILE_NAME_RPM "pird-${CPACK_PACKAGE_VERSION_MAJOR}.${CPACK_PACKAGE_VERSION_MINOR}.${CPACK_PACKAGE_VERSION_PATCH}-${CPACK_PACKAGE_REVISION}.${CPACK_PACKAGE_ARCHITECTURE}")

set (CPACK_OUTPUT_CONFIG_FILE "${CMAKE_BINARY_DIR}/CPackConfigPird.cmake")
include(CPack)

# Use custom command to build packages:
# http://http://stackoverflow.com/questions/12302836/renaming-cpack-automatic-target
add_custom_target(packages COMMAND "${CMAKE_CPACK_COMMAND}" 
   "-C" "$<CONFIGURATION>" "--config" "${CMAKE_BINARY_DIR}/CPackConfigPird.cmake")
add_custom_command(
  TARGET packages
  POST_BUILD
  COMMAND mv pird.deb ${CPACK_PACKAGE_FILE_NAME_DEB}.deb
  COMMAND mv pird.rpm ${CPACK_PACKAGE_FILE_NAME_RPM}.rpm
  COMMENT "renaming packages"
)

# Find all source files *.d
set(SOURCES_DIR ${CMAKE_CURRENT_SOURCE_DIR}/src)
file(GLOB_RECURSE SOURCE_FILES ${SOURCES_DIR} *.d)
# Same again but relative to src directory.
file(GLOB_RECURSE SOURCE_FILES_RELATIVE RELATIVE ${SOURCES_DIR} *.d)
# Usage information (related to parsers) are in this directory.
set(USAGE_DIR "${SOURCES_DIR}/usages")
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
# Also install man page.
install(DIRECTORY "doc/man" DESTINATION share)

if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE "Release")
endif()

message("CMAKE_BUILD_TYPE is ${CMAKE_BUILD_TYPE}")

# Look for available compilers if not specified.
if(NOT CMAKE_D_COMPILER)
  find_program(DMD dmd DOC "dmd D2 compiler, see digitalmars.com")
  find_program(GDC gdc DOC "gcc D2 compiler, see gdcproject.org")
  find_program(LDC2 ldc2 DOC "ldc2 D2 compiler, see https://github.com/ldc-developers/ldc")
  find_program(LDMD2 ldmd2 DOC "ldmd2 D2 compiler, see https://github.com/ldc-developers/ldc")
  if(NOT DMD AND NOT GDC AND NOT LDC2 AND NOT LDMD2)
    message(FATAL_ERROR "no D2 compiler found")
  endif()

  # Setup compiler, prefere dmd over gdc.
  if(DMD)
    set(CMAKE_D_COMPILER ${DMD})
  elseif(GDC)
    set(CMAKE_D_COMPILER ${GDC})
  elseif(LDC2)
    set(CMAKE_D_COMPILER ${LDC2})
  elseif(LDMD2)
    set(CMAKE_D_COMPILER ${LDMD2})
  endif()
endif()
message("CMAKE_D_COMPILER is ${CMAKE_D_COMPILER}")

# Init build type dependent compile flags.
if(${CMAKE_BUILD_TYPE} STREQUAL "Release")
  set(DMD_COMPILE_FLAGS "-dw -w -wi -release")
  set(GDC_COMPILE_FLAGS "-Wall -Wdeprecated -frelease")
  set(LDC_COMPILE_FLAGS "")
elseif(${CMAKE_BUILD_TYPE} STREQUAL "Debug")
  set(DMD_COMPILE_FLAGS "-g -dw -w -wi -version=devel -unittest")
  set(GDC_COMPILE_FLAGS "-g -Wall -Wdeprecated -fversion=devel -funittest")
  set(LDC_COMPILE_FLAGS "")
endif()

# Tell cmake its a C project (no D support yet).
set_target_properties(pird PROPERTIES LINKER_LANGUAGE C)
set(CMAKE_C_SOURCE_FILE_EXTENSTIONS .d)
# Get rid of -rdynamic
set(CMAKE_SHARED_LIBRARY_LINK_C_FLAGS "")

string(REGEX MATCH "dmd" DMD_SELECTED ${CMAKE_D_COMPILER})
string(REGEX MATCH "gdc" GDC_SELECTED ${CMAKE_D_COMPILER})
string(REGEX MATCH "ldc" LDC_SELECTED ${CMAKE_D_COMPILER})

if(DMD_SELECTED)
  # Before linking, build object files.
  add_custom_command(
    TARGET pird PRE_LINK 
    COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/compile.sh
    ${CMAKE_D_COMPILER}
    ${SOURCES_DIR}
    ${OBJECTS_DIR}
    "-c "
    "-of"
    "${DMD_COMPILE_FLAGS} -J${USAGE_DIR} -I${SOURCES_DIR}"
    ${SOURCE_FILES} 
  )

  # How to compile (done by pre-link job).
  set(CMAKE_C_COMPILE_OBJECT "${CMAKE_D_COMPILER} <FLAGS> -of<OBJECT> -c <SOURCE>")
  # How to link.
  # NOTE: <OBJECTS> is empty, how to use?
  #set(CMAKE_C_LINK_EXECUTABLE "dmd <FLAGS> <CMAKE_C_LINK_FLAGS> <OBJECTS> -of<TARGET> <LINK_LIBRARIES>")
  set(CMAKE_C_LINK_EXECUTABLE "${CMAKE_D_COMPILER} ${OBJECT_FILES} -of<TARGET> <LINK_LIBRARIES>")
  # Linking is done using -L-l<library>
  set(CMAKE_LINK_LIBRARY_FLAG "-L-l")
elseif(GDC_SELECTED)
  # Before linking, build object files.
  add_custom_command(
    TARGET pird PRE_LINK 
    COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/compile.sh
    ${CMAKE_D_COMPILER}
    ${SOURCES_DIR}
    ${OBJECTS_DIR}
    "-c "
    "-o "
    "${GDC_COMPILE_FLAGS} -J${USAGE_DIR} -I${SOURCES_DIR}"
    ${SOURCE_FILES} 
  )

  # How to compile (done by pre-link job).
  set(CMAKE_C_COMPILE_OBJECT "${CMAKE_D_COMPILER} <FLAGS> -o<OBJECT> -c <SOURCE>")
  # How to link.
  # NOTE: <OBJECTS> is empty, how to use?
  #set(CMAKE_C_LINK_EXECUTABLE "gdc <FLAGS> <CMAKE_C_LINK_FLAGS> <OBJECTS> -of<TARGET> <LINK_LIBRARIES>")
  set(CMAKE_C_LINK_EXECUTABLE "${CMAKE_D_COMPILER} ${OBJECT_FILES} -o<TARGET> <LINK_LIBRARIES>")
  # Linking is done using -l<library>
  set(CMAKE_LINK_LIBRARY_FLAG "-l")
else()
  message(FATAL_ERROR "type of D2 compiler couldn't be determined")
endif()

# Strip binary in release mode if possible.
if(${CMAKE_BUILD_TYPE} STREQUAL "Release")
  find_program(STRIP strip DOC "strip removes debug symbols from binary")
  if(STRIP)
    add_custom_command(
      TARGET pird POST_BUILD
      COMMAND ${STRIP} pird
    )
  else()
    message(WARNING "strip not found")
  endif()
endif()

# Link pird against this libraries.
find_library(LIBCDIO cdio)
find_library(LIBCDIO_CDDA cdio_cdda)
find_library(LIBCDIO_PARANOIA cdio_paranoia)
target_link_libraries(pird ${LIBCDIO} ${LIBCDIO_CDDA} ${LIBCDIO_PARANOIA})

# Remove object files and packages on make clean.
set_directory_properties(PROPERTIES ADDITIONAL_MAKE_CLEAN_FILES
    "${OBJECTS_DIR};${CPACK_PACKAGE_FILE_NAME_DEB}.deb;${CPACK_PACKAGE_FILE_NAME_RPM}.rpm")
