#!/bin/sh

set +x

COMPILER=$1
SRC_PATH=$2
OBJ_PATH=$3
C_OPTION=$4
O_OPTION=$5
OTHER_OPTIONS=$6
shift 6

# @param $SRC_FILE
# @param $SRC_PATH
# @param $OBJ_PATH
# @return $OBJ_FILE
gen_path_to_obj_file()
{
  local SRC_FILE_REL
  SRC_FILE_REL=${1#$2} 
  SRC_FILE_REL=${SRC_FILE_REL#/}

  echo "$OBJ_PATH/${SRC_FILE_REL%.d}.o"

  return 0
}

for SRC_FILE in $@; do
  OBJ_FILE=$(gen_path_to_obj_file "$SRC_FILE" "$SRC_PATH" "$OBJ_PATH")

  echo mkdir -p $(dirname "$OBJ_FILE")
  mkdir -p $(dirname "$OBJ_FILE")
  echo "$COMPILER" $OTHER_OPTIONS $O_OPTION"$OBJ_FILE" $C_OPTION"$SRC_FILE" 
  "$COMPILER" $OTHER_OPTIONS $O_OPTION"$OBJ_FILE" $C_OPTION"$SRC_FILE" 
done
