# 카테고리를 단축어와 같은 방식으로 저장하고 동기화하기 (설계안)

> 2026-09-28 작성. 같은 날 0~3단계를 구현했다. 아래 "구현하며 바꾼 것"이 이 문서의 나머지보다 앞선다.
> iOS 와 맥(`ClipKeyboardMac`)이 함께 바뀌는 작업이다.

## 구현하며 바꾼 것 (2026-09-28)

1. **App Group 열쇠가 계속 원본이다.** 설계에서는 `categories.data` 를 원본으로 두고 옛 열쇠를
   비추려 했다. 조사해 보니 열쇠에 직접 쓰는 곳이 `CategoryStore`, `CategoryIconSettings`,
   `ClipKeyboardListViewModel`, `CategorySnapshotStore`, `UserStageSimulator`, 맥 `MacCategoryPicker`
   등 여럿이었다. 하나만 놓쳐도 비추기가 사용자의 설정을 되돌린다.
   → 단축어가 `memos.data` 를 원본으로 두고 섀도와 비교하듯, **열쇠를 읽어 항목을 갱신**하고
   (`CategorySyncCore.refresh`), 받은 항목은 **열쇠에 되쓴다**(`CategorySyncCore.project`).
   어디서 열쇠를 바꾸든 다음 동기화에 잡힌다. 1단계의 가장 큰 위험이 사라졌다.
2. **병합은 일반화하지 않고 카테고리 전용(`CategorySyncCore.merge`)으로 뒀다.** 시험이 두터운
   `MemoSyncCore` 를 건드리지 않으려는 것이다. 규칙은 같다: 항목마다 최신 우선, 로컬이 이기면 다시 올림,
   삭제는 항목 안의 `deletedAt`.
3. **자격.** 새 항목은 "쓰는 카테고리(비샘플 단축어가 있음)이거나 사람이 보이게 둔 카테고리"만 만든다.
   페르소나가 숨긴 채 심은 빈 카테고리는 언어마다 이름이 달라 싣지 않는다(`syncable` 과 같은 이유).
4. **처음 옮기기의 시각.** 이름 기반 id 에 더해 수정 시각을 1970년으로 준다. 이미 있던 상태를 옮기는 것이지
   새 편집이 아니라서, 다른 기기의 기록(지운 것 포함)이 항상 이긴다.
5. **되쓰기의 옛 이름.** 이름 변경을 받으면 옛 이름은 어느 항목에도 없어 "모르는 이름"으로 남는다.
   남기면 다음 갱신이 새 카테고리로 되살린다. 받기 전 항목 이름(`formerNames`)도 아는 이름으로 친다.
   (시험이 잡은 버그)
6. **모든 데이터 삭제**는 항목과 섀도도 지운다(`DataWipeService`). 남기면 "목록에서 사라짐 = 지움"으로 읽혀
   이 기기만 지운 카테고리가 모든 기기에서 지워진다.

## 하위 호환 약속 (2026-09-28)

한 계정에 옛 버전과 새 버전이 섞여 돈다. 옛 버전은 고칠 수 없으니 **새 쪽이 맞춘다.**
`ClipKeyboardTests/SyncBackwardCompatibilityTests` 가 아래를 지킨다.

**옛 버전이 동기화 구역의 레코드를 읽는 방식**

| 누가 | 무엇을 | 걸리는 조건 |
|---|---|---|
| 엔진 (iOS 4.3.3 부터 전부, 맥 공유) | 단축어로 읽기 | 이름이 `category-settings` 가 아니고 **UUID** 일 때만 |
| 맥 5.1.4 "다시 받기" | 받을 단축어 수 | 종류 `Memo`, `deletedAt` 없음. **이름을 안 본다** |
| 맥 5.1.4 "지운 것 반영" | 지울 단축어 | 종류 `Memo`, `deletedAt` 있음, 이름이 UUID |
| 맥 5.1.4 진단 | 단축어 수 / 카테고리 설정 | 종류 `Memo` 전부 / 종류 `CategorySettings` 있음 |

**그래서 새 레코드는**
- 카테고리 항목 `categoryitem.<UUID>`, 표식 `sync-epoch.v2`: 종류 **`CategorySettings`**. `Memo` 로 두면 맥 5.1.4 의
  "다시 받기"가 단축어로 세어, iCloud 에 단축어가 없어도 맥을 비울 수 있다.
