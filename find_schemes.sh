#!/bin/bash

# find project or workspace directories
branch=$1
projects=()

IFS=$'\n'
for path in $(find . -type d -name '*.xcodeproj' -or -name '*.xcworkspace')
do

  already_stored=false
  for project in $projects
  do
    if [[ "$path" == "$project*" ]]; then
      already_stored=true
    fi
  done

  if ! $already_stored; then
    projects+=("$path")
  fi
done
unset IFS

# Get the project schemes
projects_encoded=()
for project in "${projects[@]}"
do
  xcodebuild_output=()
  schemes=()
  schemes_encoded=()
  parse_schemes=false

  IFS=$'\n'
  if [[ "$project" == *".xcodeproj" ]]; then
    xcodebuild_output=($(xcodebuild -list -project "$project"))
  else
    xcodebuild_output=($(xcodebuild -list -workspace "$project"))
  fi
  unset IFS

  for line in "${xcodebuild_output[@]}"
  do
    # trimming
    #  source: http://stackoverflow.com/a/3232433/974381
    trimmed_line=$([[ "$line" =~ [[:space:]]*([^[:space:]]|[^[:space:]].*[^[:space:]])[[:space:]]* ]]; echo -n "${BASH_REMATCH[1]}")
    if $parse_schemes; then
      schemes+=($trimmed_line)
      schemes_encoded+=($(printf "%s" "$trimmed_line" | base64))
    fi

    if [[ $trimmed_line == *"Schemes:"* ]]; then
      parse_schemes=true
    fi
  done

  if [[ ${#schemes[@]} == 0 ]]; then
    echo "$project - ignoring; no schemes found."
  else
    IFS=" "
    scheme_list="${schemes[*]}"
    unset IFS
    echo "Found $project ($scheme_list)"

    IFS=","
    encoded_scheme_list="${schemes_encoded[*]}"
    unset IFS
    echo "$(printf "%s" "$branch" | base64),$(printf "%s" "$project" | base64),$encoded_scheme_list" >> ~/.schemes
    #echo " [i] Final schemes info:"
    #cat ~/.schemes
    #echo " ---"
  fi
done

