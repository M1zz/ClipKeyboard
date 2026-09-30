#!/bin/sh
# 사용자 여정 표(docs/engineering/USER_JOURNEYS.md)의 시험이 전부 있는지 본다.
#
# 왜: 여정 하나를 지키던 시험이 이름이 바뀌거나 지워져도 전체 시험은 여전히 초록이다.
#     그 여정은 그날부터 아무도 안 지키는데, 아무도 모른다. 표와 시험을 묶어 두는 자리가 여기다.
#
# 표의 `시험` 칸은 `파일명/함수명` 이다. ClipKeyboardTests/파일명.swift 안에 `func 함수명(` 이 있어야 한다.
ROOT="$(git rev-parse --show-toplevel)"
DOC="$ROOT/docs/engineering/USER_JOURNEYS.md"
TESTS="$ROOT/ClipKeyboardTests"

if [ ! -f "$DOC" ]; then
  echo "❌ 여정 표가 없습니다: $DOC"
  exit 1
fi

missing=0
count=0
# 표의 마지막 칸에서 `파일/함수` 를 뽑는다.
for ref in $(grep -E '^\|' "$DOC" | grep -oE '`[A-Za-z]+Tests/[^`]+`' | tr -d '`'); do
  count=$((count + 1))
  file="${ref%%/*}"
  func="${ref#*/}"
  path="$TESTS/$file.swift"
  if [ ! -f "$path" ]; then
    echo "❌ 여정 시험 파일이 없습니다: $file.swift ($ref)"
    missing=$((missing + 1))
  elif ! grep -qF "func $func(" "$path"; then
    echo "❌ 여정 시험이 없습니다: $ref"
    missing=$((missing + 1))
  fi
done

if [ "$count" -eq 0 ]; then
  echo "❌ 여정 표에서 시험을 하나도 못 읽었습니다. 표 모양이 바뀌었는지 보세요: $DOC"
  exit 1
fi

if [ "$missing" -gt 0 ]; then
  echo ""
  echo "   여정을 지키던 시험이 사라졌습니다. 시험을 되살리거나, 표를 새 이름으로 고치세요."
  echo "   ($DOC)"
  exit 1
fi

echo "✅ 사용자 여정 ${count}개 모두 시험이 지키고 있음"
