#!/usr/bin/env bash

DMD=$1
OPTIONS=$2
shift 2

for FILE in $@; do
  DIRNAME=$(dirname ${FILE/src/build/objects})
  BASENAME=$(basename ${FILE/src/build/objects})

  mkdir -p "$DIRNAME"
  echo $DMD -c $FILE $OPTIONS -of"${DIRNAME}/${BASENAME%.d}.o"
  $DMD -c $FILE $OPTIONS -of"${DIRNAME}/${BASENAME%.d}.o"
done
