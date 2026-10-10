# HideNotch

A small macOS app that adds a black menu bar to your wallpapers so the notch on MacBook Pro / Air disappears.
It is a free replacement for TopNotch for when that app stops working after a macOS update: instead of drawing an overlay
on screen, the black bar is baked into the wallpaper image itself, so it keeps working on any macOS version.

## Install

1. Download `HideNotch-<version>.dmg` from the [latest release](../../releases/latest).
2. Open it and drag **HideNotch** to **Applications**.
3. The app is ad-hoc signed, not notarized. On first launch right-click the app, choose **Open**, then **Open** again.
   If macOS still refuses, run `xattr -dr com.apple.quarantine /Applications/HideNotch.app`.

## Use

1. Drop your wallpapers (or a folder of them) onto the window.
2. Click **Add Black Bar**. New copies are written to `~/Pictures/HideNotch` by default; your originals are untouched.
3. In **System Settings → Wallpaper**, pick the new images and set the placement to **Fill Screen**.

## How it works

- **Bar height** is measured from your display's notch geometry, relative to its default resolution, so it stays correct
  when you switch to a scaled ("More Space") mode.
- **Crop-aware.** macOS fills the screen and crops the overflow evenly, so the bar is placed below any rows macOS crops
  from taller images.
- **Rounded window corners.** Small black fillers sit under the bar at the visible left and right edges so wallpaper
  does not peek out around the rounded top corners of maximized windows. Tune the radius under **Options** if you still
  see a sliver.

## Build from source

Requires the Xcode command line tools (no full Xcode needed).

```bash
swift build -c release          # just the binary
scripts/build.sh 1.0.0          # HideNotch.app and HideNotch-1.0.0.dmg in ./build
```

`scripts/make_icon.py` regenerates `Resources/AppIcon.icns` (needs Pillow).

## License

MIT
