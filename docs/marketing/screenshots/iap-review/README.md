# 인앱 상품 심사 이미지

App Store Connect ▸ 앱 내 구입 ▸ 상품 ▸ **심사 정보 ▸ 스크린샷**에 올리는 이미지.
상품마다 한 장. 심사자가 읽기 쉽게 `en/` 을 올린다(`ko/` 는 같은 화면의 한국어판).

| 파일 | 상품 | 화면 |
| --- | --- | --- |
| `com.Ysoup.TokenMemo.gift.pro.png` | Pro 선물 (소모성) | 설정 ▸ Pro 선물하기 (`LeeoGiftView`) |
| `com.Ysoup.TokenMemo.tip.small.png` | 팁 작은 것 (소모성) | 설정 ▸ 개발자 응원하기 (`LeeoTipJarView`) |
| `com.Ysoup.TokenMemo.tip.medium.png` | 팁 중간 (소모성) | 같은 화면 |
| `com.Ysoup.TokenMemo.tip.large.png` | 팁 큰 것 (소모성) | 같은 화면 |

규격 1242x2688 (스토어 스크린샷과 같다). 가격은 그림을 그릴 때 넣은 예시값이다(실제 가격은 App Store Connect 가 정한다).

## 다시 만들기

StoreKit 상품 없이 그린다. 두 화면에 **결제하지 않는 미리보기 입구**가 있다:
`LeeoTipJarView(previewPrices: ["$0.99", "$2.99", "$9.99"])` · `LeeoGiftView(previewPrice: "$9.99", gift:)`.
시험 대상 앱 안에서 창을 하나 띄워 그 화면을 얹고, 414x896 을 3배로 찍는다
(`UIWindow.drawHierarchy`. `ImageRenderer` 는 ScrollView · NavigationStack 을 못 그린다).

⚠️ 단위 시험의 `SKTestSession` 으로는 로컬 .storekit 상품이 불러와지지 않았다(진짜 App Store 의 Pro 하나만 왔다).
그래서 미리보기 입구를 만들었다.
