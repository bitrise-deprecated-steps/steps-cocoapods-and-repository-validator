#!/bin/bash

podcount=0
IFS=$'\n'
for podfile in $(find . -type f -name 'Podfile')
do
  podcount=$[podcount + 1]
  echo " (i) Podfile found at: $podfile"
  echo " (i) Podfile directory: $(dirname \"$podfile\")"
  echo "$ (cd $(dirname \"$podfile\") && pod install)"
  (cd $(dirname "$podfile") && pod install)
done
unset IFS
echo " (i) Found Podfile count: $podcount"
