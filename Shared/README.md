# Shared 코드

두 타겟(앱·키보드 익스텐션)이 **함께 보는** 파일만 여기 둔다.

```
Shared/
└── QuickShortcutSave.swift    # 단축어 저장 진입점(앱·익스텐션 공용)
```

## ⚠️ 여기에 모델을 두지 않는다

한동안 `Models/SharedModels.swift` 에 `Memo`·`Combo`·`ClipboardItemType` 이
한 벌 더 적혀 있었다. **프로젝트에 들어 있지 않아 컴파일되지 않는 사본**이었는데,
파일이 있다는 이유로 진짜 모델인 줄 알고 고치면 아무 일도 일어나지 않는다.
`Models/DefaultTemplates.swift` 도 아무도 부르지 않은 채 남아 있었다. 둘 다 지웠다.

모델의 자리는 하나다: `ClipKeyboard/Model/Memo.swift`.
익스텐션은 타겟 멤버십으로 같은 파일을 본다. 사본을 만들지 말 것.

## macOS

맥 앱(ClipKeyboard.tap)은 **별도 저장소**로 갈라졌다
(`~/Documents/workspace/Auto/탭클립키보드`). 그쪽 `Shared/` 는 이 폴더와
다른 묶음이고, `MemoSyncEngine.swift` 처럼 **두 저장소에 같은 내용으로 있는 파일**이
있다. 그런 파일을 고칠 때는 양쪽을 함께 고칠 것 - 한쪽만 고치면 두 앱이
다른 규칙으로 돈다.
