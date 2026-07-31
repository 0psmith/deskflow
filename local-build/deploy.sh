#!/bin/bash
# deskflow 로컬 빌드를 /Applications/Deskflow.app 으로 배포한다.
#   - homebrew Qt(qtbase/qtsvg)를 번들에 담고 rpath 를 정리해 중복 Qt 적재를 막는다
#   - ad-hoc 재서명 → 매 배포마다 손쉬운 사용 권한을 다시 부여해야 한다 (cdhash 변경)
set -euo pipefail

REPO="${REPO:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
STAGE="${STAGE:-$HOME/.cache/deskflow-stage}"
QT=/opt/homebrew/opt/qt
APP=/Applications/Deskflow.app

export PATH=/opt/homebrew/bin:$PATH

if [ ! -f "$REPO/build/CMakeCache.txt" ]; then
  echo "==> configure (최초 1회)"
  # CMAKE_OSX_SYSROOT 를 반드시 넘긴다. v1.26.0 의 cmake/Libraries.cmake 가
  # "--sysroot ${CMAKE_OSX_SYSROOT}" 를 CXX_FLAGS 에 넣는데, CMake 4.x + CLT 환경에서
  # 이 변수가 비면 --sysroot 가 다음 플래그를 삼켜 링크가 깨진다
  # (ld: library 'c++' not found / library 'pthread' not found).
  cmake -S "$REPO" -B "$REPO/build" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_OSX_SYSROOT="$(xcrun --show-sdk-path)" \
    -DCMAKE_PREFIX_PATH="$QT" \
    -DOPENSSL_ROOT_DIR=/opt/homebrew/opt/openssl@3 \
    -DBUILD_INSTALLER=OFF \
    -DSKIP_BUILD_TESTS=ON
fi

echo "==> 빌드"
cmake --build "$REPO/build" -j "$(sysctl -n hw.ncpu)"

# 빌드 중 lupdate 가 translations/*.ts 를 다시 써서 작업 트리를 더럽힌다. 생성물이므로 되돌린다.
if ! git -C "$REPO" diff --quiet -- translations/ 2>/dev/null; then
  git -C "$REPO" checkout -- translations/
  echo "    (빌드가 건드린 translations/ 되돌림)"
fi

echo "==> 스테이징"
rm -rf "$STAGE" && mkdir -p "$STAGE"
cp -R "$REPO/build/bin/Deskflow.app" "$STAGE/"
C="$STAGE/Deskflow.app/Contents"

echo "==> Qt 번들링"
"$QT/bin/macdeployqt" "$STAGE/Deskflow.app" \
  -executable="$C/MacOS/deskflow-core" 2>/dev/null || true

# macdeployqt 이 homebrew 에서 분리된 qtsvg 를 못 찾으므로 직접 채운다 (svg 아이콘 필수)
cp -R /opt/homebrew/opt/qtsvg/lib/QtSvg.framework "$C/Frameworks/"
cp /opt/homebrew/opt/qtsvg/share/qt/plugins/imageformats/libqsvg.dylib "$C/PlugIns/imageformats/"

# 의존성이 깨진 채 배포되는 불필요 플러그인 제거
rm -f "$C/PlugIns/imageformats/libqpdf.dylib"
rm -rf "$C/PlugIns/platforminputcontexts"

echo "==> install name / rpath 정리"
S="$C/Frameworks/QtSvg.framework/Versions/A/QtSvg"
chmod u+w "$S"
install_name_tool -id @executable_path/../Frameworks/QtSvg.framework/Versions/A/QtSvg "$S" 2>/dev/null
for m in QtGui QtCore; do
  install_name_tool -change "/opt/homebrew/opt/qtbase/lib/$m.framework/Versions/A/$m" \
    "@loader_path/../../../$m.framework/Versions/A/$m" "$S" 2>/dev/null
  install_name_tool -change "/opt/homebrew/opt/qtbase/lib/$m.framework/Versions/A/$m" \
    "@loader_path/../../Frameworks/$m.framework/Versions/A/$m" \
    "$C/PlugIns/imageformats/libqsvg.dylib" 2>/dev/null
done
for p in "$C/PlugIns/imageformats/libqsvg.dylib" "$C/PlugIns/iconengines/libqsvgicon.dylib"; do
  install_name_tool -add_rpath @loader_path/../../Frameworks "$p" 2>/dev/null || true
done

# GUI 실행파일이 homebrew Qt 를 또 적재하지 않도록 해당 rpath 를 제거한다
install_name_tool -delete_rpath "$QT/lib" "$C/MacOS/Deskflow" 2>/dev/null || true
install_name_tool -add_rpath @loader_path/../Frameworks "$C/MacOS/Deskflow" 2>/dev/null || true
for f in "$C"/Frameworks/*.framework; do
  n=$(basename "$f" .framework)
  install_name_tool -add_rpath @loader_path/../../.. "$f/Versions/A/$n" 2>/dev/null || true
done

echo "==> 재서명"
# 고정 인증서가 있으면 그걸로 서명한다. ad-hoc(-) 은 빌드마다 cdhash 가 바뀌어
# 손쉬운 사용·입력 모니터링 권한을 매번 다시 켜야 하지만, 인증서 서명은 신원이
# 유지되므로 권한이 재빌드 후에도 살아남는다. (~/deskflow-cert-setup.sh 로 생성)
IDENTITY="Deskflow Local Build"
if security find-identity -v -p codesigning | grep -q "$IDENTITY"; then
  echo "    인증서 서명: $IDENTITY"
  # --options runtime 은 쓰지 않는다. hardened runtime 은 library validation 을 강제해서
  # 같은 Team ID 로 서명되지 않은 번들 Qt 프레임워크 적재를 막는다 (자체 서명엔 Team ID 없음).
  codesign --force --deep --sign "$IDENTITY" "$STAGE/Deskflow.app"
  SIGNED_WITH_CERT=1
else
  echo "    ad-hoc 서명 (인증서 없음 — ~/deskflow-cert-setup.sh 실행 시 권한 재부여가 사라집니다)"
  codesign --force --deep --sign - "$STAGE/Deskflow.app"
  SIGNED_WITH_CERT=0
fi
codesign --verify --deep --strict "$STAGE/Deskflow.app"

echo "==> 실행 중인 앱 종료"
osascript -e 'tell application "Deskflow" to quit' 2>/dev/null || true
for _ in $(seq 1 10); do pgrep -f "Deskflow.app" >/dev/null || break; sleep 1; done
if pgrep -f "Deskflow.app" >/dev/null; then
  pkill -9 -f "Deskflow.app" || true
  sleep 1
fi
# 강제 종료 시 남는 single-instance guard(1바이트·미연결 SHM)를 정리한다
ipcs -mbo 2>/dev/null | awk '$1=="m" && $6==0 && $7==1 {print $2}' | while read -r id; do
  ipcrm -m "$id" 2>/dev/null && echo "    stale SHM $id 제거"
done

echo "==> 교체"
rm -rf "$APP"
cp -R "$STAGE/Deskflow.app" /Applications/
xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true

if [ "$SIGNED_WITH_CERT" = "1" ]; then
  echo "==> 완료. 고정 인증서로 서명했으므로 권한은 유지됩니다."
  echo "    (인증서로 처음 바꾼 직후 한 번만 다시 켜야 할 수 있습니다)"
else
  echo "==> 완료. ad-hoc 서명이므로 권한을 다시 켜야 합니다:"
  echo "    시스템 설정 → 개인정보 보호 및 보안 → 손쉬운 사용 / 입력 모니터링 → Deskflow"
fi
