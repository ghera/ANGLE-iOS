#!/usr/bin/env bash
set -euo pipefail

### CONFIG ###
IOS_DEPLOYMENT_TARGET="14.0"
OUT_DIR="out"
XC_OUT="xcframework"
HEADERS_DIR="xcframework_headers"
ANGLE_DIR="angle"

### CLEAN ###
cd "${ANGLE_DIR}"

rm -rf "${OUT_DIR}" \
       "${XC_OUT}" \
       "${HEADERS_DIR}"

mkdir -p "${XC_OUT}"

### COMMON GN ARGS ###
COMMON_ARGS='
  target_os="ios"
  target_cpu="arm64"
  ios_deployment_target="'"${IOS_DEPLOYMENT_TARGET}"'"
  ios_enable_code_signing=false
  is_debug=false
  is_component_build=false
'

### iOS DEVICE ###
echo "▶ Building iOS device (arm64)…"
gn gen "${OUT_DIR}/ios-arm64" --args="
${COMMON_ARGS}
target_environment=\"device\"
"

ninja -C "${OUT_DIR}/ios-arm64" libEGL libGLESv2

### iOS SIMULATOR (Apple Silicon) ###
echo "▶ Building iOS simulator (arm64)…"
gn gen "${OUT_DIR}/ios-sim-arm64" --args="
${COMMON_ARGS}
target_environment=\"simulator\"
"

ninja -C "${OUT_DIR}/ios-sim-arm64" libEGL libGLESv2

### HEADERS ###
echo "▶ Collecting headers…"
mkdir -p "${HEADERS_DIR}"

cp -R include/angle_gl.h \
      include/EGL \
      include/GLES \
      include/GLES2 \
      include/GLES3 \
      include/KHR \
      "${HEADERS_DIR}/"

### XCFRAMEWORKS ###
find "${OUT_DIR}" -type d \( -name "libEGL.framework" -o -name "libGLESv2.framework" \) | while read -r FRAMEWORK_DIR; do
  FRAMEWORK_MODULE=$(basename "$FRAMEWORK_DIR" .framework)
  echo "▶ Updating $FRAMEWORK_MODULE (${FRAMEWORK_DIR})"

  # create Headers and Modules if missing
  mkdir -p "${FRAMEWORK_DIR}/Headers" "${FRAMEWORK_DIR}/Modules"

  # copy headers
  if [ "$FRAMEWORK_MODULE" = "libGLESv2" ]; then
    HEADER_ITEMS="angle_gl.h GLES GLES2 GLES3 KHR libGLESv2.h"
  elif [ "$FRAMEWORK_MODULE" = "libEGL" ]; then
    HEADER_ITEMS="EGL KHR libEGL.h"
  else
    continue
  fi

  for ITEM in $HEADER_ITEMS; do
    if [ -d "include/$ITEM" ]; then
      cp -R "include/$ITEM" "${FRAMEWORK_DIR}/Headers/"
    elif [ -f "include/$ITEM" ]; then
      cp "include/$ITEM" "${FRAMEWORK_DIR}/Headers/"
    fi
  done

  # remove unnecessary files in headers folders
  find "${FRAMEWORK_DIR}/Headers" \( -name ".clang-format" -o -iname "readme.md" \) -delete

  # create module map
  cat > "${FRAMEWORK_DIR}/Modules/module.modulemap" <<EOM
framework module ${FRAMEWORK_MODULE} {
  umbrella header "${FRAMEWORK_MODULE}.h"
  export *
  module * { export * }
}
EOM

  # create umbrella headers
  if [ "$FRAMEWORK_MODULE" = "libGLESv2" ]; then
    cat > "${FRAMEWORK_DIR}/Headers/${FRAMEWORK_MODULE}.h" <<EOM
#include <libGLESv2/angle_gl.h>
EOM
    # remove unnecessary header
    rm -rf "${FRAMEWORK_DIR}/Headers/GLES/egl.h"
    # replace include paths
    find "${FRAMEWORK_DIR}/Headers" -type f -name "*.h" -exec sed -i '' 's|#include "gl2ext_angle.h"|#include <libGLESv2/GLES2/gl2ext_angle.h>|g' {} +
    find "${FRAMEWORK_DIR}/Headers" -type f -name "*.h" -exec sed -i '' 's|#include <KHR/|#include <libGLESv2/KHR/|g' {} +
    find "${FRAMEWORK_DIR}/Headers" -type f -name "*.h" -exec sed -i '' 's|#include <GLES/|#include <libGLESv2/GLES/|g' {} +
    find "${FRAMEWORK_DIR}/Headers" -type f -name "*.h" -exec sed -i '' 's|#include <GLES2/|#include <libGLESv2/GLES2/|g' {} +
    find "${FRAMEWORK_DIR}/Headers" -type f -name "*.h" -exec sed -i '' 's|#include <GLES3/|#include <libGLESv2/GLES3/|g' {} +
    find "${FRAMEWORK_DIR}/Headers" -type f -name "*.h" -exec sed -i '' -E 's|#include "(GLES[0-3]?/[^"]+)"|#include <libGLESv2/\1>|g' {} +
  elif [ "$FRAMEWORK_MODULE" = "libEGL" ]; then
    cat > "${FRAMEWORK_DIR}/Headers/${FRAMEWORK_MODULE}.h" <<EOM
#include <libEGL/EGL/egl.h>
#include <libEGL/EGL/eglext.h>
EOM
    # replace include paths
    find "${FRAMEWORK_DIR}/Headers" -type f -name "*.h" -exec sed -i '' 's|#include <KHR/|#include <libEGL/KHR/|g' {} +
    find "${FRAMEWORK_DIR}/Headers" -type f -name "*.h" -exec sed -i '' 's|#include <EGL/|#include <libEGL/EGL/|g' {} +
    find "${FRAMEWORK_DIR}/Headers" -type f -name "*.h" -exec sed -i '' 's|#include "eglext_angle.h"|#include <libEGL/EGL/eglext_angle.h>|g' {} +
  fi

  # populate mandatory Info.plist properties
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString 1.0.0" "$FRAMEWORK_DIR/Info.plist" 2>/dev/null || \
  /usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string 1.0.0" "$FRAMEWORK_DIR/Info.plist"
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion 1" "$FRAMEWORK_DIR/Info.plist" 2>/dev/null || \
  /usr/libexec/PlistBuddy -c "Add :CFBundleVersion string 1" "$FRAMEWORK_DIR/Info.plist"
done

echo "▶ Creating libEGL.xcframework…"
xcodebuild -create-xcframework \
  -framework "${OUT_DIR}/ios-arm64/libEGL.framework" \
  -framework "${OUT_DIR}/ios-sim-arm64/libEGL.framework" \
  -output "${XC_OUT}/libEGL.xcframework"

echo "▶ Creating libGLESv2.xcframework…"
xcodebuild -create-xcframework \
  -framework "${OUT_DIR}/ios-arm64/libGLESv2.framework" \
  -framework "${OUT_DIR}/ios-sim-arm64/libGLESv2.framework" \
  -output "${XC_OUT}/libGLESv2.xcframework"

### DONE ###
echo "✅ XCFrameworks generated in ${ANGLE_DIR}/${XC_OUT}"
