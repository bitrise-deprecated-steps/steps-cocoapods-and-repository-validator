#!/bin/bash

formatted_output_file_path="$BITRISE_STEP_FORMATTED_OUTPUT_FILE_PATH"

function echo_string_to_formatted_output {
  echo "$1" >> $formatted_output_file_path
}

function write_section_to_formatted_output {
  echo '' >> $formatted_output_file_path
  echo "$1" >> $formatted_output_file_path
  echo '' >> $formatted_output_file_path
}

podcount=0
IFS=$'\n'
for podfile in $(find . -type f -name 'Podfile')
do
  podcount=$[podcount + 1]
  echo " (i) Podfile found at: $podfile"
  echo " (i) Podfile directory: $(dirname "$podfile")"
  echo "$ (cd $(dirname "$podfile") && pod install)"
  (cd $(dirname "$podfile") && pod install)
  if [ $? -ne 0 ]; then
    echo " [!] Could not pod install: ${podfile}"
    write_section_to_formatted_output "Could not install podfile: ${podfile}"
    exit 1
  fi
  write_section_to_formatted_output "Installed podfile: ${podfile}"
done
unset IFS
echo " (i) Found Podfile count: $podcount"
write_section_to_formatted_output "**${podcount} podfiles installed**"
write_section_to_formatted_output "# Podfiles installed successful"