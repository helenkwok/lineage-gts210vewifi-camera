# Camera for LineageOS 22.2 on the Galaxy Tab S2 9.7 (SM-T813)

The unofficial LineageOS 22.2 build for the SM-T813 (`gts210vewifi`) by retiredtab ships without a camera:
the legacy camera pieces were disabled in the device tree (`msm8976-common`, commit `f8c8c86`) because they
stopped working after LineageOS 18.1. This repository tries to bring them back.

## What is here

| Path | What |
|---|---|
| `local_manifests/gts210vewifi.xml` | Device, kernel and vendor trees plus legacy Qualcomm repos on top of LineageOS 22.2 |
| `patches/0001-msm8976-common-re-enable-camera.patch` | Re-enables `camera.msm8952`, `libshims_camera`, `camera.device@1.0-impl` and the camera provider |
| `port/msm8952-display-Android.bp` | Provides `display_intf_headers`, which LineageOS 22.2's surfaceflinger expects |
| `scripts/build-camera.sh` | Builds only the camera modules from a synced tree |
| `.github/workflows/build-camera.yml` | Runs the sync and build on GitHub Actions and uploads the modules |

## Reference: how the camera works on LineageOS 18.1

On 18.1 the camera works through the legacy Camera1 API (tested with Open Camera: rear and front photos and
1080p video). Each open first fails on a flash reservation, then succeeds after about 5 seconds; apps on the
Camera2 API give up at a fixed 5-second timeout in `CameraDeviceUserShim`.

## Status

Work in progress. The modules are not yet built or tested on 22.2.

## Credits

Device, kernel and vendor trees: retiredtab, syphyr (Deltadroid) and the LineageOS and LineageOS-UL projects.
