#!/bin/bash

echo "$ cd $CONCRETE_RELATIVE_GIT_DIRECTORY"
cd $CONCRETE_RELATIVE_GIT_DIRECTORY

if [ -n "GATHER_PROJECTS" ]; then
  git remote set-head origin -d

  for branch in $(git branch -r); 
  do
    echo "$ git checkout -B $branch"
    git checkout -B $branch
    
    $CONCRETE_ROOT/run_pod_install.sh

    echo "$ $CONCRETE_ROOT/find_schemes.sh"
    $CONCRETE_ROOT/find_schemes.sh
  done
else
  $CONCRETE_ROOT/run_pod_install.sh
fi
