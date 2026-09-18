#!/bin/bash
set -euo pipefail
ARCHIVE="${1:?Usage: bash verify-distribution.sh /path/to/application.zip}"
STAGING="$(mktemp -d "${TMPDIR:-/tmp}/schedule-distribution.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT
ditto -x -k "$ARCHIVE" "$STAGING"
APPLICATIONS=("$STAGING/"*.app)
if [ "${#APPLICATIONS[@]}" -ne 1 ] || [ ! -d "${APPLICATIONS[0]}" ]; then
  echo "ERROR: archive must contain exactly one application" >&2
  exit 1
fi
APP_DIR="${APPLICATIONS[0]}"
codesign --verify --deep --strict "$APP_DIR"
"$APP_DIR/Contents/MacOS/AvailabilitySchedule" --verify-package

# A missing packaged file must fail even when a build-machine resource exists.
# Only this temporary copy is changed. No user settings or drafts are accessed.
mv "$APP_DIR/Contents/Resources/PublicAvailabilitySchedule_ScheduleApp.bundle/repository-config.json" "$STAGING/withheld-config.json"
set +e
"$APP_DIR/Contents/MacOS/AvailabilitySchedule" --verify-package
CHECK_STATUS=$?
set -e
if [ "$CHECK_STATUS" -ne 1 ]; then
  echo "ERROR: missing-resource check must exit cleanly with status 1" >&2
  exit 1
fi
echo "OK: extracted application is self-contained; missing resources are handled without a crash"
