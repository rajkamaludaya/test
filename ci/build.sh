#!/usr/bin/env bash
# ci/build.sh — single entry point for you AND Jenkins.
#   ./ci/build.sh build | analyze | test | report
# Runs directly on the Linux PC (needs gcc, cmake; cppcheck optional).
# Run it by hand the same way Jenkins does:  ./ci/build.sh build && ./ci/build.sh test
set -euo pipefail

OUT=out
BUILD=build/linux
mkdir -p "$OUT"

do_build() {
  cmake -S . -B "$BUILD" -DCMAKE_BUILD_TYPE=Debug -DCMAKE_EXPORT_COMPILE_COMMANDS=ON 2>&1 | tee "$OUT/build.log"
  cmake --build "$BUILD" -j"$(nproc)" 2>&1 | tee -a "$OUT/build.log"
}

do_analyze() {
  if ! command -v cppcheck >/dev/null; then
    echo "cppcheck not installed (sudo apt install cppcheck)" | tee "$OUT/cppcheck.txt"; return 0
  fi
  # Non-blocking for now: findings are reported, not fatal. Add --error-exitcode=1 to enforce.
  cppcheck --enable=warning,style,performance --inline-suppr --quiet \
           --project="$BUILD/compile_commands.json" 2> "$OUT/cppcheck.txt" || true
  echo "cppcheck findings: $(grep -c ': ' "$OUT/cppcheck.txt" || true)"
}

do_test() {
  (cd "$BUILD" && ctest --output-on-failure) 2>&1 | tee "$OUT/test.log"
}

# Plain HTML (no JavaScript) so it displays under Jenkins' default security policy.
do_report() {
  mkdir -p "$OUT/report"
  local commit; commit="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
  esc() { if [ -f "$1" ]; then sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' "$1"; else echo "(not run)"; fi; }
  {
    echo '<!doctype html><html><head><meta charset="utf-8"><title>Visible build report</title>'
    echo '<style>body{font-family:sans-serif;margin:2em}pre{background:#f4f4f4;padding:1em;overflow:auto}</style></head><body>'
    echo '<h1>Visible build report</h1>'
    echo "<p>Commit: <b>${commit}</b> &middot; Build: <b>${BUILD_NUMBER:-local}</b> &middot; $(date -u '+%Y-%m-%d %H:%M UTC')</p>"
    echo '<h2>Tests</h2><pre>';                  esc "$OUT/test.log";     echo '</pre>'
    echo '<h2>Static analysis (cppcheck)</h2><pre>'; esc "$OUT/cppcheck.txt"; echo '</pre>'
    echo '<h2>Build log</h2><pre>';              esc "$OUT/build.log";    echo '</pre>'
    echo '</body></html>'
  } > "$OUT/report/index.html"
  echo "Report written to $OUT/report/index.html"
}

case "${1:-build}" in
  build)   do_build ;;
  analyze) do_analyze ;;
  test)    do_test ;;
  report)  do_report ;;
  *) echo "usage: $0 build|analyze|test|report" >&2; exit 1 ;;
esac
