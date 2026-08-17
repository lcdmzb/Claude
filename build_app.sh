#!/usr/bin/env bash
#
# 把源码编译并打包成可以直接双击运行的「站立提醒.app」。
#
#   ./build_app.sh              编译 + 打包到 dist/
#   ./build_app.sh --install    编译 + 打包，并复制到 /Applications
#   ./build_app.sh --run        编译 + 打包，并立刻打开
#
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="站立提醒"
BINARY_NAME="StandUp"
BUNDLE_ID="com.standup.reminder"
VERSION="1.0.0"
BUILD_NUMBER="1"
DIST_DIR="dist"
APP_DIR="${DIST_DIR}/${APP_NAME}.app"

INSTALL=false
LAUNCH=false
for arg in "$@"; do
    case "$arg" in
        --install) INSTALL=true ;;
        --run)     LAUNCH=true ;;
        -h|--help)
            sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *) echo "未知参数：$arg" >&2; exit 1 ;;
    esac
done

# ---------------------------------------------------------------- 环境检查

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "错误：本 App 使用 SwiftUI / AppKit，只能在 macOS 上编译。" >&2
    exit 1
fi

if ! command -v swift >/dev/null 2>&1; then
    echo "错误：找不到 swift 命令。" >&2
    echo "请先安装 Xcode 命令行工具：xcode-select --install" >&2
    exit 1
fi

MACOS_MAJOR="$(sw_vers -productVersion | cut -d. -f1)"
if [[ "$MACOS_MAJOR" -lt 13 ]]; then
    echo "警告：本 App 需要 macOS 13 (Ventura) 或更高版本，当前为 $(sw_vers -productVersion)。" >&2
fi

# ---------------------------------------------------------------- 编译

echo "==> 编译（Release）"
# 优先输出 Intel + Apple Silicon 通用二进制；工具链不支持时退回本机架构
BUILD_ARGS=(-c release)
if swift build -c release --arch arm64 --arch x86_64 --show-bin-path >/dev/null 2>&1; then
    BUILD_ARGS+=(--arch arm64 --arch x86_64)
else
    echo "    当前工具链不支持通用二进制，改为编译本机架构"
fi

swift build "${BUILD_ARGS[@]}"
BIN_PATH="$(swift build "${BUILD_ARGS[@]}" --show-bin-path)/${BINARY_NAME}"

if [[ ! -f "$BIN_PATH" ]]; then
    echo "错误：编译产物不存在：$BIN_PATH" >&2
    exit 1
fi

# ---------------------------------------------------------------- 组装 .app

echo "==> 组装 ${APP_DIR}"
rm -rf "$APP_DIR"
mkdir -p "${APP_DIR}/Contents/MacOS" "${APP_DIR}/Contents/Resources"
cp "$BIN_PATH" "${APP_DIR}/Contents/MacOS/${BINARY_NAME}"
chmod +x "${APP_DIR}/Contents/MacOS/${BINARY_NAME}"

cat > "${APP_DIR}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>zh_CN</string>
    <key>CFBundleExecutable</key>
    <string>${BINARY_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${BINARY_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${BUILD_NUMBER}</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.healthcare-fitness</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsSuddenTermination</key>
    <false/>
    <key>NSHumanReadableCopyright</key>
    <string>站立提醒 · 久坐提醒与打卡</string>
</dict>
</plist>
PLIST

echo "APPL????" > "${APP_DIR}/Contents/PkgInfo"

# ---------------------------------------------------------------- 图标

ICON_SRC="Resources/AppIcon.png"
if [[ -f "$ICON_SRC" ]] && command -v iconutil >/dev/null 2>&1; then
    echo "==> 生成图标"
    ICONSET="$(mktemp -d)/AppIcon.iconset"
    mkdir -p "$ICONSET"
    for spec in "16:16x16" "32:16x16@2x" "32:32x32" "64:32x32@2x" \
                "128:128x128" "256:128x128@2x" "256:256x256" "512:256x256@2x" \
                "512:512x512" "1024:512x512@2x"; do
        px="${spec%%:*}"
        name="${spec##*:}"
        sips -z "$px" "$px" "$ICON_SRC" --out "${ICONSET}/icon_${name}.png" >/dev/null 2>&1
    done
    iconutil -c icns "$ICONSET" -o "${APP_DIR}/Contents/Resources/AppIcon.icns"
    rm -rf "$(dirname "$ICONSET")"
else
    echo "    跳过图标（缺少 ${ICON_SRC} 或 iconutil）"
fi

# ---------------------------------------------------------------- 签名

echo "==> 本地临时签名"
codesign --force --deep --sign - "$APP_DIR" 2>/dev/null \
    || echo "    签名失败，App 仍可运行（首次打开需右键 → 打开）"

# ---------------------------------------------------------------- 收尾

if $INSTALL; then
    echo "==> 安装到 /Applications"
    rm -rf "/Applications/${APP_NAME}.app"
    cp -R "$APP_DIR" "/Applications/${APP_NAME}.app"
    FINAL="/Applications/${APP_NAME}.app"
else
    FINAL="$(pwd)/${APP_DIR}"
fi

echo ""
echo "✅ 构建完成：${FINAL}"
echo "   首次打开若提示「无法验证开发者」，请右键点击 App → 打开 → 再次点「打开」。"

if $LAUNCH; then
    open "$FINAL"
fi
