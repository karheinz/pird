cmake_minimum_required(VERSION 2.8)

project(pird)

# Build deb and rpm packages.
set(CPACK_GENERATOR DEB;RPM)

set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "a simple cd ripper written in D")
set(CPACK_PACKAGE_DESCRIPTION ${CPACK_PACKAGE_DESCRIPTION_SUMMARY})
set(CPACK_PACKAGE_VERSION_MAJOR 0)
set(CPACK_PACKAGE_VERSION_MINOR 8)
set(CPACK_PACKAGE_VERSION_PATCH 0)
set(CPACK_PACKAGE_REVISION 1)

set(CPACK_DEBIAN_PACKAGE_DEPENDS "libcdio-dev (>= 0.81-4), libcdio-cdda-dev (>= 0.81-4), libcdio-paranoia-dev (>= 0.81-4)" )
set(CPACK_DEBIAN_PACKAGE_MAINTAINER "Karsten Heinze <karsten@sidenotes.de>")

set(CPACK_RPM_PACKAGE_REQUIRES "libcdio-dev >= 0.81-4, libcdio-cdda-dev >= 0.81-4, libcdio-paranoia-dev >= 0.81-4" )
set(CPACK_RPM_PACKAGE_VENDOR "Karsten Heinze <karsten@sidenotes.de>" )
set(CPACK_RPM_PACKAGE_LICENSE "GPLv3")

# Set package name.
if(ARCH)
  set(CPACK_PACKAGE_ARCHITECTURE ${ARCH})
else()
  find_program(DPKG_PROGRAM dpkg DOC "dpkg program of Debian-based systems") 
  if(DPKG_PROGRAM) 
    execute_process( 
      COMMAND ${DPKG_PROGRAM} --print-architecture 
        OUTPUT_VARIABLE CPACK_PACKAGE_ARCHITECTURE 
        OUTPUT_STRIP_TRAILING_WHITESPACE 
      ) 
    set(ARCH ${CPACK_PACKAGE_ARCHITECTURE})
  else(DPKG_PROGRAM)
    set(CPACK_PACKAGE_ARCHITECTURE "arch")
    set(ARCH "arch")
  endif(DPKG_PROGRAM) 
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

# Link pird against this libraries.
SET(CMAKE_FIND_LIBRARY_SUFFIXES ".so")
find_library(LIBCDIO cdio)
find_library(LIBCDIO_CDDA cdio_cdda)
find_library(LIBCDIO_PARANOIA cdio_paranoia)
SET(CMAKE_FIND_LIBRARY_SUFFIXES ".so")
find_library(LIBPHOBOS2 phobos2)
message(${LIBCDIO})
message(${LIBCDIO_CDDA})
message(${LIBCDIO_PARANOIA})
message(${LIBPHOBOS2})
execute_process(COMMAND dirname ${LIBCDIO}
  OUTPUT_VARIABLE LIBRARY_PATH_LIBCDIO
  OUTPUT_STRIP_TRAILING_WHITESPACE 
)
execute_process(COMMAND dirname ${LIBCDIO_CDDA}
  OUTPUT_VARIABLE LIBRARY_PATH_LIBCDIO_CDDA
  OUTPUT_STRIP_TRAILING_WHITESPACE 
)
execute_process(COMMAND dirname ${LIBCDIO_PARANOIA}
  OUTPUT_VARIABLE LIBRARY_PATH_LIBCDIO_PARANOIA
  OUTPUT_STRIP_TRAILING_WHITESPACE 
)
execute_process(COMMAND dirname ${LIBPHOBOS2}
  OUTPUT_VARIABLE LIBRARY_PATH_LIBPHOBOS2
  OUTPUT_STRIP_TRAILING_WHITESPACE 
)

if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE "Release")
endif()

message("CMAKE_BUILD_TYPE is ${CMAKE_BUILD_TYPE}")

# Look for available compilers.
find_program(DMD dmd DOC "dmd D2 compiler, see digitalmars.com")
find_program(GDC gdc DOC "gcc D2 compiler, see gdcproject.org")
if(NOT DMD AND NOT GDC)
  message(FATAL_ERROR "no D2 compiler found")
endif()

# Init build type dependent compile flags.
if(${CMAKE_BUILD_TYPE} STREQUAL "Release")
  set(DMD_COMPILE_FLAGS -release)
  set(GDC_COMPILE_FLAGS -frelease)
elseif(${CMAKE_BUILD_TYPE} STREQUAL "Debug")
  set(DMD_COMPILE_FLAGS "-g -version=devel -unittest")
  set(GDC_COMPILE_FLAGS "-g -fversion=devel -funittest")
endif()

