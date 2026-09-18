#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
BUILD_ROOT="${SCHEDULE_BUILD_ROOT:-$PWD/.build}"
mkdir -p "$BUILD_ROOT"
swiftc -O -module-cache-path "$BUILD_ROOT/module-cache" \
  Sources/ScheduleCore/Models/Schedule.swift \
  Sources/ScheduleCore/Models/WeekGridLayout.swift \
  Sources/ScheduleCore/Utilities/TimeZoneService.swift \
  Benchmarks/RenderingBenchmark.swift -o "$BUILD_ROOT/rendering-benchmark"
"$BUILD_ROOT/rendering-benchmark"
