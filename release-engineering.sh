#!/bin/bash
source ./buildtools.sh

NOW="$(date +'%B %d, %Y')"

QUESTION_FLAG="${GREEN}?"
WARNING_FLAG="${YELLOW}!"
NOTICE_FLAG="${CYAN}❯"

ADJUSTMENTS_MSG="${QUESTION_FLAG} ${CYAN}Now you can make adjustments to ${WHITE}CHANGELOG.md${CYAN}. Then press enter to continue."
PUSHING_MSG="${NOTICE_FLAG} Pushing new version to the ${WHITE}origin${CYAN}..."
BUILDING_MSG="${NOTICE_FLAG} We are building the software so that files such as package.json will have the new version in it and, when built, will cause package-lock.json to be also generated with the new version."


function handle_change_log() {
    echo "## ${2} ($NOW)" > tmpfile
    git log --pretty=format:"  - %s" "${1}"...HEAD >> tmpfile
    echo "" >> tmpfile
    echo "" >> tmpfile
    cat CHANGELOG.md >> tmpfile
    mv tmpfile CHANGELOG.md
    echo -e "$ADJUSTMENTS_MSG"
    read
}

function create_new_release() {
    local RELEASE_VERSION_NUMBER="${1}.1"
    local RELEASE_BRANCH="release-${1}"
    local RELEASE_TAG="release-${RELEASE_VERSION_NUMBER}"
    echo "Creating a new release: ${RELEASE_BRANCH}"
    # fetch the potential branch from remote in case it is not local
    msg "Fetching this branch name from remote. This may fail and that is ok. \n"
    git fetch origin $RELEASE_BRANCH
    # fetch the potential tag from remote in case it is not local
    msg "Fetching this tag name from remote. This may fail and that is ok. \n"
    git fetch origin refs/tags/$RELEASE_TAG

    # Cutting a new branch for the release. This can fail if the branch already exists.
    git checkout -b $RELEASE_BRANCH
    exit_if_error "Could not create branch for release"

    echo $RELEASE_VERSION_NUMBER > VERSION

    if [[ $OSTYPE =~ [darwin*] ]]; then
    #     # Updating Angular application version
    #     sed -E -i '' "s;([ ]*\"version\": *)\"[0-9][0-9.]*\";\1\"$1\";g" ./frontend/image/app/package.json
        sed -E -i '' "s;(version: [0-9.]+);version: $INPUT_STRING;" ./helm/Chart.yaml
        sed -E -i '' "s;(appVersion: *)\"?[0-9][0-9.]*\"?;\1\"$INPUT_STRING\";g" ./helm/Chart.yaml
    else
    #     # Updating Angular application version
    #     sed -E -i "s;([ ]*\"version\": *)\"[0-9][0-9.]*\";\1\"$1\";g" ./frontend/image/app/package.json
        sed -E -i "s;(version: [0-9.]+);version: $INPUT_STRING;" ./helm/Chart.yaml
        sed -E -i "s;(appVersion: *)\"?[0-9][0-9.]*\"?;\1\"$INPUT_STRING\";g" ./helm/Chart.yaml
    fi

    handle_change_log $RELEASE_TAG $RELEASE_TAG

    #
    # Add files that were changed by the release process:
    #
    # frontend/image/app/package.json frontend/image/app/package-lock.json SDS/helm/Chart.yaml
    git add CHANGELOG.md VERSION 

    echo -e "$PUSHING_MSG"


    git commit -m "Creating inital commit for release version ${RELEASE_BRANCH}."
    # This can fail if the tag already exists.
    git tag -a -m "Tag release version ${RELEASE_BRANCH}." "$RELEASE_TAG"
    exit_if_error "Could not create tag for release"

    git push origin refs/tags/$RELEASE_TAG

    git push -u origin $RELEASE_BRANCH
}

