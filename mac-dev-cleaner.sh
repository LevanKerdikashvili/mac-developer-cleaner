#!/usr/bin/env bash
# Mac Developer Cleaner - interactive cleanup of macOS developer caches.
# Copyright (c) 2026 Levan Kerdikashvili
set -u

DRY_RUN=0
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=1
elif [[ $# -ne 0 ]]; then
  printf 'Usage: %s [--dry-run]\n' "$0"
  exit 2
fi

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "macOS is required." >&2
  exit 1
fi

size_kb() {
  if [[ -e "$1" && ! -L "$1" ]]; then
    du -sk "$1" 2>/dev/null | awk '{print $1+0}'
  else
    echo 0
  fi
}
human_kb() {
  awk -v k="$1" 'BEGIN { if (k >= 1048576) printf "%.2f GiB", k/1048576; else if (k >= 1024) printf "%.1f MiB", k/1024; else printf "%d KiB", k }'
}
sum_size() {
  local total=0 path current
  for path in "$@"; do
    current=$(size_kb "$path")
    total=$((total + current))
  done
  echo "$total"
}
confirm() {
  local response
  printf "Clean this stage? [y/N]: "
  IFS= read -r response || return 1
  [[ "$response" == "y" || "$response" == "Y" || "$response" == "yes" || "$response" == "YES" ]]
}

snapshots=()
cache_images=()
for avd in "$HOME"/.android/avd/*.avd; do
  [[ -d "$avd" && ! -L "$avd" ]] || continue
  [[ -d "$avd/snapshots" && ! -L "$avd/snapshots" ]] && snapshots+=("$avd/snapshots")
  [[ -f "$avd/cache.img" && ! -L "$avd/cache.img" ]] && cache_images+=("$avd/cache.img")
done

ios_cache=("$HOME/Library/Developer/CoreSimulator/Caches")
xcode_data=("$HOME/Library/Developer/Xcode/DerivedData")
gradle_cache=("$HOME/.gradle/caches")
maven_repo=("$HOME/.m2/repository")
npm_cache=("$HOME/.npm/_cacache")

android_busy=0
ios_busy=0
if pgrep -f '[q]emu-system|[e]mulator.*-avd|[e]mulator.*@' >/dev/null 2>&1; then android_busy=1; fi
if command -v xcrun >/dev/null 2>&1; then
  if ! booted=$(xcrun simctl list devices booted 2>/dev/null); then
    ios_busy=1
  elif printf '%s\n' "$booted" | grep -q '(Booted)'; then
    ios_busy=1
  fi
fi

s1=$(sum_size "${snapshots[@]}")
s2=$(sum_size "${cache_images[@]}")
s3=$(sum_size "${ios_cache[@]}")
s4=$(sum_size "${xcode_data[@]}")
s5=$(sum_size "${gradle_cache[@]}")
s6=$(sum_size "${maven_repo[@]}")
s7=$(sum_size "${npm_cache[@]}")
if [[ $android_busy -eq 1 ]]; then s1=0; s2=0; fi
if [[ $ios_busy -eq 1 ]]; then s3=0; fi
if ! command -v npm >/dev/null 2>&1; then s7=0; fi

potential=$((s1+s2+s3+s4+s5+s6+s7))
approved=0
failures=0

printf '\nMac Developer Cleaner%s\n' "$([[ $DRY_RUN -eq 1 ]] && echo ' (DRY RUN)' || true)"
echo "Stop builds and close development tools before cleaning."
echo "Every stage is optional. Default answer is No."
printf "Estimated eligible cleanup: %s\n" "$(human_kb "$potential")"
printf "Android emulator running: %s | iOS simulator booted or unknown: %s\n" "$android_busy" "$ios_busy"
echo "Sizes are estimates; actual free space may differ on APFS."

stage() {
  local title="$1" details="$2" estimate="$3" mode="$4" path
  shift 4
  printf '\n%s\n%s\n' "$title" "$details"
  printf 'Estimated size: %s\n' "$(human_kb "$estimate")"
  if [[ "$estimate" -eq 0 ]]; then
    echo "Skipped - no eligible data or device is active."
    return
  fi
  for path in "$@"; do
    [[ -e "$path" && ! -L "$path" ]] && printf '  %s (%s)\n' "$path" "$(human_kb "$(size_kb "$path")")"
  done
  if ! confirm; then echo "Skipped."; return; fi
  approved=$((approved + estimate))
  if [[ $DRY_RUN -eq 1 ]]; then echo "Preview only - nothing deleted."; return; fi
  if [[ "$mode" == "npm" ]]; then
    if npm cache clean --force; then echo "npm cache cleaned."; else failures=$((failures+1)); echo "npm cleanup failed." >&2; fi
  else
    for path in "$@"; do
      [[ -e "$path" && ! -L "$path" ]] || continue
      if rm -rf -- "$path"; then printf 'Removed: %s\n' "$path"
      else failures=$((failures+1)); printf 'FAILED: %s\n' "$path" >&2; fi
    done
  fi
}

stage "1. Android snapshots" "Removes saved Quick Boot states, not AVDs or user data." "$s1" files "${snapshots[@]}"
stage "2. Android cache images" "Removes cache.img files, not emulator definitions." "$s2" files "${cache_images[@]}"
stage "3. iOS Simulator cache" "Keeps simulator devices, installed apps, data and runtimes." "$s3" files "${ios_cache[@]}"
stage "4. Xcode DerivedData" "Generated build files and indexes will regenerate." "$s4" files "${xcode_data[@]}"
stage "5. Gradle cache" "Dependencies and transforms may be downloaded again." "$s5" files "${gradle_cache[@]}"
stage "6. Maven local repository" "CAUTION: Locally installed and private artifacts might be unrecoverable." "$s6" files "${maven_repo[@]}"
stage "7. npm cache" "Runs npm cache clean --force." "$s7" npm "${npm_cache[@]}"

printf '\n=========== SUMMARY ===========\n'
printf 'Potential eligible cleanup: %s\n' "$(human_kb "$potential")"
printf 'Approved stages estimate: %s\n' "$(human_kb "$approved")"
printf 'Failed operations: %d\n' "$failures"
echo "Free disk space now:"
df -h / | tail -1
if [[ $DRY_RUN -eq 1 ]]; then echo "Dry run complete - nothing was deleted."; fi
echo "Emulator snapshots may be recreated by Quick Boot."
[[ "$failures" -eq 0 ]]
