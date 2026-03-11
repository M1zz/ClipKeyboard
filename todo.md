# ClipKeyboard 리팩토링 진행 상황

## Phase 1: Foundation (Storage + Repository) ✅ 완료

- [x] `Data/Storage/AppGroupStorage.swift` - App Group 스토리지 래퍼
- [x] `Domain/Repository/MemoRepositoryProtocol.swift`
- [x] `Domain/Repository/ClipboardRepositoryProtocol.swift`
- [x] `Domain/Repository/ComboRepositoryProtocol.swift`
- [x] `Data/Repository/MemoRepository.swift` - MemoStore 위임
- [x] `Data/Repository/ClipboardRepository.swift`
- [x] `Data/Repository/ComboRepository.swift`

## Phase 2: Use Cases ✅ 완료

- [x] `Domain/UseCase/ClassifyClipboardUseCase.swift`
- [x] `Domain/UseCase/SaveMemoUseCase.swift`

## Phase 3: ViewModel ✅ 완료

- [x] `Presentation/MemoAdd/MemoAddViewModel.swift`

## Phase 4: DI Container ✅ 완료

- [x] `App/AppDependencies.swift`

## Phase 5: Xcode 프로젝트 파일 등록 ✅ 완료

- [x] PBXFileReference 등록 (11개 파일)
- [x] PBXBuildFile 등록 (11개 파일, ClipKeyboard 타겟만)
- [x] PBXGroup 생성 (Data, Data/Storage, Data/Repository, Domain, Domain/Repository, Domain/UseCase, Presentation, Presentation/MemoAdd, App)
- [x] PBXSourcesBuildPhase 등록

## Phase 6: 구조 개선 ✅ 완료

- [x] ClipKeyboardApp.swift에 AppDependencies 주입 (`.environmentObject(deps)`)
- [x] ProStatusManager 이중 상태 제거 (Combine 구독 제거, StoreManager 직접 호출 방식 유지)
- [x] MemoStore God Object 분해:
  - [x] ClipboardClassificationService → 별도 파일 추출 (678줄 → 540줄 → 삭제)
  - [x] OCRService → 별도 파일 추출
  - [x] MemoStore.swift: 1,220줄 → 678줄 (분류/OCR 서비스 분리)

## 다음 단계 (미완료)

- [ ] MemoAdd.swift의 @State 변수를 MemoAddViewModel로 완전 연결 (남은 View-only 상태 정리)
- [ ] ClipKeyboardList ViewModel 분리 (1,071줄 → ViewModel + View 분리)
- [ ] 미커밋 파일 커밋 (StoreManager, ProStatusManager, Products.storekit, 새 Service 파일들)
