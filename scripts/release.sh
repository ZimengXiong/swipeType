#!/bin/bash
set -e

# Setup paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ROOT_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"
VERSION_FILE="$ROOT_DIR/VERSION"
BUILD_NUMBER_FILE="$ROOT_DIR/BUILD_NUMBER"
CASK_FILE="$ROOT_DIR/homebrew/Casks/swipetype.rb"

# Check for uncommitted changes (excluding version files which we might change)
if ! git diff-index --quiet HEAD --; then
    echo "Warning: You have uncommitted changes in the main repo."
    read -p "Do you want to continue? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Read current version
CURRENT_VERSION=$(cat "$VERSION_FILE" | tr -d '[:space:]')
IFS='.' read -r -a VERSION_PARTS <<< "$CURRENT_VERSION"
MAJOR="${VERSION_PARTS[0]}"
MINOR="${VERSION_PARTS[1]}"
PATCH="${VERSION_PARTS[2]}"

echo "Current Version: $CURRENT_VERSION"
echo "Select release type:"
echo "1) Patch ($MAJOR.$MINOR.$((PATCH + 1)))"
echo "2) Minor ($MAJOR.$((MINOR + 1)).0)"
echo "3) Major ($((MAJOR + 1)).0.0)"
echo "4) No version change (Just build & release)"

read -p "Enter choice [1-4]: " CHOICE

NEW_VERSION="$CURRENT_VERSION"

case $CHOICE in
    1)
        NEW_VERSION="$MAJOR.$MINOR.$((PATCH + 1))"
        ;;
    2)
        NEW_VERSION="$MAJOR.$((MINOR + 1)).0"
        ;;
    3)
        NEW_VERSION="$((MAJOR + 1)).0.0"
        ;;
    4)
        echo "Keeping version $CURRENT_VERSION"
        ;;
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac

# Update VERSION file if changed
if [ "$NEW_VERSION" != "$CURRENT_VERSION" ]; then
    echo "$NEW_VERSION" > "$VERSION_FILE"
    echo "Updated VERSION to $NEW_VERSION"
fi

echo "Starting Build & Package Process..."
cd "$ROOT_DIR"
make dmg-mac

# Read the final Build Number
FINAL_BUILD=$(cat "$BUILD_NUMBER_FILE" | tr -d '[:space:]')
TAG_NAME="v$NEW_VERSION"
RELEASE_TITLE="Release $NEW_VERSION (Build $FINAL_BUILD)"
DMG_PATH="apps/mac/build/SwipeType.dmg"

if [ ! -f "$DMG_PATH" ]; then
    echo "Error: DMG file not found at $DMG_PATH"
    exit 1
fi

# Calculate SHA256 for Homebrew
echo "SHASUMing DMG..."
SHA256=$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')
echo "SHA256: $SHA256"

echo "Build Complete."
echo "Version: $NEW_VERSION"
echo "Build:   $FINAL_BUILD"

read -p "Proceed with Git Commit, Tag, Push, GitHub Release, and Homebrew sync? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted. Build artifacts are in apps/mac/build/"
    exit 0
fi

# 1. Update Homebrew Cask
echo "Updating Homebrew Cask..."
if [ -f "$CASK_FILE" ]; then
    sed -i '' "s/version \".*\"/version \"$NEW_VERSION\"/" "$CASK_FILE"
    sed -i '' "s/sha256 \".*\"/sha256 \"$SHA256\"/" "$CASK_FILE"
    echo "Updated $CASK_FILE"
else
    echo "Warning: Cask file not found at $CASK_FILE"
fi

# 2. Main Repo Git Operations
echo "Committing main repo changes..."
git add "$VERSION_FILE" "$BUILD_NUMBER_FILE" apps/mac/project.yml Cargo.toml .gitignore
git commit -m "chore: release $TAG_NAME (Build $FINAL_BUILD)" || echo "No changes to commit in main repo"

echo "Tagging $TAG_NAME..."
git tag -a "$TAG_NAME" -m "$RELEASE_TITLE" || echo "Tag already exists"

echo "Pushing main repo to GitHub..."
git push origin main
git push origin "$TAG_NAME"

# 3. GitHub Release
echo "Creating GitHub Release..."
gh release create "$TAG_NAME" "$DMG_PATH" --title "$RELEASE_TITLE" --notes "Automated release via CLI."

# 4. Homebrew Repo Git Operations
echo "Committing Homebrew repo changes..."
cd "$ROOT_DIR/homebrew"
git add "Casks/swipetype.rb"
git commit -m "swipetype $NEW_VERSION" || echo "No changes to commit in homebrew repo"
echo "Pushing Homebrew repo to GitHub..."
git push origin main

echo "All done! Release $TAG_NAME is live and Homebrew cask is updated."
