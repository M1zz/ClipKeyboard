# 앞으로 만들 것 (로드맵)

사용자는 설정 ▸ 앞으로 만들 기능에서 "지금 만들고 있는 것 · 다음에 만들 것 · 최근에 나온 것"을 본다.
화면은 LeeoKit 의 `LeeoRoadmapView` 이고, **원본은 `ClipKeyboard/Service/ClipKeyboardRoadmap.swift` 한 곳**이다.

## 개발하면서 지키는 것

1. **"이건 다음에" 가 생기면 그 자리에서 로드맵에 한 줄을 더한다.** 코드에 `// TODO` 만 남기지 않는다.
   사용자가 기다릴 만한 것이면 로드맵, 개발 안쪽 일(리팩터링 · 시험 · 빌드)이면 `.sprintcommander/tasks.json`.
2. 상태를 옮긴다.
   - 새로 생김 → `.planned`
   - 손대기 시작 → `.building`
   - 내보낸 버전에 들어감 → `.shipped("5.2.0")` (화면에는 최근 5개만 보인다)
3. `id` 는 한 번 정하면 바꾸지 않는다. 문구는 바꿔도 된다.
4. 문구는 사용자 말로 쓴다. 내부 이름 · 기술 용어를 쓰지 않는다(릴리즈 노트 규칙과 같다).
5. 새 문구는 다른 문구처럼 번역한다: `python3 scripts/i18n.py sync` → 사람 손 언어(en · zh-Hans) → `extract` · `translate` · `build`.
6. 배포 전에 `.building` 인 것 중 이번 버전에 들어간 것을 `.shipped` 로 옮긴다.

## 지키는 장치

- LeeoKit 사전 점검: 같은 `id` 두 번(`roadmap.duplicateID`), 빈 이름(`roadmap.emptyTitle`)
- 시험: `TipAskAndRoadmapTests/roadmapIsSound`
- "이런 기능이 있으면 좋겠어요" 는 기능 제안으로 시작하는 피드백 창을 연다. 들어온 제안 중 할 것은 여기로 옮긴다.