- 필드는 `CategorySettings` 가 처음부터 쓰던 **`payload`, `updatedAt` 둘만.** Production 스키마에 없는 필드는
  대시보드 배포 전까지 저장이 거절된다. 삭제 표시는 `payload` 안, 수정 시각은 `updatedAt`.
- 이름은 UUID 도 `category-settings` 도 아니다. 모든 옛 엔진이 건너뛴다.
- 충돌 처리는 `lastEdited` 와 `updatedAt` 을 모두 본다(`MemoSyncEngine.editedDate`). 한쪽만 보면 다른 종류는
  늘 "아주 옛날"이 되어 서버의 새 버전을 덮어쓴다.
- 개발 빌드가 한때 `Memo` 종류로 만든 `sync-epoch` 는 새 표식을 심을 때 지운다(종류는 바꿀 수 없다).
- 개발 빌드가 한때 `Memo` 종류로 올린 카테고리 항목 `category.<UUID>` 는 받으면 항목으로 읽기만 하고,
  새 빌드가 처음 뜰 때 한 번 지운 뒤 새 이름으로 다시 올린다(`cleanUpLegacyCategoryRecords`).

**옛 `category-settings` 레코드**
- 새 버전도 계속 올린다(목록은 합쳐서). 옛 버전 기기는 이것으로 카테고리를 본다.
- 새 버전은 받을 때 목록을 무시하고, 화면 구성과 **처음 보는 이름**만 받는다. 옛 버전이 더하기만 하며 올리므로
  목록을 받으면 지운 카테고리가 되살아난다.
- 섞여 도는 동안의 한계: 옛 버전에서 지우거나 이름을 바꾼 것, 숨긴 것은 새 버전으로 가지 않는다.
  새 버전에서 지운 것은 옛 버전에 남아 보인다. 업데이트하면 풀린다.

**저장 형식**
- `CategorySnapshot.items`(백업)는 선택 필드다. 없으면 쓰지 않고, 옛 버전은 모르는 키를 무시한다.
- `CategoryItem` 은 관용 디코더다. id·이름만 있으면 읽고, 모르는 필드는 무시한다.
  **필드를 더할 땐 선택형으로만.** 이 버전은 모르는 필드를 다시 올릴 때 빠뜨린다.
- 단축어 `payload`(Memo JSON)는 바꾸지 않았다.

**같은 기기에서 버전을 내렸다 올릴 때**
- 원본은 계속 App Group 열쇠라서 옛 버전도 카테고리를 그대로 쓴다. 새 항목 열쇠(`category.sync.*`)는 옛 버전이 모른다.
- 다시 올리면 `refresh` 가 열쇠와 항목을 맞춘다. 옛 버전에서 바꾼 이름은 "지우고 새로 만들기"로 읽힌다.

코드: `CategorySnapshot.swift` 의 `CategoryItem`, `CategorySyncCore`, `CategoryItemStore`
(iOS·맥 공유 파일), `MemoSyncEngine.swift` 의 "카테고리 항목 동기화" 절, `CategoryStore.rename`.
시험: `CategorySyncCoreTests`, `CategoryStoreTests.testRename_MovesIconColorAndHidden`.

## 요약

단축어는 하나에 레코드 하나이고, 각자 id, 마지막 수정 시각, 삭제 기록(툼스톤)을 가진다.
카테고리는 설정값 묶음 하나(`category-settings` 레코드)에 이름 목록째 들어가고, 이름이 곧 정체다.
그래서 **삭제와 이름 변경이 기기 사이에 전달될 수 없다.**

카테고리도 단축어처럼 **하나에 레코드 하나, 고유 id, 수정 시각, 툼스톤**으로 바꾼다.
병합은 단축어가 쓰는 규칙(`MemoSyncCore.merge`, 최신 우선 + 툼스톤)을 그대로 쓴다.
단축어의 `category` 필드는 당분간 이름 문자열로 둔다. 옛 버전 앱이 이름으로 읽기 때문이다.

## 지금 구조와 문제

### 저장