function bump_release_build_version() {

    local RELEASE_VERSION="release-${1}"

    get_most_recent_tag_for_branch $RELEASE_VERSION
    # If there is no most recent tag then tell the user that they probaly want to cut a new release
    if [ -z "$MOST_RECENT_TAG" ]; then
        exit_with_error "There are no existing tags for the current release version ${RELEASE_VERSION}. Please Rerun this script and create a new release."
    fi
    
    BASE_LIST=(`echo $MOST_RECENT_TAG | tr '.' ' '`)
    V_BUILD=${BASE_LIST[3]}
    V_NEXT_BUILD=$((V_BUILD + 1))
    CURRENT_RELEASE_BUILD_TAG="${RELEASE_VERSION}.${V_BUILD}"
    NEW_RELEASE_BUILD_TAG="${RELEASE_VERSION}.${V_NEXT_BUILD}"
    NEW_RELEASE_VERSION_NUMBER="${1}.${V_NEXT_BUILD}"

    echo $NEW_RELEASE_VERSION_NUMBER > VERSION

    handle_change_log $CURRENT_RELEASE_BUILD_TAG $NEW_RELEASE_BUILD_TAG
    #
    # Add files that were changed by the bumpversion.sh:
    #
    git add CHANGELOG.md VERSION

    echo -e "$PUSHING_MSG"

    git commit -m "Bumping Release Build to ${NEW_RELEASE_BUILD_TAG}."

    git push origin $RELEASE_VERSION

    # This can fail if the tag already exists.
    git tag -a -m "Tag release version ${NEW_RELEASE_BUILD_TAG}." "$NEW_RELEASE_BUILD_TAG"
    exit_if_error "Could not create tag for release"

    git push origin refs/tags/$NEW_RELEASE_BUILD_TAG
}

function get_most_recent_tag_for_branch() {
    MOST_RECENT_TAG=$(git ls-remote --tags --sort="-v:refname" --refs origin -l "$1.*" | cut -f 3 -d '/' | head -1)
}

function get_current_git_branch() {
    CURRENT_GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
}

function get_release_version(){
    if [ -f VERSION ]; then
        RELEASE_BUILD_VERSION_NUMBER=`cat VERSION`
        BASE_LIST=(`echo $RELEASE_BUILD_VERSION_NUMBER | tr '.' ' '`)
        V_MAJOR=${BASE_LIST[0]}
        V_MINOR=${BASE_LIST[1]}
        V_PATCH=${BASE_LIST[2]}
        RELEASE_VERSION_NUMBER="$V_MAJOR.$V_MINOR.$V_PATCH"
    else
        exit_with_error "No Version File Detected!"
    fi
}

