# 무료로 쓰는 기간 (5.2 수익 모델)

2026-09-30 결정. 시안: https://claude.ai/artifact/FnFDBa1seGkR9zRBMoYQPT

## 한 줄

**단축어를 N번(기본 100) 넣을 때까지는 모든 기능이 무료다.** 그 뒤에 결제하지 않아도 만든 것은 전부 계속 쓰고,
새로 만드는 것에만 예전 무료 한도(단축어 10 · 템플릿 3 · 스택 3 · 이미지 5)가 선다.
요금제는 평생 Pro 와 연 구독 둘뿐이고, 같은 권한을 기간으로만 나눈다.

## 왜

- 예전 "10개까지 무료"는 가치를 받기 **전에** 벽을 세웠다. 10개를 만든 사람이 그걸 쓰는지는 모른다.
- 100번 넣은 사람은 이 앱이 이미 생활에 들어와 있다. 결제를 망설이는 이유(이 값을 하나?)에 대한 증거가
  이미 쌓여 있고, 결제 화면은 그 증거(영수증)를 먼저 보여 준다.
- 문턱 뒤에 만든 것을 잠그지 않는 이유: 남의 앱에서 글을 쓰다가 어제까지 되던 키가 안 눌리면
  사용자에게 그건 결제 안내가 아니라 고장이다. 기존 구매자 보호(심사 기준 3.1.2)와도 맞는다.

## 사용자가 보는 것

| 때 | 무엇 | 어디 |
| --- | --- | --- |
| 첫날부터 | 설정 "무료로 쓰는 중 · 100번 중 N번" → 안내 화면 → Pro 보기 | `SettingView` · `FreeUseGuideView` |
| 50% | 이정표 카드: 쓴 횟수 · 아낀 시간 · "100번까지는 모두 무료" | `FreeUseMilestoneBanner` |
| 80% | 남은 횟수 · 문턱 뒤에도 **그대로인 것** 먼저 | 같은 카드 |
| 100% | 앱을 열 때 한 번: 영수증(기간 · 횟수 · 아낀 시간 · 가장 많이 쓴 것) → 평생 / 연 구독 | `FreeUsePaywallView` |
| 문턱 뒤 한도 | 새로 만들기에서 기존 결제 화면 | `PaywallView` |

모든 안내는 닫을 수 있고 이정표마다 한 번만 뜬다. 키보드에서 넣는 일은 절대 막지 않는다.
"체험" 이라는 말은 쓰지 않는다. 심사 기준에서 체험은 **기간**으로 끝나는 것이다.

## 코드

- `Service/FreeUse.swift`: 문턱 · 센 값 · 이정표. 세는 곳은 `MemoStore.incrementClipCount` 한 곳.
  값은 줄지 않는다(단축어 합계를 쓰면 지웠다 만들기로 문턱을 피한다).
- `ProFeatureManager.hasFullAccess` 에 `FreeUse.isActive` 가 들어 있다. `memosWithinLimit` 은 이제 전부를 돌려준다.
- 연 구독 `com.Ysoup.TokenMemo.pro.yearly` 는 `ClipKeyboardSpec` 의 productIDs · entitlementIDs 둘 다에 있다.
- 문턱은 원격으로 옮긴다: CloudKit `RemoteFlags` 레코드(`flags_com.Ysoup.TokenMemo`)에 Int64 필드
  `freeUseThreshold` 를 넣으면 된다. 20~1000 밖의 값은 무시하고 100 을 쓴다. 필드를 지우면 100 으로 돌아간다.
- 기존 설치는 업데이트 시점에 0 에서 센다. 쓰던 무료 사용자도 갑자기 막히지 않고 100번을 새로 받는다.

## 출시 전에 사람이 할 일

1. App Store Connect 에 자동 갱신 구독 `com.Ysoup.TokenMemo.pro.yearly` 를 만든다(구독 그룹 하나, 1년).
   없으면 결제 화면에서 연 구독 칸만 숨고 평생은 그대로 팔린다.
