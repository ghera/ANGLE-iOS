#!/usr/bin/env bash
set -euo pipefail

### CONFIG ###
ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
ANGLE_DIR="${ROOT_DIR}/angle"

### DEPOT_TOOLS ###
echo "Checking depot_tools..."
if ! command -v gclient &>/dev/null; then
  echo "'gclient' not found in PATH."
  echo "Make sure depot_tools is installed and in your PATH:"
  echo "export PATH=\"/path/to/depot_tools:\$PATH\""
  exit 1
fi

### FETCH HASH ###
echo "Fetching latest stable ANGLE hash from ChromiumDash..."

ANGLE_HASH=$(curl -s "https://chromiumdash.appspot.com/fetch_releases?channel=Stable&platform=iOS&num=1" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['hashes']['angle'])" 2>/dev/null \
  || true)

if [[ -z "$ANGLE_HASH" ]]; then
  echo "Failed to retrieve ANGLE hash from ChromiumDash."
  echo "Try --hash <commit> to use a manual commit hash."
  exit 1
fi

echo "Stable ANGLE hash: $ANGLE_HASH"

### CHECKOUT ###
if [[ ! -d "$ANGLE_DIR/.git" ]]; then
  echo "'$ANGLE_DIR' is not a git repository."
  echo "Clone ANGLE first, e.g.: fetch angle"
  exit 1
fi

cd "$ANGLE_DIR"

echo "Fetching updates from origin..."
git fetch --tags --quiet origin 2>&1 | tail -5 || true

echo "Checking out $ANGLE_HASH ..."
git checkout "$ANGLE_HASH"

### SYNC ###
echo "Syncing dependencies with gclient sync..."
gclient sync -D --with_branch_heads --with_tags --nohooks 2>&1 | tail -10 || true

### DONE ###
CURRENT_HASH=$(git rev-parse HEAD)
if [[ "$CURRENT_HASH" == "$ANGLE_HASH"* ]]; then
  echo ""
  echo "ANGLE successfully updated!"
  echo "Commit : $CURRENT_HASH"
  echo "Message: $(git log -1 --pretty=%s)"

  ### PRINT ANGLE VERSION ###
  # Same format compiled into the binaries by commit_id.py:
  #   revision = git rev-list HEAD --count, hash = git rev-parse --short=12 HEAD
  VERSION_HEADER="${ANGLE_DIR}/src/common/angle_version.h"
  MAJOR=$(sed -n 's/^#define ANGLE_MAJOR_VERSION //p' "${VERSION_HEADER}")
  MINOR=$(sed -n 's/^#define ANGLE_MINOR_VERSION //p' "${VERSION_HEADER}")
  REV=$(git rev-list HEAD --count)
  SHORT_HASH=$(git rev-parse --short=12 HEAD)
  echo ""
  echo "ANGLE ${MAJOR}.${MINOR}.${REV} git hash: ${SHORT_HASH}"
else
  echo "Checkout may have failed (HEAD=$CURRENT_HASH)."
fi
