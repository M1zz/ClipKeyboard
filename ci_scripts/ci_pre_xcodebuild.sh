#!/bin/sh
#
# Xcode Cloud - 빌드가 시작되기 직전에 도는 스크립트.
#
# 여기서 하는 일도 하나다: **빌드 번호를 손으로 올리는 일을 없앤다.**
#
# 지금까지는 `Version.xcconfig` 의 `CURRENT_PROJECT_VERSION` 을 사람이 올렸고, 그걸 잊으면
# TestFlight 업로드가 "이미 있는 빌드 번호" 로 거절됐다. Xcode Cloud 는 빌드마다 하나씩
# 늘어나는 `CI_BUILD_NUMBER` 를 주므로, 그 값을 그대로 쓰면 겹칠 일이 없다.
#
# ⚠️ **1000 을 더한다.** 클라우드의 번호는 1부터 시작하는데, 맥에서 손으로 올린 빌드도
#    1, 2, 3 을 쓴다. 그대로 두면 언젠가 정확히 겹쳐서 업로드가 거절된다.
#    1000 위쪽은 클라우드 전용 자리로 비워 둔다(손 빌드가 1000 을 넘을 일은 없다).
#
# ⚠️ 마케팅 버전(`MARKETING_VERSION`)은 **건드리지 않는다.** 4.4.7 은 사람이 정하는 값이고,
#    그것까지 자동으로 만들면 어느 버전이 나갔는지 아무도 모르게 된다.
#
# ⚠️ 이 수정은 클라우드가 클론한 **일회용 사본**에만 일어난다. 저장소로 커밋되지 않는다.
#
# 자세한 배경: docs/engineering/XCODE_CLOUD.md
#

set -e

cd "$CI_PRIMARY_REPOSITORY_PATH" || exit 1

CONFIG="Version.xcconfig"
BASE=1000

if [ -z "$CI_BUILD_NUMBER" ]; then
  echo "⚠️ [ci_pre_xcodebuild] CI_BUILD_NUMBER 가 없습니다. 빌드 번호를 그대로 둡니다"
  exit 0
fi

BUILD=$((BASE + CI_BUILD_NUMBER))
echo "▶︎ [ci_pre_xcodebuild] 빌드 번호 = $BUILD (CI_BUILD_NUMBER=$CI_BUILD_NUMBER + $BASE)"

# xcconfig 한 줄만 바꾼다 - pbxproj 는 $(CURRENT_PROJECT_VERSION) 을 참조하므로
# 이 한 곳이면 앱과 모든 익스텐션에 같은 번호가 들어간다.
sed -i '' "s/^CURRENT_PROJECT_VERSION = .*/CURRENT_PROJECT_VERSION = $BUILD/" "$CONFIG"

echo "✅ [ci_pre_xcodebuild] $(grep '^CURRENT_PROJECT_VERSION' "$CONFIG")"
echo "   $(grep '^MARKETING_VERSION' "$CONFIG")   ← 마케팅 버전은 그대로"