2. 스토어 설명의 "무료와 Pro" 문단을 여섯 언어 모두 새 모델로 바꾼다(`docs/marketing/APP_STORE_*.md`).
3. 이용약관 페이지(`docs/terms.html`)에 자동 갱신 구독 조항이 있는지 확인한다.

## 조사 요약 (2026-09-30)

[근거]가 붙은 것만 사실이고 나머지는 추론이다.

- [근거] 설치 35일 안 유료 전환 중앙값: 하드 페이월 10.7%, 프리미엄 2.1%
  ([RevenueCat State of Subscription Apps 2026](https://www.revenuecat.com/state-of-subscription-apps)).
  같은 전환이 어떤 앱은 LTV +75%, 어떤 앱은 -50% 로 갈렸다
  ([RevenueCat 블로그](https://www.revenuecat.com/blog/growth/hard-paywall-vs-freemium)). **실험이 필수다.**
- [근거] 체험 시작의 82% 가 설치 당일(Day 0)
  ([2025판](https://www.revenuecat.com/state-of-subscription-apps-2025)).
  → 100번 뒤로 결제를 미루면 첫날 사려던 마음을 놓친다. 그래서 설정 · 안내 화면의 "Pro 보기"를 첫날부터 둔다.
- [근거] 목표가 가까울수록 행동이 빨라진다(goal-gradient, 커피 쿠폰 실험 약 20% 가속)
  ([Kivetz 외 2006](https://business.columbia.edu/sites/default/files-efs/pubfiles/1200/goalgradient.pdf)).
  → 진행 막대와 50 · 80% 이정표의 근거.
- [근거] 무작위 잦은 권유보다 한도에 닿은 순간의 마찰을 권한다
  ([RevenueCat, freemium tier design](https://www.revenuecat.com/blog/growth/freemium-tier-design)).
- [근거] 평생권은 연 가격의 2.1배~11.5배까지 퍼져 있고, 유지비가 낮은 유틸리티에 맞는다
  ([RevenueCat, lifetime](https://www.revenuecat.com/blog/growth/lifetime-subscriptions)).
  연 구독 가격 중앙값 $34.80(2026 보고서).
- [불확실] "영수증 화면이 전환을 X% 올린다"는 공개 1차 자료는 없다. 사용량 문턱 앱의 N 별 전환 공개 자료도 없다.
  **100 은 출발점이지 답이 아니다.**

## 가격 (추론)

평생 = 연 구독의 **2.5~3배**에서 시작한다(예: 연 $9.99 → 평생 $24.99~29.99). 평생 비중이 연 구독을 잡아먹으면
3~4배로 올리는 것을 실험한다. 실제 가격은 App Store Connect 에서 정한다.

## N 을 정하는 법

1. `scripts/analyze_use_threshold.py` 로 쓴 횟수 구간별 도달률 · 걸린 날 · 결제율을 본다
   (cktool 토큰이 필요하다. 스크립트 머리말 참고).
2. 도달한 사람의 D30 리텐션이 꺾여 평평해지는 지점, 그리고 **활성 사용자 중앙값이 2~4주 안에 닿는 지점**을 후보로.
3. 새 설치를 N=50 / 100 / 200 으로 나눠 최소 6주. 주 지표는 설치당 매출(D60), 가드레일은 D30 리텐션 · 환불 · 1~2점 리뷰.
   설치가 적으면 두 갈래로 줄인다. 지금은 원격 값 하나라 모두가 같은 N 을 본다. 설치별로 나누는 것은 다음 일이다.

## 스냅샷에 더한 값

`freeUses`(줄지 않는 횟수) · `freeUseThreshold` · `flag.freePeriod`. 앞으로의 문턱 분석은 `uses`(지금 남은
단축어의 합) 대신 `freeUses` 를 본다.
