#!/bin/bash

if [ -f "Podfile" ]; then
  echo "$ pod install"
  pod install
fi