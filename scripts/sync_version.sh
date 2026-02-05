#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ROOT_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"

VERSION=$(cat "$ROOT_DIR/VERSION" | tr -d '[:space:]')
BUILD_NUMBER=$(cat "$ROOT_DIR/BUILD_NUMBER" | tr -d '[:space:]')

echo "Syncing version: $VERSION (Build: $BUILD_NUMBER)"

if [ -f "$ROOT_DIR/apps/mac/project.yml" ]; then
    sed -i '' 's/MARKETING_VERSION: .*/MARKETING_VERSION: "'"$VERSION"'"/' "$ROOT_DIR/apps/mac/project.yml"
    sed -i '' 's/CURRENT_PROJECT_VERSION: .*/CURRENT_PROJECT_VERSION: "'"$BUILD_NUMBER"'"/' "$ROOT_DIR/apps/mac/project.yml"
    echo "Updated apps/mac/project.yml"
fi

if [ -f "$ROOT_DIR/Cargo.toml" ]; then
    sed -i '' 's/^version = .*/version = "'"$VERSION"'"/' "$ROOT_DIR/Cargo.toml"
    echo "Updated root Cargo.toml workspace version"
fi
