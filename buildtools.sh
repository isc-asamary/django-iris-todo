#!/bin/bash

RED="\033[1;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
PURPLE="\033[1;35m"
CYAN="\033[1;36m"
WHITE="\033[1;37m"
RESET="\033[0m"

exit_if_error() {
	if [ $(($(echo "${PIPESTATUS[@]}" | tr -s ' ' +))) -ne 0 ]; then
		if [ ! -z "$1" ];
		then
			echo ""
			echo -e "${RED}ERROR: ${1}$RESET"
			echo ""
		fi
		exit 1
	fi
}

exit_with_error() {
	echo ""
	echo -e "${RED}ERROR: ${1}$RESET"
	echo ""
	exit 1
}

function msg {
	printf "\n${BLUE}$1${RESET}"
}

function option {
	printf "\n${WHITE}$1 - ${BLUE}$2${RESET}"
}

function trace {
	printf "\n\n${YELLOW}$1${RESET}\n"
}

function warn {
	printf "\n\n${YELLOW}$1${RESET}\n\n"
}

function danger {
	printf "\n\n${RED}$1${RESET}\n\n"
}

# $1 is the message to be displayed to the user.
function pause {
	printf "\n\n${WHITE}$1${RESET}\n\n"
	while [ true ] ; do
		read -t 3 -n 1
		if [ $? = 0 ] ; then
			break;
		else
			echo "waiting for the keypress"
		fi
	done
}


function danger_to_continue {
	clear
	printf "\n${WHITE}--------------------------------------------------------------------------------${RESET}"
	danger "$1"
	printf "${WHITE}--------------------------------------------------------------------------------${RESET}"
	warn "Do you want to continue?"

	PS3='Choice: '
	options=("Yes, I want to continue" "No! Get me out of here!")
	select opt in "${options[@]}"
	do
		case $opt in
			"Yes, I want to continue")
				break
				;;
			"No! Get me out of here!")
				msg "Aborting.\n"
				exit 0
				;;
			*) echo "Invalid choice: $REPLY. Please type '1' or '2'.";;
		esac
	done
}

function yes_or_no {
	clear
	printf "\n${WHITE}--------------------------------------------------------------------------------${RESET}"
	danger "$1"
	printf "${WHITE}--------------------------------------------------------------------------------${RESET}"
	warn "Yes or no?"

	PS3='Choice: '
	options=("Yes, go ahead." "Hell No!")
	select opt in "${options[@]}"
	do
		case $opt in
			"Yes, go ahead.")
				export YES_OR_NO="YES"
				break
				;;
			"Hell No!")
				export YES_OR_NO="NO"
				break
				;;
			*) echo "Invalid choice: $REPLY. Please type '1' or '2'.";;
		esac
	done
}

function normalize_path_for_platform
{
    if [ ! -z $(uname | grep MINGW64) ];
    then 
        # Need to fix it for K3D running on windows when using git-bash or cygwin
        FORWARD_SLASH='\/'
        BACK_SLASH='\\'

        if [[ $(echo $1 | head -c 2) == *"c"* ]]
        then
            BAD_C_COLON='\\c\\'
        else
            BAD_C_COLON='\\C\\'
        fi
        
        GOOD_C_COLON='C:\\'

        TMP=$(echo $1 | awk "{gsub(/$FORWARD_SLASH/,\"$BACK_SLASH\"); print}")
        export NORMALIZED_PATH=$(echo $TMP | awk "{gsub(/$BAD_C_COLON/,\"$GOOD_C_COLON\"); print}")
    else
        # On *NIX we don't change anything
        export NORMALIZED_PATH=$1
    fi
}