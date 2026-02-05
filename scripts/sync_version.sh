#!/bin/bash

# Get the directory of the script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ROOT_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"

# Read VERSION and BUILD_NUMBER
VERSION=$(cat "$ROOT_DIR/VERSION" | tr -d '[:space:]')
BUILD_NUMBER=$(cat "$ROOT_DIR/BUILD_NUMBER" | tr -d '[:space:]')

echo "Syncing version: $VERSION (Build: $BUILD_NUMBER)"

# Update apps/mac/project.yml
# Use sed to replace MARKETING_VERSION and CURRENT_PROJECT_VERSION
if [ -f "$ROOT_DIR/apps/mac/project.yml" ]; then
    sed -i '' 's/MARKETING_VERSION: .*/MARKETING_VERSION: "'"$VERSION"'"/' "$ROOT_DIR/apps/mac/project.yml"
    sed -i '' 's/CURRENT_PROJECT_VERSION: .*/CURRENT_PROJECT_VERSION: "'"$BUILD_NUMBER"'"/' "$ROOT_DIR/apps/mac/project.yml"
    echo "Updated apps/mac/project.yml"
fi

# Update Cargo.toml workspace version
if [ -f "$ROOT_DIR/Cargo.toml" ]; then
    sed -i '' 's/^version = .*/version = "'"$VERSION"'"/' "$ROOT_DIR/Cargo.toml"
    echo "Updated root Cargo.toml workspace version"
fi
