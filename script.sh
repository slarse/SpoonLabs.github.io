#!/bin/bash
#
# Deploys the current Spoon website to the website server.
# To test the site locally before deploying run `jekyll serve`
# in the website branch.
#
# Copied in the config of job "website deployer" on Jenkins

set -o errexit
set -o nounset
set -o pipefail

if [[ -z $1 ]]; then
    INITIAL_WORKDIR="$PWD"
else
    INITIAL_WORKDIR="$1"
fi

#SOURCE_REPO="https://github.com/INRIA/spoon.git" # TODO use
SOURCE_REPO="https://github.com/slarse/spoon.git" # TODO remove
SOURCE_DIR="$INITIAL_WORKDIR/temp-spoon-clone"
WEBSITE_SOURCE_DIR="$SOURCE_DIR/doc"
WEBSITE_GENERATED_DIR="$WEBSITE_SOURCE_DIR/_site"
WEBSITE_DST_DIR="$INITIAL_WORKDIR/spoon-website"
WEBSITE_REPO="https://github.com/spoonlabs/spoonlabs.github.io"
WEBSITE_BRANCH=main

function generate_javadoc() {
    # Generate Javadoc and place it in the website sources
    cd "$SOURCE_DIR"
    git switch issue/3759-use-kramdown-for-website # TODO remove
    mvn -B site

    mkdir "$WEBSITE_SOURCE_DIR"/mvnsites/
    cp -r target/site/ "$WEBSITE_SOURCE_DIR"/mvnsites/spoon-core
}

function generate_website() {
    # Generate the website (Javadoc must be generated first!)
    cd "$WEBSITE_SOURCE_DIR"
    cp ../README.md doc_homepage.md

    LATESTVERSION=`curl -s "http://search.maven.org/solrsearch/select?q=g:%22fr.inria.gforge.spoon%22+AND+a:%22spoon-core%22&core=gav" | jq -r '.response.docs | map(select(.v | match("^[0-9.]+$")) | .v )| .[0]'`
    sed -i -e "s/^spoon_release: .*/spoon_release: $LATESTVERSION/" _config.yml
    SNAPSHOTVERSION=`xmlstarlet sel -t -v /_:project/_:version ../pom.xml`
    sed -i -e "s/^spoon_snapshot: .*/spoon_snapshot: \"$SNAPSHOTVERSION\"/" _config.yml
    jekyll build
}

function configure_git_as_github_bot() {
    git config --local user.email github-actions[bot]@users.noreply.github.com
    git config --local user.name github-actions[bot]
}

function update_website() {
    # Update the existing website with the enwly generated one
    cd "$WEBSITE_DST_DIR"

    git init -b "$WEBSITE_BRANCH"
    configure_git_as_github_bot

    git remote add origin "$WEBSITE_REPO"
    git fetch origin

    # this is intricate; we update the HEAD reference without updating the working directory,
    # and then copy the website into the working directory and force-commit it
    git update-ref refs/heads/"$WEBSITE_BRANCH" refs/remotes/origin/"$WEBSITE_BRANCH"
    cp -r "$WEBSITE_GENERATED_DIR"/* .
    git add . --force
    git commit -m "Update website" || {
        echo "Nothing to commit, website up-to-date"
        return
    }
}

cd "$INITIAL_WORKDIR"
mkdir "$WEBSITE_DST_DIR"
git clone "$SOURCE_REPO" "$SOURCE_DIR"

generate_javadoc
generate_website
update_website
