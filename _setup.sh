#!/bin/bash

command_exists () {
	command -v "$1" >/dev/null 2>&1 ;
}

function SetupGatherProjectsDependencies {
	set -e

	STARTTIME=$(date +%s)

	if command_exists gtimeout ; then
		echo " (i) gtimeout already installed - OK"
	else
		# gtimeout is part of coreutils
		echo " (i) gtimeout not yet installed, installing..."
		brew install coreutils
		echo " (i) install done - OK"
	fi

	ENDTIME=$(date +%s)
	echo " (i) Setup took $(($ENDTIME - $STARTTIME)) seconds to complete"
}
