#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ROOT_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"
VERSION_FILE="$ROOT_DIR/VERSION"
BUILD_NUMBER_FILE="$ROOT_DIR/BUILD_NUMBER"
HB_REPO_DIR="$ROOT_DIR/homebrew"
HB_CASK_REL_PATH="Casks/swipetype.rb"
CASK_FILE="$HB_REPO_DIR/$HB_CASK_REL_PATH"

ensure_homebrew_repo() {
    if [ ! -d "$HB_REPO_DIR" ]; then
        echo "Homebrew tap repo not found at $HB_REPO_DIR"
        echo "Initializing submodule..."
        git -C "$ROOT_DIR" submodule update --init --recursive homebrew
    fi

    if ! git -C "$HB_REPO_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "Error: $HB_REPO_DIR is not a git repo. Expected the homebrew-tools submodule checkout."
        echo "Fix: git submodule update --init --recursive homebrew"
        exit 1
    fi

    HB_URL="$(git -C "$ROOT_DIR" config -f .gitmodules --get submodule.homebrew.url 2>/dev/null || true)"
    if [ -n "$HB_URL" ]; then
        git -C "$HB_REPO_DIR" remote set-url origin "$HB_URL" >/dev/null 2>&1 || true
    fi

    git -C "$HB_REPO_DIR" fetch origin --prune

    HB_DEFAULT_BRANCH="$(git -C "$HB_REPO_DIR" symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null || true)"
    HB_DEFAULT_BRANCH="${HB_DEFAULT_BRANCH#origin/}"
    if [ -z "$HB_DEFAULT_BRANCH" ]; then
        HB_DEFAULT_BRANCH="main"
    fi

    if [ "$(git -C "$HB_REPO_DIR" branch --show-current)" != "$HB_DEFAULT_BRANCH" ]; then
        if git -C "$HB_REPO_DIR" show-ref --verify --quiet "refs/heads/$HB_DEFAULT_BRANCH"; then
            git -C "$HB_REPO_DIR" checkout "$HB_DEFAULT_BRANCH"
        else
            git -C "$HB_REPO_DIR" checkout -b "$HB_DEFAULT_BRANCH" "origin/$HB_DEFAULT_BRANCH"
        fi
    fi

    git -C "$HB_REPO_DIR" pull --ff-only origin "$HB_DEFAULT_BRANCH"
}

cd "$ROOT_DIR"

if ! git diff-index --quiet HEAD --; then
    echo "Warning: You have uncommitted changes in the main repo."
    read -p "Do you want to continue? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

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

if [ "$NEW_VERSION" != "$CURRENT_VERSION" ]; then
    echo "$NEW_VERSION" > "$VERSION_FILE"
    echo "Updated VERSION to $NEW_VERSION"
fi

echo "Starting Build & Package Process..."
cd "$ROOT_DIR"
make dmg-mac

FINAL_BUILD=$(cat "$BUILD_NUMBER_FILE" | tr -d '[:space:]')
TAG_NAME="v$NEW_VERSION"
RELEASE_TITLE="Release $NEW_VERSION (Build $FINAL_BUILD)"
DMG_PATH="apps/mac/build/SwipeType.dmg"

if [ ! -f "$DMG_PATH" ]; then
    echo "Error: DMG file not found at $DMG_PATH"
    exit 1
fi

echo "SHASUMing DMG..."
SHA256=$(shasum -a 256 "$DMG_PATH" | awk '{print $1}' | tr '[:upper:]' '[:lower:]')
if [[ ! "$SHA256" =~ ^[0-9a-f]{64}$ ]]; then
    echo "Error: Failed to calculate SHA256 for $DMG_PATH"
    exit 1
fi
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

echo "Updating Homebrew Cask..."
ensure_homebrew_repo

mkdir -p "$(dirname "$CASK_FILE")"
if [ ! -f "$CASK_FILE" ]; then
    cat >"$CASK_FILE" <<EOF
cask "swipetype" do
  version "$NEW_VERSION"
  sha256 "$SHA256"

  url "https://github.com/ZimengXiong/swipeType/releases/download/v#{version}/SwipeType.dmg"
  name "SwipeType"
  desc "Swipe-to-type predictor for macOS"
  homepage "https://github.com/ZimengXiong/swipeType"

  depends_on macos: ">= :ventura"

  app "SwipeType.app"

  zap trash: [
    "~/Library/Preferences/com.swipetype.SwipeType.plist",
    "~/Library/Saved Application State/com.swipetype.SwipeType.savedState"
  ]
end
EOF
else
    sed -i '' "s/^[[:space:]]*version .*/  version \"$NEW_VERSION\"/" "$CASK_FILE"
    sed -i '' "s/^[[:space:]]*sha256 .*/  sha256 \"$SHA256\"/" "$CASK_FILE"
fi

if ! grep -q "version \"$NEW_VERSION\"" "$CASK_FILE"; then
    echo "Error: Failed to update version in $CASK_FILE"
    exit 1
fi
if ! grep -q "sha256 \"$SHA256\"" "$CASK_FILE"; then
    echo "Error: Failed to update sha256 in $CASK_FILE"
    exit 1
fi
echo "Updated $CASK_FILE"

CURRENT_BRANCH=$(git branch --show-current)

echo "Committing main repo changes..."
git add "$VERSION_FILE" "$BUILD_NUMBER_FILE" apps/mac/project.yml Cargo.toml .gitignore
git commit -m "chore: release $TAG_NAME (Build $FINAL_BUILD)" || echo "No changes to commit in main repo"

echo "Tagging $TAG_NAME..."
git tag -a "$TAG_NAME" -m "$RELEASE_TITLE" || echo "Tag already exists"

echo "Pushing main repo to GitHub ($CURRENT_BRANCH)..."
git push origin "$CURRENT_BRANCH"
git push origin "$TAG_NAME"

echo "Creating GitHub Release..."
gh release create "$TAG_NAME" "$DMG_PATH" --title "$RELEASE_TITLE" --notes "Automated release via CLI."

echo "Committing Homebrew repo changes..."
cd "$HB_REPO_DIR"
git add "$HB_CASK_REL_PATH"
git commit -m "swipetype $NEW_VERSION" || echo "No changes to commit in homebrew repo"
echo "Pushing Homebrew repo to GitHub ($HB_DEFAULT_BRANCH)..."
git push origin "$HB_DEFAULT_BRANCH"

echo "All done! Release $TAG_NAME is live and Homebrew cask is updated."
