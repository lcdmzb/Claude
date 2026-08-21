#!/usr/bin/env bash
#
# 从「已经装好的 App」直接打包成 .dmg 安装包。
#
# 与 build_app.sh --dmg 的区别：这个脚本不编译、不联网，
# 只是把现成的 App 装进磁盘映像，几秒钟就能跑完。
#
#   ./make_dmg.sh              打包 /Applications 里的 App，输出到桌面
#   ./make_dmg.sh <App路径>    指定要打包的 .app
#
set -euo pipefail

APP_NAME="站立提醒"
VERSION="1.0.0"
APP_PATH="${1:-/Applications/${APP_NAME}.app}"
OUTPUT="${HOME}/Desktop/StandUp-${VERSION}.dmg"

if [[ ! -d "$APP_PATH" ]]; then
    echo "错误：找不到 App：${APP_PATH}" >&2
    echo "请先运行 ./build_app.sh --install 把 App 装进「应用程序」文件夹。" >&2
    exit 1
fi

echo "==> 打包 ${APP_PATH}"

# 装配临时目录：App + 指向「应用程序」的软链接，
# 用户打开 dmg 后把左边图标拖到右边即可完成安装
STAGE="$(mktemp -d)/payload"
mkdir -p "$STAGE"
cp -R "$APP_PATH" "${STAGE}/${APP_NAME}.app"
ln -s /Applications "${STAGE}/应用程序"

rm -f "$OUTPUT"
hdiutil create \
    -volname "${APP_NAME}" \
    -srcfolder "$STAGE" \
    -fs HFS+ \
    -format UDZO \
    -ov \
    "$OUTPUT" >/dev/null

rm -rf "$(dirname "$STAGE")"

echo ""
echo "📦 安装包已生成：${OUTPUT}"
echo "   双击它，把图标拖进「应用程序」即可安装。可以备份或拷给别人。"
open -R "$OUTPUT" 2>/dev/null || true
