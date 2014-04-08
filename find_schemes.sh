#!/bin/bash

# find project or workspace directories
projects=()
for path in $(find . -type d -name '*.xcodeproj' -or -name '*.xcworkspace')
do

  already_stored=false
  for project in $projects
  do
    if [[ $path == $project* ]]; then
      already_stored=true
    fi
  done

  if ! $already_stored; then
    projects+=($path)
  fi
done

# Get the project schemes
for project in "${projects[@]}"
do
  xcodebuild_output=()
  schemes=()
  parse_schemes=false

  IFS=$'\n'
  if [[ $project == *".xcodeproj" ]]; then
    xcodebuild_output=($(xcodebuild -list -project $project))
  else
    xcodebuild_output=($(xcodebuild -list -workspace $project))
  fi
  unset IFS

  for line in "${xcodebuild_output[@]}"
  do
    if $parse_schemes; then
      schemes+=($line)
    fi

    if [[ $line == *"Schemes:"* ]]; then
      parse_schemes=true
    fi
  done

  if [[ ${#schemes[@]} == 0 ]]; then
    echo "$project - ignoring; no schemes found."
  else
    IFS=" "
    scheme_list="${schemes[*]}"
    unset IFS

    echo "$project ($scheme_list)"
  fi
done