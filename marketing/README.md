# App Store 스크린샷 자동 생성

원본 앱 화면을 아이폰 프레임에 끼우고 위에 마케팅 문구를 얹어, 제출용 스크린샷을 자동 생성합니다.

## 구성

| 파일 | 역할 |
|---|---|
| `make_shot.py` | 프레이밍 + 텍스트 합성 (핵심) |
| `shots.json` | 컷별 화면·문구 정의 (여기만 편집하면 됨) |
| `capture.sh` | 시뮬레이터 현재 화면을 깔끔한 상태바로 캡처 |
| `raw/` | 원본 앱 화면 (입력) |
| `out/` | 완성 스크린샷 (출력, 1290×2796 = 6.9") |
| `mockup.png` | PNG 목업 (frame_style="mockup" 일 때만 사용) |

## 워크플로

```bash
# 1) 시뮬레이터에서 ClipKeyboard 를 원하는 화면으로 이동시킨 뒤 캡처
./capture.sh screen1        # → raw/screen1.png
./capture.sh screen2        # 다른 화면으로 이동 후 반복

# 2) shots.json 에 컷별 파일명·문구 작성

# 3) 전체 생성
python3 make_shot.py        # → out/01.png, out/02.png ...
```

## 프레임 방식 두 가지 (`frame_style`)

- **`clean`** (기본, 권장): 코드로 그린 아이폰 프레임. **워터마크 없음**, 임의 해상도 선명,
  모서리 반경이 앱 화면과 맞아 잘림 없음.
- **`mockup`**: `mockup.png` PNG 목업을 사용. 화면 영역을 자동 검출(둥근 모서리·노치 반영).
  ⚠️ pngtree 등 **무료 스톡 목업은 반투명 워터마크가 결과에 새어 나오므로** 제출용으로는 비권장.
  깨끗한(워터마크 없는) 목업 PNG 가 있을 때만 사용하세요.

## 스타일 조정 (`shots.json` 의 `defaults` 또는 컷별)

- `bg_top` / `bg_bottom` : 배경 그라디언트 (밝게: `#F5F5F7`→`#FFFFFF`, 어둡게: 기본값)
- `accent` : 아이브로우(윗줄) 색 — 기본 `#4FACFE` (앱 브랜드 블루)
- `title_color` / `title_size` / `eyebrow_size`
- `phone_scale` : 폰 크기(캔버스 폭 대비, 0.86)
- `phone_top` : 폰 상단 위치(높을수록 아래로). 폰이 캔버스 하단으로 자연스럽게 bleed 됩니다.
- `title` 에 `\n` 을 쓰면 강제 줄바꿈, 없으면 자동 워드랩.
- `size` : `[1290,2796]`=6.9"(기본), `[1242,2688]`=6.5".

## 참고: 시뮬레이터 CloudKit 크래시 가드

시뮬레이터는 iCloud 엔타이틀먼트가 적용되지 않아 `CKContainer(identifier:)` 가
런치 즉시 앱을 죽입니다. `CloudKitBackupService.swift` 에 **시뮬레이터 전용 가드**를 넣어
(실기기/앱스토어 빌드에는 영향 없음) 시뮬레이터에서도 앱이 뜨고 화면을 캡처할 수 있습니다.
