cmake_minimum_required(VERSION 2.8)

project(pird)

file(GLOB_RECURSE SOURCE_FILES ${CMAKE_CURRENT_SOURCE_DIR}/src *.d)
file(GLOB_RECURSE SOURCE_FILES_RELATIVE RELATIVE ${CMAKE_CURRENT_SOURCE_DIR}/src *.d)
set(USAGE_DIR_RELATIVE "usages")
set(OBJECTS_DIR ${CMAKE_CURRENT_BINARY_DIR}/objects)

foreach(SOURCE_FILE ${SOURCE_FILES_RELATIVE})
  get_filename_component(FILE_BASENAME ${SOURCE_FILE} NAME_WE)
  get_filename_component(FILE_PATH ${SOURCE_FILE} PATH)
  set(OBJECT_FILES ${OBJECT_FILES} "${OBJECTS_DIR}/${FILE_PATH}/${FILE_BASENAME}.o")
endforeach()

message("Sources ${SOURCE_FILES_RELATIVE}")
message("Objects ${OBJECT_FILES}")

add_executable(pird ${SOURCE_FILES})
add_custom_command(
  TARGET pird PRE_LINK 
  COMMAND cd ${CMAKE_CURRENT_SOURCE_DIR}/src &&
  dmd ${SOURCE_FILES_RELATIVE} -J${USAGE_DIR_RELATIVE}
  -od${CMAKE_CURRENT_BINARY_DIR}/objects -op
  -w -c
)
set_target_properties(pird PROPERTIES LINKER_LANGUAGE C)
#set_target_properties(pird PROPERTIES LINK_DEPENDS ${OBJECT_FILES})
set(CMAKE_C_LINK_EXECUTABLE dmd)
find_library(LIBCDIO cdio)
find_library(LIBCDIO_CDDA cdio_cdda)
find_library(LIBCDIO_PARANOIA cdio_paranoia)
target_link_libraries(pird ${LIBCDIO} ${LIBCDIO_CDDA} ${LIBCDIO_PARANOIA})