| 무엇 | 어디 | 열쇠 |
|---|---|---|
| 사용자 카테고리 목록(순서 포함) | App Group UserDefaults | `userDefinedCategories_v1` |
| 아이콘 | App Group UserDefaults | `userCategoryIcons_v1` `[이름: 심볼]` |
| 색 | App Group UserDefaults | `userCategoryColors_v1` `[이름: hex]` |
| 숨긴 탭 | App Group UserDefaults | `hiddenCategoryTabs_v1` `[이름]` |
| 켠 기본 제공 카테고리 | App Group UserDefaults | `enabledBuiltInCategories_v1` |
| 카테고리 기능 켬 | App Group UserDefaults | `category.feature.enabled.v1` |
| 단축어의 소속 | `memos.data` 의 각 `Memo` | `category: String` (이름) |

모두 이름으로 이어져 있다. 카테고리 자체를 가리키는 id 가 없다.

### 동기화

- `MemoSyncEngine` 이 위 설정을 `CategorySnapshot` 하나로 묶어 `category-settings` 레코드 **한 장**으로 올린다.
- 올릴 때 서버 목록과 합친다(`CategorySnapshotStore.union`). 목록이 빈약한 기기가 공용 레코드를
  덮어써 맥 탭이 12개에서 2개로 줄었던 사고 뒤에 들어간 방어다.
- 받을 때 없는 것만 더한다(`CategorySnapshotStore.apply(.sync)`). 숨김과 기본 제공 카테고리만 그대로 비춘다.
- 결과: 목록이 **더하기만 하는 집합**이 됐다. 지운 카테고리는 다른 기기에서 다시 올라오고,
  이름을 바꾸면 옛 이름이 다른 기기에 남는다.

### 이름이 곧 정체라서 생기는 일

- **iOS 이름 바꾸기 버그 (지금 사용자에게 보인다).** `CategoryStore.rename` 은 목록의 이름만 바꾼다.
  그 카테고리의 단축어 `category`, 아이콘, 색, 숨김은 옛 이름에 남는다. 단축어는 기본 탭으로
  밀려나고(`CategoryBucketRule.belongsToBasicBucket`), 아이콘과 색이 사라진다.
- 두 기기에서 같은 이름을 따로 만들면 같은 것으로 합쳐지지만, 이름을 바꾸면 다른 카테고리가 된다.
- 삭제는 "목록에서 빠짐"으로만 표현돼서, 받는 쪽은 "지운 것"과 "그 기기가 아직 모르는 것"을 가를 수 없다.

## 목표와 비목표

**목표**
1. 카테고리 추가, 이름 변경, 삭제, 순서, 아이콘, 색, 숨김이 모든 기기에 전달된다.
2. 동시에 고치면 카테고리마다 마지막 수정이 이긴다(단축어와 같은 규칙).
3. 옛 버전 앱과 한동안 함께 돌아도 데이터가 사라지지 않는다.
4. "다른 기기를 이 기기에 맞추기"가 카테고리까지 맞춘다.

**비목표 (이번에 안 하는 것)**
- 단축어가 카테고리를 id 로 가리키게 바꾸기. 옛 버전과 키보드 확장까지 한꺼번에 바뀌어야 해서 다음 단계로 미룬다.
- 기본 제공 카테고리(템플릿, 이미지 등)와 즐겨찾기 탭 숨김을 카테고리 레코드로 옮기기.
  이것들은 목록이 아니라 "화면 구성" 설정이라 지금처럼 한 덩어리로 비추는 게 맞다.

## 새 데이터 모델

```swift
/// 사용자 카테고리 하나. 단축어의 `Memo` 와 같은 자리.
struct CategoryItem: Codable, Identifiable, Equatable {
    let id: UUID              // 만들 때 정하고 바뀌지 않는다. 이름을 바꿔도 그대로.
    var name: String          // 단축어의 `category` 가 가리키는 값
    var order: Double         // 탭 순서. 사이에 끼울 수 있게 실수(두 값의 중간)
    var icon: String?         // SF Symbol, 없으면 기본 팔레트
    var colorHex: String?
    var isHidden: Bool
    var lastEdited: Date      // 이 카테고리의 마지막 수정. 병합 기준
}
```

- 로컬 저장: App Group 의 `categories.data` 파일(JSON 배열). `memos.data` 와 같은 방식이다.
- 삭제: 단축어처럼 툼스톤 `[id: 삭제 시각]` 을 따로 둔다(`sync.categoryTombstones`).
- 화면 구성 설정(기본 제공 카테고리 켬, 즐겨찾기 탭 숨김, 기능 켬)은 `CategoryLayout` 한 덩어리로 남긴다.

