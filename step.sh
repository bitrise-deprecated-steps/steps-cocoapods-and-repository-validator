#!/bin/bash

echo "$ cd $CONCRETE_SOURCE_DIR"
cd $CONCRETE_SOURCE_DIR

if [ -n "GATHER_PROJECTS" ]; then
  git remote set-head origin -d

  for branch in $(git branch -r); 
  do
    echo "$ git checkout -B $branch"
    git checkout -B $branch
    
    $CONCRETE_STEP_DIR/run_pod_install.sh

    echo "$ $CONCRETE_STEP_DIR/find_schemes.sh"
    $CONCRETE_STEP_DIR/find_schemes.sh
  done
else
  $CONCRETE_STEP_DIR/run_pod_install.sh
fi
