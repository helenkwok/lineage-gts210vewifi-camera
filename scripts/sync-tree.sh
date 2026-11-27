#!/bin/bash
# Shallow-sync LineageOS 22.2 for gts210vewifi into a small disk (about 90 GB).
# Syncs in batches and deletes each batch's git objects right away; the build does not need git history.
# Also removes prebuilt toolchains this build never uses.
# Usage: scripts/sync-tree.sh <empty dir>
set -euo pipefail
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$1"; mkdir -p "$SRC"; cd "$SRC"
REPO="${REPO:-repo}"
BATCH="${BATCH:-120}"

"$REPO" init -q -u https://github.com/LineageOS/android.git -b lineage-22.2 --git-lfs --depth=1 \
  --no-clone-bundle -g default,-notdefault,-darwin,-mips,-x86,-riscv64
mkdir -p .repo/local_manifests && cp "$REPO_DIR/local_manifests/"*.xml .repo/local_manifests/

prune_unused() {
  rm -rf prebuilts/clang/host/linux-x86/clang-r530567b prebuilts/clang/host/linux-x86/clang-r522817 \
         prebuilts/rust/darwin-x86 prebuilts/rust/windows-x86 prebuilts/rust/linux-x86/1.80.1
}

sync_batch() {  # args: "path : name" lines on stdin
  local paths=() names=()
  while IFS= read -r line; do paths+=("${line%% : *}"); names+=("${line##* : }"); done
  [ ${#paths[@]} -gt 0 ] || return 0
  "$REPO" sync -q -c -j16 --no-tags --no-clone-bundle --optimized-fetch --force-sync "${paths[@]}"
  for n in "${names[@]}"; do rm -rf ".repo/project-objects/$n.git"; done
  for p in "${paths[@]}"; do rm -rf ".repo/projects/$p.git"; done
  prune_unused
  echo "[sync] +${#paths[@]} projects, disk free $(df -h . | awk 'NR==2{print $4}')"
}

"$REPO" list --all > /tmp/projects.txt
n=$(wc -l < /tmp/projects.txt); echo "[sync] $n projects"; [ "$n" -gt 100 ] || { echo "repo list returned too few projects"; exit 1; }
# biggest first, alone, so their objects are freed before anything else lands
{ grep -E '^prebuilts/(clang/host/linux-x86|rust) :' /tmp/projects.txt || true; } | sync_batch
grep -vE '^prebuilts/(clang/host/linux-x86|rust) :' /tmp/projects.txt > /tmp/rest.txt || true
split -l "$BATCH" /tmp/rest.txt /tmp/batch.
for b in /tmp/batch.*; do sync_batch < "$b"; done
echo "[sync] done"; du -sh "$SRC" 2>/dev/null; df -h .