### 옛 열쇠는 "비추기"로 계속 쓴다

`userDefinedCategories_v1` 등 여섯 열쇠를 읽는 곳이 iOS 앱, 키보드 확장, 맥에 서른 곳이 넘는다.
한 번에 바꾸지 않는다. `CategoryItem` 목록이 바뀔 때마다 옛 열쇠를 **다시 계산해서 써 둔다**.

- 목록 = 숨기지 않은 것과 숨긴 것 모두, `order` 순
- 아이콘, 색 = `[name: 값]`
- 숨김 = `isHidden` 인 이름 + 즐겨찾기 숨김 표시

읽는 쪽은 그대로 두고, **쓰는 쪽만** `CategoryStore` 를 거치게 한다. 옛 열쇠에 직접 쓰는 곳
(`CategoryIconSettings`, `CategoryStore.setVisible` 등)을 전부 `CategoryStore` 로 모으는 것이 1단계다.

## 동기화

### 레코드

- 카테고리 하나에 레코드 하나. 이름 `categoryitem.<UUID>`, 종류는 **`CategorySettings`**, 필드는 `payload` 와 `updatedAt` 뿐.
  이유는 위 "하위 호환 약속"에 있다(처음 설계는 `Memo` 종류였으나 맥 5.1.4 의 셈 때문에 바꿨다).
- 화면 구성(`CategoryLayout`)은 지금의 `category-settings` 레코드에 계속 싣는다(아래 호환 참고).

### 병합

`MemoSyncCore.merge` 를 `Memo` 전용에서 **"id, 수정 시각, 지문이 있는 것"** 일반으로 바꾼다.

```swift
protocol SyncItem: Codable { var id: UUID { get }; var lastEdited: Date { get } }
extension Memo: SyncItem {}
extension CategoryItem: SyncItem {}
```

그러면 오늘 고친 두 가지(이긴 쪽 다시 올리기, 이긴 삭제 다시 알리기)가 카테고리에도 그대로 적용된다.
섀도, 툼스톤, 레코드 메타도 같은 틀로 카테고리용을 하나씩 둔다.

### 이름 겹침

두 기기가 끊긴 채로 같은 이름을 따로 만들거나, 한쪽이 다른 카테고리를 그 이름으로 바꾸면
**이름이 같은 살아 있는 카테고리가 둘** 생긴다. 병합 뒤에 한 번 정리한다.

- 먼저 만들어진 쪽(id 가 아니라 기록된 생성 시각, 같으면 id 사전순)을 남기고 다른 쪽은 툼스톤.
- 단축어는 이름으로 가리키므로 옮길 것이 없다.
- 아이콘, 색은 남는 쪽에 없으면 사라지는 쪽 것을 넘겨받는다.
- 규칙이 결정적이어야 두 기기가 같은 쪽을 남긴다. 생성 시각을 `CategoryItem` 에 하나 더 둔다(`createdAt`).

### 이름 바꾸기와 삭제에서 단축어

- **이름 바꾸기:** 바꾼 기기가 카테고리 레코드와 **그 이름을 쓰던 단축어의 `category`** 를 함께 고친다
  (단축어는 `lastEdited` 를 올려 평소처럼 동기화). 받는 기기는 두 가지가 따로 도착해도 결국 같아진다.
  잠깐 사이 단축어가 기본 탭에 보일 수 있다.
- **삭제:** 지금처럼 단축어는 지우지 않는다. 이름을 잃은 단축어는 기본 탭이 받는다(지금 동작 그대로).

## 옛 버전과 함께 도는 동안

- **새 버전은 `category-settings` 레코드를 계속 쓴다.** `CategoryItem` 목록에서 만든 스냅샷을 올려,
  아직 업데이트하지 않은 기기도 카테고리를 본다. 옛 버전은 지운 것을 다시 더해 올린다.
- 그래도 **새 버전은 받은 `category-settings` 의 목록을 무시한다.** 화면 구성(기본 제공, 기능 켬)만 읽는다.
  그래서 새 버전끼리는 삭제와 이름 변경이 지켜지고, 옛 버전에서만 지운 것이 남아 보인다.
  옛 버전이 업데이트되면 사라진다.
