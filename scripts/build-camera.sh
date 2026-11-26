#!/bin/bash
# Build the legacy (HAL1) camera pieces for gts210vewifi on a freshly synced LineageOS 22.2 tree.
# Does not need git in the tree (CI deletes .repo history to save disk).
# Usage: scripts/build-camera.sh <lineage-22.2 source dir>
set -euo pipefail
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$(cd "$1" && pwd)"
JOBS="${JOBS:-$(nproc)}"

# 1. Re-enable the camera in msm8976-common (undoes retiredtab commit f8c8c86;
#    same change as patches/0001-msm8976-common-re-enable-camera.patch)
C="$SRC/device/samsung/msm8976-common"
[ -f "$C/camera/Android.mk.old" ] && mv "$C/camera/Android.mk.old" "$C/camera/Android.mk"
python3 - "$C/msm8976.mk" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
old = """#PRODUCT_PACKAGES += \\
#    android.hardware.camera.provider@2.4-impl \\
#    camera.device@1.0-impl \\
#    camera.msm8952 \\
#    libshims_camera

PRODUCT_NO_CAMERA := true
"""
new = """PRODUCT_PACKAGES += \\
    android.hardware.camera.provider@2.4-impl \\
    camera.device@1.0-impl \\
    camera.msm8952 \\
    libshims_camera
"""
if new not in s:
    assert old in s, "camera block not found in msm8976.mk"
    open(p, "w").write(s.replace(old, new, 1))
print("camera re-enabled")
PY

# 2. surfaceflinger in 22.2 expects display_intf_headers from the msm8952 display HAL
cp "$REPO_DIR/port/msm8952-display-Android.bp" "$SRC/hardware/qcom-caf/msm8952/display/Android.bp"

# 3. fsgen turns PRODUCT_COPY_FILES into prebuilt modules; lib/ and lib64/ copies become MultilibBoth
#    modules, so each 32-bit vendor blob also claims lib64 (180 packaging conflicts). Skip lib/lib64 there;
#    make's PRODUCT_COPY_FILES still installs them.
python3 - "$SRC/build/soong/fsgen/prebuilt_etc_modules_gen.go" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
anchor = "\tmoduleFactory := etcInstallPathToFactoryList[etcInstallPathKey]\n"
guard = anchor + ('\tif d := "/" + destDir + "/"; strings.Contains(d, "/lib/") || strings.Contains(d, "/lib64/") {\n'
                  '\t\treturn nil // ELF blobs via PRODUCT_COPY_FILES: leave them to make\n\t}\n')
if guard not in s:
    assert anchor in s, "fsgen anchor not found"
    open(p, "w").write(s.replace(anchor, guard, 1))
print("fsgen guard applied")
PY

# 4. Keep Soong analysis small: drop device trees this build never uses
for d in device/generic/car device/google/atv device/lineage/atv device/lineage/car device/google/trout; do
  rm -rf "${SRC:?}/$d"
done

cd "$SRC"
export GOGC="${GOGC:-50}" ROOMSERVICE_BRANCHES=none
set +u; source build/envsetup.sh; lunch lineage_gts210vewifi-bp1a-userdebug; set -u
m -j"$JOBS" \
  camera.msm8952 libshims_camera camera.device@1.0-impl \
  android.hardware.camera.provider@2.4-impl android.hardware.camera.provider@2.4-legacy \
  android.hardware.camera.provider@2.4-service

# 5. Collect outputs
OUT="$SRC/out/target/product/gts210vewifi"
mkdir -p "$REPO_DIR/artifacts"
( cd "$OUT" && find system vendor \( -name 'camera.msm8952.so' -o -name 'libshims_camera.so' -o -name 'camera.device@1.0-impl.so' \
    -o -name 'android.hardware.camera.provider@2.4-*' \) -print0 | xargs -0 tar czf "$REPO_DIR/artifacts/camera-modules.tar.gz" )
tar tzf "$REPO_DIR/artifacts/camera-modules.tar.gz"