function choose_new_version(){
    if [ -f VERSION ]; then
        BASE_STRING=`cat VERSION`
        BASE_LIST=(`echo $BASE_STRING | tr '.' ' '`)
        V_MAJOR=${BASE_LIST[0]}
        V_MINOR=${BASE_LIST[1]}
        V_PATCH=${BASE_LIST[2]}
        echo -e "${NOTICE_FLAG} Current version: ${WHITE}$BASE_STRING"
        echo -e "${NOTICE_FLAG} Latest commit hash: ${WHITE}$LATEST_HASH"
        V_MINOR=$((V_MINOR + 1))
        V_PATCH=0
        SUGGESTED_VERSION="$V_MAJOR.$V_MINOR.$V_PATCH"
        echo -ne "${QUESTION_FLAG} ${CYAN}Enter a version number [${WHITE}$SUGGESTED_VERSION${CYAN}]: "
        read INPUT_STRING
        if [ "$INPUT_STRING" = "" ]; then
            INPUT_STRING=$SUGGESTED_VERSION
        fi

        #Make sure that the user chose a proper semantic version
        if [[ ! $INPUT_STRING =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            exit_with_error "You have not chosen a proper semantic version (Ex. 1.0.0). The release engineering script will now exit."
        fi

        echo -e "${NOTICE_FLAG} Will set new version to be ${WHITE}$INPUT_STRING"
        RELEASE_VERSION_NUMBER=$INPUT_STRING

    else
        echo -e "${WARNING_FLAG} Could not find a VERSION file."
        echo -ne "${QUESTION_FLAG} ${CYAN}Do you want to create a version file and start from scratch? [${WHITE}y${CYAN}]: "
        read RESPONSE
        if [ "$RESPONSE" = "" ]; then RESPONSE="y"; fi
        if [ "$RESPONSE" = "Y" ]; then RESPONSE="y"; fi
        if [ "$RESPONSE" = "Yes" ]; then RESPONSE="y"; fi
        if [ "$RESPONSE" = "yes" ]; then RESPONSE="y"; fi
        if [ "$RESPONSE" = "YES" ]; then RESPONSE="y"; fi
        if [ "$RESPONSE" = "y" ]; then
            touch VERSION
            touch CHANGELOG.md
            RELEASE_VERSION_NUMBER="0.1.0"
        fi
    fi
}

function create_new_feature() {
    local FEATURE_VERSION="${1}.1"
    echo "Creating a new feature: ${1}"
    # fetch the potential branch from remote in case it is not local
    msg "Fetching this branch name from remote. This may fail and that is ok. \n"
    git fetch origin $1
    # fetch the potential tag from remote in case it is not local
    msg "Fetching this tag name from remote. This may fail and that is ok. \n"
    git fetch origin refs/tags/$FEATURE_VERSION
    # Cutting a new branch for the feature. This can fail if the branch already exists.
    git checkout -b $1
    exit_if_error "Could not create branch for release"

    # This can fail if the tag already exists.
    git tag -a -m "Tag release version ${FEATURE_VERSION}." "$FEATURE_VERSION"
    exit_if_error "Could not create tag for release"

    git push origin refs/tags/$FEATURE_VERSION

    git push -u origin $1
}

function bump_feature_build_version() {
    get_most_recent_tag_for_branch $1
    # If there is no most recent tag then tell the user that they probaly want to cut a new release
    if [ -z "$MOST_RECENT_TAG" ]
    then
        NEW_FEATURE_VERSION="${1}.1"
    else
        BASE_LIST=(`echo $MOST_RECENT_TAG | tr '.' ' '`)
        V_BUILD=${BASE_LIST[3]}
        V_NEXT_BUILD=$((V_BUILD + 1))
        NEW_FEATURE_VERSION="${1}.${V_NEXT_BUILD}"
    fi

    echo -e "$PUSHING_MSG"

    # This can fail if the tag already exists.
    git tag -a -m "Tag feature version ${NEW_FEATURE_VERSION}." "$NEW_FEATURE_VERSION"
    exit_if_error "Could not create tag for feature"

    git push origin refs/tags/$NEW_FEATURE_VERSION
}

function create_work_branch() {
    echo "Creating a new work branch: ${1}"
    # fetch the potential branch from remote in case it is not local
    msg "Fetching this branch name from remote. This may fail if the branch does not exist and that is ok. \n"
    git fetch origin $1
    
    git checkout -b $1
    exit_if_error "Could not create work branch for this feature"

    git push -u origin $1
}

function get_release_operation(){
	clear
	printf "${WHITE}--------------------------------------------------------------------------------${RESET}"
	msg "What release operation do you want to perform? \n"
    printf "${WHITE}--------------------------------------------------------------------------------${RESET} \n"

	PS3='Choice: '
	options=("Create a New Release Branch." "Bump the Current Release Build Number." "Create a New Feature Branch." "Bump the Current Feature Build Number." "Create a Work Branch for Your Feature." "Cancel")
	select opt in "${options[@]}"
	do
		case $opt in
			"Create a New Release Branch.")
				export BUMP_RELEASE_CHOICE=1
				break
				;;
			"Bump the Current Release Build Number.")
				export BUMP_RELEASE_CHOICE=2
				break
				;;
            "Create a New Feature Branch.")
				export BUMP_RELEASE_CHOICE=3
				break
				;;
			"Bump the Current Feature Build Number.")
				export BUMP_RELEASE_CHOICE=4
				break
				;;
            "Create a Work Branch for Your Feature.")
				export BUMP_RELEASE_CHOICE=5
				break
				;;
            "Cancel")
                msg "Script Has Been Canceled."
				exit 0
				;;
			*) echo "Invalid choice: $REPLY. Please type '1', '2', '3', '4', '5', or '6'.";;
		esac
	done
}

# Ask the user if they are conneceted to the VPN because they will be running git commands against the repo
danger_to_continue "This script runs Git commands against the remote repo. Please make sure you are connected to the ISC network and run a git pull if your code is out of date."

