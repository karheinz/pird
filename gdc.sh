#!/usr/bin/env bash

GDC=$1
OPTIONS=$2
shift 2

for FILE in $@; do
  DIRNAME=$(dirname ${FILE/src/build/objects})
  BASENAME=$(basename ${FILE/src/build/objects})

  mkdir -p "$DIRNAME"
  echo $GDC -c $FILE $OPTIONS -o "${DIRNAME}/${BASENAME%.d}.o"
  $GDC -c $FILE $OPTIONS -o "${DIRNAME}/${BASENAME%.d}.o"
done
