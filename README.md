# ANGLE-iOS

[![Build Status](https://img.shields.io/badge/build-passing-brightgreen)](https://github.com/yourusername/angle-xcframework-builder)
[![License](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

This repository provides a script to build ANGLE as an iOS XCFramework, ready to be imported into Xcode projects. It supports device and simulator (arm64) architectures, generates umbrella headers, and properly structures headers and module maps.

---

## Prerequisites

### 1) Install depot_tools

```bash
git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git
export PATH=`pwd`/depot_tools:$PATH
mkdir angle && cd angle
fetch angle
```

---

### 2) Checkout the latest stable version (optional)

You can retrieve the latest stable Chromium release with:

```bash
curl -s "https://chromiumdash.appspot.com/fetch_releases?channel=Stable&platform=iOS&num=1"
```

Example output:

```json
[
  {
    "channel": "Stable",
    "chromium_main_branch_position": 1552494,
    "hashes": {
      "angle": "a96fca8d5ee2ca61e8de419e38cd577579281c9e",
      "chromium": "f2b3a1def08459c715c8109a61650e5756f7123a",
      "dawn": "a8d1e554a9bd35b0418ba7fd6b0bc005250a7703",
      "devtools": "a3064782146fc247c488d44c1ad3496b29d55ec4",
      "pdfium": "66c6bc40966122935d37eef739deb988581214d4",
      "skia": "ee20d565acb08dece4a32e3f209cdd41119015ca",
      "v8": "80477e7fe91f0fba0567bc51c75f5a966afbd617",
      "webrtc": "8f3537ef5b85b4c7dabed2676d4b72214c69c494"
    },
    "milestone": 144,
    "platform": "iOS",
    "previous_version": "144.0.7559.53",
    "time": 1768323441355,
    "version": "144.0.7559.85"
  }
]
```

From this output, you can extract the ANGLE commit hash:

```json
"angle": "a96fca8d5ee2ca61e8de419e38cd577579281c9e"
```

Or retrieve it directly with the following one-liner:

```bash
curl -s "https://chromiumdash.appspot.com/fetch_releases?channel=Stable&platform=iOS&num=1" | jq -r '.[0].hashes.angle'
```

Then check out the commit and sync dependencies:

```bash
git fetch
git checkout a96fca8d5ee2ca61e8de419e38cd577579281c9e
gclient sync
```
---

## 3) Build the XCFramework

Customize the configuration if needed:

```bash
### CONFIG ###
IOS_DEPLOYMENT_TARGET="14.0"
OUT_DIR="out"
XC_OUT="xcframework"
HEADERS_DIR="xcframework_headers"
ANGLE_DIR="angle"
```

Then run the build script from the parent folder of the ANGLE repository:

```bash
./build_angle_xcframework.sh
```

This will generate:

```bash
angle/xcframework
├── libEGL.xcframework
└── libGLESv2.xcframework
```

Both frameworks include:

- Device and simulator slices (arm64)  
- Correct Headers/ directories  
- Umbrella headers (libEGL.h and libGLESv2.h)  
- Modules/module.modulemap ready for Xcode  

---

## License

This repository is licensed under the MIT License. See LICENSE for details.