get_release_operation

get_current_git_branch

if [ $BUMP_RELEASE_CHOICE = 1 ]; then

    choose_new_version

    create_new_release $RELEASE_VERSION_NUMBER
elif [ $BUMP_RELEASE_CHOICE = 2 ]; then

    get_release_version

    RELEASE_VERSION="release-${RELEASE_VERSION_NUMBER}"

    # You should only be bumping the release version from the corresponding release branch.
    if [ $RELEASE_VERSION != $CURRENT_GIT_BRANCH ]; then
        danger_to_continue "You are trying to bump the relase build version from a branch that does not match the current release: ${RELEASE_VERSION}. This is most likely a mistake."
    fi
    bump_release_build_version $RELEASE_VERSION_NUMBER

elif [ $BUMP_RELEASE_CHOICE = 3 ]; then

    get_release_version
    RELEASE_VERSION="release-${RELEASE_VERSION_NUMBER}"

    echo -ne "${QUESTION_FLAG} ${CYAN}Enter Your feature's Jira code (Example: IFS-1234): "
    read FEATURE_CODE
    FEATURE_VERSION="feature-${FEATURE_CODE}-${RELEASE_VERSION_NUMBER}"

    if [[ ! $FEATURE_VERSION =~ ^feature-IFS-[0-9]+-[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        exit_with_error "Malformed feature branch code. Please make sure your feature code matches this format (Ex. IFS-1234)"
    fi

    # You should generally only be cutting new features from a release branch.
    if [ $RELEASE_VERSION != $CURRENT_GIT_BRANCH ]; then
        danger_to_continue "You are trying to create a new feature branch from a non-release branch. This is most likely a mistake."
    fi
    create_new_feature $FEATURE_VERSION

elif [ $BUMP_RELEASE_CHOICE = 4 ]; then 

    if [[ ! $CURRENT_GIT_BRANCH =~ ^feature-IFS-[0-9]+-[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        danger_to_continue "You are trying to bump the build number of a feature branch, but are not currently on a feature branch. This is most likely a mistake.\nYour current Git branch: ${CURRENT_GIT_BRANCH}"
    fi
    bump_feature_build_version $CURRENT_GIT_BRANCH

elif [ $BUMP_RELEASE_CHOICE = 5 ]; then 

    if [[ ! $CURRENT_GIT_BRANCH =~ ^feature-IFS-[0-9]+-[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        danger_to_continue "You are trying to create a feature work branch, but are not currently on a feature branch. This is most likely a mistake.\n"
    fi

    echo -ne "${QUESTION_FLAG} ${CYAN}Enter Your Task's Jira code (Example: IFS-1234): "
    read FEATURE_CODE
    FEATURE_VERSION="feature-${FEATURE_CODE}-${RELEASE_VERSION_NUMBER}"

    echo -ne "${QUESTION_FLAG} ${CYAN}Enter a short description for your work branch: "
    read WORK_DESCRIPTION

    DESCRIPTION_ARRAY=($(echo "$WORK_DESCRIPTION" | tr ' ' '\n'))
    FORMATTED_DESCRIPTION=""
    for WORD in "${DESCRIPTION_ARRAY[@]}"
    do
        FORMATTED_DESCRIPTION="$FORMATTED_DESCRIPTION-$WORD" # this line changed
    done

    EPIC_CODE="$(echo $CURRENT_GIT_BRANCH | grep -e 'IFS\-[0-9]\+' -o)"

    WORK_BRANCH_NAME="work-${EPIC_CODE}-${FEATURE_CODE}${FORMATTED_DESCRIPTION}"

    echo "Generating work branch: ${WORK_BRANCH_NAME}"

    if [[ ! $WORK_BRANCH_NAME =~ ^work-IFS-[0-9]+-IFS-[0-9]+-.+$ ]]; then
        exit_with_error "Malformed work branch name. Please make sure your feature code matches this format (Ex. IFS-1234) and that you provided a description"
    fi

    create_work_branch $WORK_BRANCH_NAME
fi

echo -e "${NOTICE_FLAG} Finished."