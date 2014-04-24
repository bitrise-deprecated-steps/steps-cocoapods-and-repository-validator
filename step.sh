#!/bin/bash

echo "$ cd $CONCRETE_SOURCE_DIR"
cd $CONCRETE_SOURCE_DIR

if [ -n "$GATHER_PROJECTS" ]; then
  git remote set-head origin -d

  for branch in $(git branch -r); 
  do
    echo "$ git checkout -B $branch"
    git checkout -B $branch
    # remove the prefix "origin/" from the branch name
    branch_without_remote=$(printf "%s" "$branch" | cut -c 8-)
    echo "Local branch: $branch_without_remote"
    
    $CONCRETE_STEP_DIR/run_pod_install.sh

    echo "$ $CONCRETE_STEP_DIR/find_schemes.sh"
    $CONCRETE_STEP_DIR/find_schemes.sh "$branch_without_remote"
  done
else
  $CONCRETE_STEP_DIR/run_pod_install.sh
fi
