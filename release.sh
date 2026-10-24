#!/usr/bin/env bash
#
# release.sh: cut a Pluck release.
#
#   ./release.sh 1.2.0
#
# Sets the version, bumps the build number, commits, and creates an annotated
# tag whose message is the release notes, shown in the update window and on the
# website. Pushing the tag starts the release workflow, which builds, notarizes
# and publishes the DMG and the update feed.
#
# The version is typed once, here, so the two Xcode version fields and the git
# tag can't drift apart.
set -euo pipefail

VERSION="${1:-}"
PBX="Pluck.xcodeproj/project.pbxproj"

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Usage: ./release.sh X.Y.Z   (for example ./release.sh 1.2.0)" >&2
  exit 1
fi

# Safety checks: on main, clean, in sync, tag free.
branch="$(git branch --show-current)"
if [[ "$branch" != "main" ]]; then
  echo "Refusing: you're on '$branch', not 'main'." >&2
  exit 1
fi
if [[ -n "$(git status --porcelain)" ]]; then
  echo "Refusing: the working tree has uncommitted changes." >&2
  exit 1
fi
git fetch --quiet origin main
if [[ "$(git rev-parse HEAD)" != "$(git rev-parse origin/main)" ]]; then
  echo "Refusing: local main is not in sync with origin/main." >&2
  exit 1
fi
if git rev-parse "v$VERSION" >/dev/null 2>&1; then
  echo "Refusing: tag v$VERSION already exists." >&2
  exit 1
fi

# Bump both configurations (Debug and Release) together.
current_build="$(grep -m1 -E 'CURRENT_PROJECT_VERSION = [0-9]+;' "$PBX" | grep -oE '[0-9]+')"
new_build=$((current_build + 1))
sed -i '' -E "s/MARKETING_VERSION = [^;]+;/MARKETING_VERSION = $VERSION;/g" "$PBX"
sed -i '' -E "s/CURRENT_PROJECT_VERSION = [0-9]+;/CURRENT_PROJECT_VERSION = $new_build;/g" "$PBX"
echo "Version $VERSION, build $new_build"

git add "$PBX"
git commit -m "Release $VERSION (build $new_build)"

echo
echo "Opening your editor for the release notes. They appear in the update"
echo "window and on the website changelog. Use short bullet lines, for example:"
echo "    - Faster Preview after a screenshot"
echo "    - Fixes the Shelf closing during a drag"
echo
git tag -a "v$VERSION"

if [[ -z "$(git tag -l --format='%(contents)' "v$VERSION" | tr -d '[:space:]')" ]]; then
  echo "No release notes entered. Undoing the tag and the commit." >&2
  git tag -d "v$VERSION"
  git reset --hard HEAD~1
  exit 1
fi

git push origin main
git push origin "v$VERSION"

echo
echo "Pushed v$VERSION. The release workflow is building and notarizing it:"
echo "https://github.com/Awhalen1999/pluck/actions"
