#!/bin/bash
# iOS ↔ macOS 메모 저장체계 round-trip 무결성 테스트
#
# iCloud 백업이 저장하는 포맷이 정확히 JSONEncoder().encode([Memo]) 이므로,
# 실제 모델 소스를 그대로 컴파일해 아래 경로를 검증한다:
#   1. iOS 인코딩(=iCloud 백업) → 맥 디코딩(=맥에서 복원)
#   2. 맥 재인코딩(=맥에서 편집/재백업) → iOS 디코딩(=아이폰에서 복원)
#   3. 모든 필드(hint, 콤보, 템플릿, 이미지, 보안 등) + 구버전 레거시 키 보존 확인
#   4. 1.x OldMemo 포맷 폴백 동작 확인
#
# 사용법: ./scripts/roundtrip/run_roundtrip_test.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
WORK_DIR="$(mktemp -d /tmp/ck_roundtrip.XXXXXX)"
trap 'rm -rf "$WORK_DIR"' EXIT

mkdir -p "$WORK_DIR/ios" "$WORK_DIR/mac" "$WORK_DIR/data"
cp "$REPO_ROOT/scripts/roundtrip/ios_driver_main.swift" "$WORK_DIR/ios/main.swift"
cp "$REPO_ROOT/scripts/roundtrip/mac_driver_main.swift" "$WORK_DIR/mac/main.swift"

echo "🔧 iOS 모델(Memo.swift) 드라이버 컴파일..."
swiftc -o "$WORK_DIR/ios_driver" "$REPO_ROOT/ClipKeyboard/Model/Memo.swift" "$WORK_DIR/ios/main.swift"

echo "🔧 macOS 모델(Models.swift) 드라이버 컴파일..."
swiftc -o "$WORK_DIR/mac_driver" "$REPO_ROOT/ClipKeyboard.tap/Models.swift" "$WORK_DIR/mac/main.swift"

"$WORK_DIR/ios_driver" encode "$WORK_DIR/data"
"$WORK_DIR/mac_driver" roundtrip "$WORK_DIR/data"
"$WORK_DIR/ios_driver" verify "$WORK_DIR/data"
"$WORK_DIR/ios_driver" verify-old "$WORK_DIR/data"
"$WORK_DIR/mac_driver" verify-old "$WORK_DIR/data"

echo "🎉 iOS ↔ macOS round-trip 무결성 테스트 전체 통과"