- 옛 버전 기기가 새로 만든 카테고리: 새 버전은 `category-settings` 목록에서
  **처음 보는 이름**만 새 레코드로 만들어 받아들인다. 이미 툼스톤이 있는 이름은 되살리지 않는다.

### 처음 옮길 때 (마이그레이션)

- 새 버전이 처음 뜨면 로컬 목록과 서버의 `category-settings` 를 합쳐 `CategoryItem` 을 만든다.
- 이때 id 는 **이름에서 결정적으로 만든다**(이름의 SHA256 앞 16바이트로 UUID). 두 기기가 동시에
  옮겨도 같은 이름은 같은 id 가 되어 겹치지 않는다.
- 옮긴 뒤 새로 만드는 카테고리는 무작위 UUID 다. 이름에서 만들면 "A 를 B 로 바꾼 뒤 A 를 새로 만들기"가
  같은 id 로 부딪힌다.
- 옮긴 표시는 표식(`memo.sync.epoch`)마다 한 번. 저장소가 바뀌면 다시 확인한다.

## 백업

- `categoriesAsset`(CategorySnapshot JSON)에 `items: [CategoryItem]?` 를 더한다. 옛 버전은 모르는 필드를 무시한다.
- 복원은 `items` 가 있으면 그것으로 **교체**, 없으면 지금처럼 목록에서 역산한다(이름 기반 id).
- 맥 `CloudKitBackupService` 는 `CONTRACT_MAP` 감시 대상이라 필드를 함께 맞춘다.

## "다른 기기를 이 기기에 맞추기"

카테고리 레코드도 서버 전부를 받아 비교한다. 이 기기와 다른 것은 지금 시각으로 다시 올리고,
이 기기에 없는 것은 삭제로 올린다. 확인 창 숫자에 카테고리 개수를 따로 적는다.

## 단계

| 단계 | 내용 | 배포 |
|---|---|---|
| 0 | **이름 바꾸기 버그**: 바꿀 때 단축어 `category`, 아이콘, 색, 숨김도 새 이름으로 옮긴다 | 바로. 독립적이다 |
| 1 | `CategoryItem` 과 `categories.data`, 옛 열쇠 비추기. 옛 열쇠에 직접 쓰는 곳을 `CategoryStore` 로 모은다. 동기화는 그대로 | iOS 먼저, 맥은 공유 파일만 |
| 2 | `MemoSyncCore` 일반화, 카테고리 레코드 동기화, 마이그레이션, 이름 겹침 정리, `category-settings` 호환 | iOS 와 맥을 **같은 날** (공유 엔진) |
| 3 | 백업 `items`, "이 기기에 맞추기"에 카테고리 포함 | 2와 함께 또는 바로 뒤 |
| 4 | 대부분 업데이트한 뒤 `category-settings` 의 목록 쓰기 중단 | 사용 통계로 판단 |

## 시험

- 병합 일반화 뒤에도 기존 `MemoSyncCoreTests`, `MemoSyncConvergenceTests` 가 그대로 통과한다.
- 카테고리: 이름 변경 전파, 삭제 전파, 동시 이름 변경(최신 우선), 이름 겹침 정리의 결정성(두 순서로 병합해도 같은 쪽이 남음).
- 마이그레이션: 두 기기가 같은 이름으로 같은 id 를 만든다. 툼스톤이 있는 이름은 옛 스냅샷에서 되살아나지 않는다.
- 옛 열쇠 비추기: `CategoryItem` 을 바꾸면 여섯 열쇠가 기대한 값이 된다(키보드 확장이 읽는 값).
- 기존 `CategoryStoreTests`, `CategorySnapshotTests`, `HiddenCategoryReachabilityTests` 가 통과한다.

## 위험

- **옛 열쇠에 직접 쓰는 곳을 하나라도 놓치면**, 비추기가 그 값을 덮어써 사용자의 설정이 되돌아간다.
  1단계에서 `grep` 으로 전수 확인하고, 쓰기를 `CategoryStore` 밖에서 못 하게 막는 시험을 둔다.
- 이름 바꾸기 중 단축어와 카테고리가 따로 도착하는 사이에 단축어가 기본 탭에 잠깐 보인다.
- 옛 버전이 오래 남으면 그 기기에는 지운 카테고리가 계속 보인다.
