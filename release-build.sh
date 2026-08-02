#!/usr/bin/env bash
#
# Prompts for release-signing credentials and runs the release build inside
# mingc/android-build-box.
#
# Why prompt instead of passing -P/-e values with the secret baked into the
# command line:
#   - Values typed via `read` never touch shell history and never appear as
#     a process argument (visible to `ps`/other users on a shared machine).
#   - `docker run -e VAR_NAME` (name only, no "=value") copies VAR_NAME
#     straight from this shell's environment into the container's process
#     environment as one opaque string. It is never re-tokenized by a shell,
#     so spaces/quotes/special characters in an alias or password survive
#     intact - unlike threading "-PRELEASE_KEY_ALIAS=$RELEASE_KEY_ALIAS"
#     through docker -> bash -c -> gradle, where the value gets shell-parsed
#     at each layer.
#   - app/build.gradle already reads these three names via System.getenv(),
#     so nothing else needs to change.
#
# Nothing here is written to disk. Passwords are read with -s (not echoed).
#
# Assumes the keystore is at the project root, named "keystore" (this is
# also what build.gradle defaults to and what .gitignore excludes). If yours
# lives elsewhere, export RELEASE_STORE_FILE yourself before running this
# script, as a path relative to the project root.

set -euo pipefail

if [ ! -f "$(pwd)/keystore" ] && [ -z "${RELEASE_STORE_FILE:-}" ]; then
    echo "No 'keystore' file found at the project root, and RELEASE_STORE_FILE isn't set." >&2
    echo "Either place your keystore at ./keystore, or export RELEASE_STORE_FILE first." >&2
    exit 1
fi

read -r -s -p "Keystore password: " RELEASE_STORE_PASSWORD
echo
read -r -p "Key alias: " RELEASE_KEY_ALIAS
read -r -s -p "Key password: " RELEASE_KEY_PASSWORD
echo

export RELEASE_STORE_PASSWORD RELEASE_KEY_ALIAS RELEASE_KEY_PASSWORD

cleanup() {
    unset RELEASE_STORE_PASSWORD RELEASE_KEY_ALIAS RELEASE_KEY_PASSWORD
}
trap cleanup EXIT

docker run --rm \
    -e RELEASE_STORE_PASSWORD \
    -e RELEASE_KEY_ALIAS \
    -e RELEASE_KEY_PASSWORD \
    ${RELEASE_STORE_FILE:+-e RELEASE_STORE_FILE} \
    -v "$(pwd)":/project \
    mingc/android-build-box \
    bash -c "./gradlew assembleRelease"
