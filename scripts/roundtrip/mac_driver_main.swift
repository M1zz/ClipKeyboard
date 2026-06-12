// macOS 측 드라이버 — 실제 ClipKeyboard.tap/Models.swift와 함께 컴파일된다.
// roundtrip 모드: iOS가 인코딩한 JSON을 맥 디코더로 읽고(=iCloud 복원),
//               맥 인코더로 재기록(=맥에서 편집 후 저장/재백업)하여 같은 경로에 덮어쓴다.
import Foundation

func fail(_ msg: String) -> Never {
    print("❌ MAC FAIL: \(msg)")
    exit(1)
}

let args = CommandLine.arguments
let mode = args[1]
let dir = args[2]

let dec = JSONDecoder()
let enc = JSONEncoder()

switch mode {
case "roundtrip":
    let memosURL = URL(fileURLWithPath: dir + "/memos.json")
    guard let memos = try? dec.decode([Memo].self, from: Data(contentsOf: memosURL)) else {
        fail("맥 디코더가 iOS memos.json을 읽지 못함")
    }
    guard memos.count == 3 else { fail("맥 디코드 후 메모 개수 \(memos.count) != 3") }
    guard memos[0].hint == "쿠팡 배송지 입력할 때" else {
        fail("맥 디코드에서 hint 손실: \(String(describing: memos[0].hint))")
    }
    guard memos[0].lastUsedAt != nil else { fail("맥 디코드에서 lastUsedAt 손실") }
    guard memos[1].isTemplate else { fail("맥 디코드에서 isTemplate(레거시 키) 손실") }
    guard memos[2].isCombo, memos[2].comboInterval == 3.5 else { fail("맥 디코드에서 콤보 필드 손실") }
    try enc.encode(memos).write(to: memosURL)

    let combosURL = URL(fileURLWithPath: dir + "/combos.json")
    guard let combos = try? dec.decode([Combo].self, from: Data(contentsOf: combosURL)) else {
        fail("맥 디코더가 combos.json을 읽지 못함")
    }
    try enc.encode(combos).write(to: combosURL)

    let clipURL = URL(fileURLWithPath: dir + "/clipboard.json")
    guard let clips = try? dec.decode([SmartClipboardHistory].self, from: Data(contentsOf: clipURL)) else {
        fail("맥 디코더가 clipboard.json을 읽지 못함")
    }
    try enc.encode(clips).write(to: clipURL)

    print("✅ 맥 roundtrip 완료 (디코드 → 재인코드)")

case "verify-old":
    // 1.x OldMemo 포맷 폴백이 맥에서도 동작하는지 (MemoStore.load와 동일 로직)
    let data = try Data(contentsOf: URL(fileURLWithPath: dir + "/old_memos.json"))
    if let memos = try? dec.decode([Memo].self, from: data), !memos.isEmpty, !memos[0].title.isEmpty {
        // 관용 디코더가 그대로 읽을 수도 있음 — title 보존만 확인
        guard memos[0].title == "옛날 메모", memos[0].value == "old value" else {
            fail("OldMemo 직접 디코드 결과 필드 손실")
        }
        print("✅ 맥 OldMemo 호환: 관용 디코더가 직접 수용")
    } else if let olds = try? dec.decode([OldMemo].self, from: data) {
        let migrated = olds.map { Memo(from: $0) }
        guard migrated[0].title == "옛날 메모", migrated[0].value == "old value", migrated[0].isChecked else {
            fail("OldMemo 폴백 마이그레이션 필드 손실")
        }
        print("✅ 맥 OldMemo 폴백 마이그레이션 통과")
    } else {
        fail("맥에서 OldMemo 포맷을 어떤 경로로도 읽지 못함 — 데이터 손실")
    }

default:
    fail("unknown mode \(mode)")
}
