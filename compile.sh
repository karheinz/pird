#!/bin/sh
#
#  Copyright (C) 2013 Karsten Heinze <karsten@sidenotes.de>
#
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program. If not, see <http://www.gnu.org/licenses/>.
#

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
  echo "$SRC_FILE"

  OBJ_FILE=$(gen_path_to_obj_file "$SRC_FILE" "$SRC_PATH" "$OBJ_PATH")

  mkdir -p $(dirname "$OBJ_FILE")

  # Go on if object file is new than src file.
  if [ -f "$OBJ_FILE" -a "$OBJ_FILE" -nt "${SRC_FILE}" ]; then
    continue
  fi

  "$COMPILER" $OTHER_OPTIONS $O_OPTION"$OBJ_FILE" $C_OPTION"$SRC_FILE" 
  if [ $? != 0 ]; then
    exit 1
  fi
done
