#!/bin/bash

### ****************************************************

GITHUB_ACCOUNT_NAME=$1
CHART_REPOSITORY_FOLDER=$2


### ****************************************************
# Excerpt from buildtools.sh

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

### ****************************************************

CHART_NAME=${PWD##*/}
CHART_REPOSITORY_URL=$GITHUB_ACCOUNT_NAME.github.io
GIT_REPOSITORY=https://github.com/$GITHUB_ACCOUNT_NAME/$CHART_REPOSITORY_FOLDER

echo "Publishing chart $CHART_NAME to $GIT_REPOSITORY\n"

if [ ! -d ../$CHART_REPOSITORY_FOLDER ];
then
    exit_with_error "You don't have the git repository $CHART_REPOSITORY_FOLDER in the right place. Make sure you have clonned $GIT_REPOSITORY as a sibling to this folder before you proceed."
fi

#
# Fixing the icon reference
#
ICON_FILE_NAME=$(ls ./helm/icon.*)
ICON_FILE_NAME=${ICON_FILE_NAME##*/}
sed -E -i '' "s;icon: .*;icon: https://$CHART_REPOSITORY_URL/$CHART_REPOSITORY_FOLDER/$CHART_NAME/$ICON_FILE_NAME;g" ./helm/Chart.yaml

#
# Publishing
#

cd ../$CHART_REPOSITORY_FOLDER
git pull
exit_if_error "Could not pull changes from $GIT_REPOSITORY on your folder $CHART_REPOSITORY_FOLDER. Do you have pending changes there?"

cd ../$CHART_NAME

rm -rf ../$CHART_REPOSITORY_FOLDER/$CHART_NAME
cp -R ./helm ../$CHART_REPOSITORY_FOLDER/$CHART_NAME

cd ../$CHART_REPOSITORY_FOLDER

helm package ./$CHART_NAME
exit_if_error "Packaging of helm chart $CHART_NAME failed."

helm repo index . --url https://$CHART_REPOSITORY_URL/$CHART_REPOSITORY_FOLDER
exit_if_error "Failed to index helm chart $CHART_NAME on your folder $CHART_REPOSITORY_FOLDER."

git add .
exit_if_error "Could not add changes to the staging area of your folder $CHART_REPOSITORY_FOLDER."

git commit -m "Publishing new version of chart $CHART_NAME."
exit_if_error "Could not commit changes."

git push
exit_if_error "Could not push changes."

cd ../$CHART_NAME

git checkout ./helm/Chart.yaml