# Consider architecture!
string(REGEX MATCH "(([356ix]86)|(amd64))" ARCH_SUPPORTED ${ARCH})
if("${ARCH_SUPPORTED}" STREQUAL "")
  message(FATAL_ERROR "architecture ${ARCH} is not supported")
endif()
if(${ARCH} MATCHES "[356ix]86")
  set(DMD_COMPILE_FLAGS "${DMD_COMPILE_FLAGS} -m32")
  set(GDC_COMPILE_FLAGS "${GDC_COMPILE_FLAGS} -m32")
  set(DMD_LINK_FLAGS "-m32")
  set(GDC_LINK_FLAGS "-m32")
else()
  set(DMD_COMPILE_FLAGS "${DMD_COMPILE_FLAGS} -m64")
  set(GDC_COMPILE_FLAGS "${GDC_COMPILE_FLAGS} -m64")
  set(DMD_LINK_FLAGS "-m64")
  set(GDC_LINK_FLAGS "-m64")
endif()

# Tell cmake its a C project (no D support yet).
set_target_properties(pird PROPERTIES LINKER_LANGUAGE C)
set(CMAKE_C_SOURCE_FILE_EXTENSTIONS .d)
# Get rid of -rdynamic
set(CMAKE_SHARED_LIBRARY_LINK_C_FLAGS "")

# Setup compiler, prefere dmd over gdc.
if(NOT CMAKE_D_COMPILER)
  if(DMD)
    set(CMAKE_D_COMPILER ${DMD})
  elseif(GDC)
    set(CMAKE_D_COMPILER ${GDC})
  endif()
endif()
message("CMAKE_D_COMPILER is ${CMAKE_D_COMPILER}")

string(REGEX MATCH "dmd" DMD_SELECTED ${CMAKE_D_COMPILER})
string(REGEX MATCH "gdc" GDC_SELECTED ${CMAKE_D_COMPILER})

if(DMD_SELECTED)
  # Before linking, build object files.
  add_custom_command(
    TARGET pird PRE_LINK 
    COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/compile.sh
    ${DMD}
    ${SOURCES_DIR}
    ${OBJECTS_DIR}
    "-c "
    "-of"
    "${DMD_COMPILE_FLAGS} -wi -J${USAGE_DIR} -I${SOURCES_DIR}"
    ${SOURCE_FILES} 
  )

  # How to compile (done by pre-link job).
  set(CMAKE_C_COMPILE_OBJECT "${DMD} <FLAGS> -of<OBJECT> -c <SOURCE>")
  # How to link.
  # NOTE: <OBJECTS> is empty, how to use?
  #set(CMAKE_C_LINK_EXECUTABLE "dmd <FLAGS> <CMAKE_C_LINK_FLAGS> <OBJECTS> -of<TARGET> <LINK_LIBRARIES>")
  #set(CMAKE_LINK_LIBRARY_FLAG "-L-l")
  #set(CMAKE_LINK_LIBRARY_PATH_FLAG "-L-L")
  set(CMAKE_C_LINK_EXECUTABLE "dmd ${OBJECT_FILES} ${DMD_LINK_FLAGS} -of<TARGET> -L-Bdynamic -L-lcdio -L-lcdio_cdda -L-lcdio_paranoia -L-L${LIBRARY_PATH_LIBCDIO} -L-L${LIBRARY_PATH_LIBCDIO_CDDA} -L-L${LIBRARY_PATH_LIBCDIO_PARANOIA} -L-Bdynamic -L-L${LIBRARY_PATH_LIBPHOBOS2}")
elseif(GDC_SELECTED)
  # Before linking, build object files.
  add_custom_command(
    TARGET pird PRE_LINK 
    COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/compile.sh
    ${GDC}
    ${SOURCES_DIR}
    ${OBJECTS_DIR}
    "-c "
    "-o "
    "${GDC_COMPILE_FLAGS} -J${USAGE_DIR} -I${SOURCES_DIR}"
    ${SOURCE_FILES} 
  )

  # How to compile (done by pre-link job).
  set(CMAKE_C_COMPILE_OBJECT "${GDC} <FLAGS> -o<OBJECT> -c <SOURCE>")
  # How to link.
  set(CMAKE_C_LINK_EXECUTABLE "${GDC} ${OBJECT_FILES} ${GDC_LINK_FLAGS} -o<TARGET> -Wl,-Bdynamic -lcdio -lcdio_cdda -lcdio_paranoia -L${LIBRARY_PATH_LIBCDIO} -L${LIBRARY_PATH_LIBCDIO_CDDA} -L${LIBRARY_PATH_LIBCDIO_PARANOIA} -Wl,-Bdynamic -L${LIBRARY_PATH_LIBPHOBOS2}")
endif()

#target_link_libraries(pird ${LIBCDIO} ${LIBCDIO_CDDA} ${LIBCDIO_PARANOIA})
