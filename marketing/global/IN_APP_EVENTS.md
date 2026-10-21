# 인앱 이벤트 (In-App Events), 2026-11 ~ 2027-01

붙여 넣을 곳: App Store Connect ▸ 앱 ▸ 클립키보드 ▸ **인앱 이벤트**(In-App Events) ▸ (+).
이벤트는 앱 버전과 따로 심사에 낸다. DeployBar 는 이벤트를 올리지 않는다.

## Apple 기준 (공식 문서로 확인, 2026-10-21)

출처: [In-App Events](https://developer.apple.com/app-store/in-app-events/)

| 항목 | 기준 |
| --- | --- |
| 이벤트 이름 | **30자**, 제목형 대문자(영어). 부르는 말(CTA)·"이벤트" 같은 군더더기 금지 |
| 짧은 설명 | **50자**, 문장형. 이벤트 카드에 보인다 |
| 긴 설명 | **120자**, 문장형. 상세 화면에 보인다 |
| 참조 이름 | App Store Connect 안에서만 보인다 |
| 기간 | 최대 **31일**, 시작 **14일 전**부터 미리 알릴 수 있다 |
| 개수 | 승인된 이벤트 15개, 게시 중 10개까지 |
| 목적(Purpose) | 모든 사용자 · 새 사용자 · 기존 사용자에게 알림 · 떠난 사용자 되돌리기 (카드에 안 보이고 추천에만 쓰인다) |
| 우선순위 | 보통 · 높음. 높음이 앞에, 나머지는 시작일 순 |
| 딥링크 | 유니버설 링크 권장, 사용자 지정 URL 가능. 단축 URL 금지 |
| 이벤트 카드 그림 | 16:9, 1920×1080 ~ 3840×2160, jpg/png (영상은 30·60fps mov/m4v/mp4) |
| 상세 화면 그림 | 9:16, 1080×1920 ~ 2160×3840 |
| 그림 주의 | 글자·로고(특히 이벤트 이름·앱 이름)를 넣지 말 것, 테두리·그라데이션 금지(Apple 이 자르고 그라데이션을 얹는다) |
| 거절 사유 | **값을 적으면 거절.** "최고", "1위" 같은 확인할 수 없는 말 금지. 새 내용 없는 **할인만으로는 이벤트가 안 된다.** 앱 전체 홍보 금지 |

이 기준 때문에 뺀 후보: **반값 제안**(`DiscountOfferManager`)은 사람마다 한 번 뜨는 장치라 모두에게 같은 기간이 없고,
새 내용이 없는 할인이라 Apple 이 이벤트로 받지 않는다. 시즌 템플릿은 앱에 없다(코드 확인).

## 한눈에

| # | 참조 이름 | 배지 | 미리 알림 | 시작 | 종료 | 우선순위 | 목적 | 심사에 낼 날 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | `typing-23` | **Major Update** | 2026-11-04 | 2026-11-18 (수) 09:00 | 2026-12-17 (목) 23:59 | 높음 | 모든 사용자 | 5.1.13 출시 직후, 늦어도 2026-10-31 |
| 2 | `holiday-gift` | **Special Event** | 2026-11-28 | 2026-12-12 (토) 09:00 | 2027-01-06 (수) 23:59 | 높음 | 기존 사용자에게 알림 | 2026-11-21 |

시간은 "각 나라 현지 시각"으로 둔다. 1번 30일, 2번 26일로 31일 한도 안이다. 두 이벤트는 겹치지 않는다.

---

## 1. `typing-23`: 키보드 하나로 23개 언어 (Major Update)

**무엇이 실제로 일어나나**: 5.1.13 에서 키보드에 23개 언어 자판이 들어왔다(`cf4b4f7e` · `aebb532c` · `eb59b36e` · `2c361f2e`,
태그 `deploy-ClipKeyboard-5.1.13-37`). Apple 정의의 Major Update("significant new features ... beyond minor enhancements")에 맞는다.
2026-10-21 현재 5.1.13 은 **심사 대기**다. **출시(Ready for Sale)를 확인한 뒤에** 이벤트를 심사에 낸다.

- **배지**: Major Update
- **목적**: Appropriate for all users (새 사용자에게는 "쓰던 키보드 그대로", 기존 사용자에게는 "이제 갈아타지 않아도 된다")
- **딥링크**: 비워 둔다(열기 = 앱 실행). 입력 언어 설정으로 바로 가는 링크는 아직 없다.
  `clipkeyboard://` 가 받는 곳은 `copy` · `paywall` · `feedback` · `fullaccess` · `placeholder` · `saveclip` · `quicknote` 뿐이다
  (`ClipKeyboardApp.handleOpenURL`). 다음 이벤트부터 쓰려면 `clipkeyboard://typing` 같은 길을 앱에 더한다.
- **지역**: 전체. 일본 · 중국 본토 · 대만 · 홍콩은 빼는 것을 권한다(한자 변환이 아직 없다). 빼지 않더라도 ja · zh 문구는
  "한자 입력은 다음 업데이트"라고 정직하게 적었다.
- **그림**: `events/typing-23-card.png` (3840×2160) · `events/typing-23-detail.png` (2160×3840).
  글자 없이 여러 문자의 키와 단축어 자리(알약 모양)만 그렸다. 한자 키는 일부러 넣지 않았다.

## 2. `holiday-gift`: 연말 Pro 선물 (Special Event)

**무엇이 실제로 일어나나**: 설정 ▸ Pro 선물하기(5.1.12, `fca03ab4`). 보내는 사람이 결제하면 코드가 나오고, 받는 사람이
앱의 "선물 코드 입력"에 넣으면 정가 Pro 를 산 것과 같아진다(`LeeoGiftConfig.grantsProductID = com.Ysoup.TokenMemo.pro`).

⚠️ **거절 위험: 중간.** 선물하기는 기간 한정 기능이 아니다. Apple 은 Special Event 에 "new content, features, or goods"를 요구하는데,
가을에 새로 나온 기능을 연말에 처음 크게 알리는 것이라 맞는다고 보고 문구를 짰다. 거절되면 다투지 말고 접는다.
값(가격)은 어떤 문구에도 넣지 않았다(넣으면 거절).

⚠️ **내기 전 확인**: 선물 상품 `com.Ysoup.TokenMemo.gift.pro` 가 판매 중이고, 출시 빌드에서 사고 받는 데까지 된다. 설정의 선물 줄은
상품이 와야 보인다. 안 보이는 나라가 있으면 그 나라는 지역에서 뺀다.

- **배지**: Special Event
- **목적**: Keep active users informed (선물을 사는 쪽은 이미 쓰는 사람이다)
- **딥링크**: 비워 둔다. 선물 화면으로 가는 길이 없다(위 목록). 만들려면 `clipkeyboard://gift` 를 앱에 더한다.
- **지역**: 전체(선물 상품이 팔리는 나라).
- **그림**: `events/holiday-gift-card.png` · `events/holiday-gift-detail.png`. 리본 두른 큰 키 하나와 둘레의 여러 문자 키.
  크리스마스 상징은 넣지 않았다(태국 · 인도네시아 · 튀르키예 · 베트남에도 같은 그림이 나간다).

## 그림

`python3 marketing/global/events/make_event_art.py` 로 다시 만든다(헤드리스 Chrome). 2배 해상도라 최대 규격에 맞다.

**더 좋게 하려면(사람 일)**: Apple 은 앱 안의 실제 장면을 좋아한다. 지금 레포의 스크린샷(`docs/screenshots/raw/`)은 10월 6일
촬영이라 **자판이 나오기 전 화면**이고, 선물 화면도 찍힌 적이 없다. 실기기나 시뮬레이터에서 아래를 찍어 글자 없는 배경 위에
올리면 이 그림을 바꿀 수 있다.

| 이벤트 | 찍을 장면 | 필요한 것 |
| --- | --- | --- |
| typing-23 | 메시지 앱에서 키보드가 자판 판(예: 독일어 QWERTZ)이고 맨 위에 단축어 띠가 보이는 순간 | 5.1.13 빌드, 입력 언어 2~3개 켜기. `-ScreenshotScene` 에 자판 장면이 없어 `take_screenshots.sh` 로는 못 찍는다 |
| holiday-gift | 설정 ▸ Pro 선물하기 화면(코드와 보내기 단추) | 실제 선물 상품 또는 `LeeoGiftView(previewPrice:)` 미리보기 |

이벤트 카드에는 영상(16:9, 30·60fps, 반복 재생)도 된다. `docs/screenshots/preview/` 의 미리보기 영상은 자판 이전이라 쓰지 않는다.

---

## 로케일별 문구 (24개)

원본: `events/event_text.json`. 세기: `python3 marketing/global/events/count_event_text.py`
(한도를 넘거나 ko 밖에 한글이 섞이면 실패로 끝난다). 아래 표는 그 출력이다. 글자 수는 유니코드 글자(NFC) 기준.

- en-GB 는 en-US 와 같은 문구다(영국 철자로 달라지는 낱말이 없다).
- 단축어를 부르는 말은 앱 번역과 맞췄다: ja 定型文 · zh 短语/短語 · de Textbaustein · th ข้อความด่วน · nl fragment · tr İfade …
- "설정"은 앱의 번역(Ajustes · Réglages · Einstellungen …)을 그대로 썼다.
- 북유럽 · 체코의 선물 이벤트 이름은 그 나라에서 자연스러운 '크리스마스 선물'(julegave · julklapp · joululahja · vánoční dárek)로, 나머지는 '연말 · 축제'로 썼다.

#### `typing-23`

| 로케일 | 이벤트 이름 | 자 | 짧은 설명 | 자 | 긴 설명 | 자 |
| --- | --- | ---: | --- | ---: | --- | ---: |
| ko | 키보드 하나로 23개 언어 | 14 | 글도 단축어도, 키보드를 바꾸지 않고 | 20 | iPhone과 같은 배열로 23개 언어를 치고, 저장해 둔 단축어도 같은 키보드에서 바로 넣어요. | 54 |
| en-US | One Keyboard, 23 Languages | 26 | Type and use snippets on the same keyboard | 42 | Type in 23 languages on layouts that match iPhone, and drop in a saved snippet without switching keyboards. | 107 |
| en-GB | One Keyboard, 23 Languages | 26 | Type and use snippets on the same keyboard | 42 | Type in 23 languages on layouts that match iPhone, and drop in a saved snippet without switching keyboards. | 107 |
| zh-Hans | 一个键盘，23 种语言 | 11 | 打字和插入短语，都不用切换键盘 | 15 | 按 iPhone 的键位输入 23 种语言，常用短语也在同一个键盘上。汉字输入将在后续更新中加入。 | 49 |
| zh-Hant | 一個鍵盤，23 種語言 | 11 | 打字和插入短語，都不用切換鍵盤 | 15 | 依 iPhone 的鍵位輸入 23 種語言，常用短語也在同一個鍵盤上。漢字輸入將在之後的更新加入。 | 49 |
| ru | Одна клавиатура, 23 языка | 25 | Печать и фразы на одной клавиатуре | 34 | Печатайте на 23 языках с раскладками как на iPhone и вставляйте сохранённые фразы, не меняя клавиатуру. | 103 |
| ja | ひとつのキーボードで23言語 | 14 | 文字入力も定型文も、切り替えなしで | 17 | iPhoneと同じ配列で23言語を入力でき、定型文もそのまま挿入できます。漢字変換は今後のアップデートで対応予定です。 | 59 |
| es-MX | Un teclado, 23 idiomas | 22 | Escribe y usa tus frases sin cambiar de teclado | 47 | Escribe en 23 idiomas con la distribución del iPhone y usa tus frases guardadas sin cambiar de teclado. | 103 |
| de-DE | Eine Tastatur, 23 Sprachen | 26 | Tippen und Textbausteine ohne Tastaturwechsel | 45 | Tippe in 23 Sprachen mit den Layouts des iPhone und füge Textbausteine ein, ohne die Tastatur zu wechseln. | 106 |
| fr-FR | Un clavier, 23 langues | 22 | Saisie et phrases sur un seul et même clavier | 45 | Écrivez dans 23 langues avec les dispositions de l’iPhone et insérez vos phrases sans changer de clavier. | 105 |
| it | Una tastiera, 23 lingue | 23 | Scrivi e inserisci frasi senza cambiare tastiera | 48 | Scrivi in 23 lingue con i layout dell’iPhone e inserisci le frasi salvate senza cambiare tastiera. | 98 |
| pt-BR | Um teclado, 23 idiomas | 22 | Digite e use suas frases sem trocar de teclado | 46 | Digite em 23 idiomas com o layout do iPhone e insira suas frases salvas sem trocar de teclado. | 94 |
| th | คีย์บอร์ดเดียว 23 ภาษา | 22 | พิมพ์และใส่ข้อความด่วนได้ในคีย์บอร์ดเดียว | 41 | พิมพ์ได้ 23 ภาษาด้วยแป้นแบบเดียวกับ iPhone และใส่ข้อความด่วนที่บันทึกไว้ได้โดยไม่ต้องสลับคีย์บอร์ด | 98 |
| vi | Một bàn phím, 23 ngôn ngữ | 25 | Gõ chữ và chèn cụm từ mà không cần đổi bàn phím | 47 | Gõ 23 ngôn ngữ với bố cục giống iPhone và chèn cụm từ đã lưu mà không cần đổi bàn phím. | 87 |
| cs | Jedna klávesnice, 23 jazyků | 27 | Pište a vkládejte fráze bez přepínání klávesnice | 48 | Pište ve 23 jazycích s rozložením jako na iPhonu a vkládejte uložené fráze bez přepínání klávesnice. | 100 |
| da | Ét tastatur, 23 sprog | 21 | Skriv og indsæt fraser uden at skifte tastatur | 46 | Skriv på 23 sprog med samme layout som på iPhone, og indsæt gemte fraser uden at skifte tastatur. | 97 |
| el | Ένα πληκτρολόγιο, 23 γλώσσες | 28 | Γράψτε και προσθέστε φράσεις στο ίδιο πληκτρολόγιο | 50 | Γράψτε σε 23 γλώσσες με διάταξη όπως στο iPhone και προσθέστε φράσεις χωρίς να αλλάξετε πληκτρολόγιο. | 101 |
| fi | Yksi näppäimistö, 23 kieltä | 27 | Kirjoita ja lisää fraaseja samalla näppäimistöllä | 49 | Kirjoita 23 kielellä iPhonen asetteluilla ja lisää tallennetut fraasit vaihtamatta näppäimistöä. | 96 |
| id | Satu Keyboard, 23 Bahasa | 24 | Mengetik dan memakai frasa di satu keyboard | 43 | Ketik dalam 23 bahasa dengan tata letak seperti iPhone, lalu masukkan frasa tersimpan tanpa berganti keyboard. | 110 |
| nb | Ett tastatur, 23 språk | 22 | Skriv og sett inn fraser uten å bytte tastatur | 46 | Skriv på 23 språk med samme oppsett som på iPhone, og sett inn lagrede fraser uten å bytte tastatur. | 100 |
| nl | Eén toetsenbord, 23 talen | 25 | Typen en fragmenten invoegen op één toetsenbord | 47 | Typ in 23 talen met de indeling van de iPhone en voeg bewaarde fragmenten in zonder te wisselen. | 96 |
| pl | Jedna klawiatura, 23 języki | 27 | Pisz i wstawiaj frazy bez zmiany klawiatury | 43 | Pisz w 23 językach na układach jak w iPhonie i wstawiaj zapisane frazy bez zmiany klawiatury. | 93 |
| sv | Ett tangentbord, 23 språk | 25 | Skriv och infoga fraser utan att byta tangentbord | 49 | Skriv på 23 språk med samma layout som på iPhone och infoga sparade fraser utan att byta tangentbord. | 101 |
| tr | Tek Klavye, 23 Dil | 18 | Klavye değiştirmeden yazın ve ifade ekleyin | 43 | iPhone ile aynı düzenlerle 23 dilde yazın, kayıtlı ifadelerinizi klavye değiştirmeden ekleyin. | 94 |

#### `holiday-gift`

| 로케일 | 이벤트 이름 | 자 | 짧은 설명 | 자 | 긴 설명 | 자 |
| --- | --- | ---: | --- | ---: | --- | ---: |
| ko | 연말 Pro 선물 시즌 | 12 | 결제는 내가, Pro는 받는 사람이 써요 | 22 | 설정의 Pro 선물하기에서 결제하면 선물 코드가 생겨요. 받는 사람이 앱에 코드를 넣으면 Pro를 계속 써요. | 61 |
| en-US | Holiday Pro Gifting | 19 | You pay, and someone you care about gets Pro | 44 | Buy a gift in Settings and you get a code to send. They enter it in the app, and Pro is theirs to keep. | 103 |
| en-GB | Holiday Pro Gifting | 19 | You pay, and someone you care about gets Pro | 44 | Buy a gift in Settings and you get a code to send. They enter it in the app, and Pro is theirs to keep. | 103 |
| zh-Hans | 节日 Pro 礼物季 | 10 | 由你付款，对方使用 Pro | 13 | 在设置的“赠送 Pro”中付款后，会得到一个礼物码。对方在 App 中输入礼物码，即可一直使用 Pro。 | 52 |
| zh-Hant | 節日 Pro 禮物季 | 10 | 由你付款，對方使用 Pro | 13 | 在設定的「贈送 Pro」付款後，會取得一組禮物碼。對方在 App 中輸入禮物碼，即可一直使用 Pro。 | 51 |
| ru | Pro в подарок к праздникам | 26 | Платите вы, а Pro получает близкий человек | 42 | Купите подарок в настройках и отправьте код. Получатель вводит его в приложении, и Pro остаётся у него навсегда. | 112 |
| ja | ホリデー Pro ギフト | 12 | お支払いは贈る方、Pro は受け取る方に | 20 | 設定の「Pro をギフトする」で購入するとギフトコードが表示されます。相手がアプリでコードを入力すれば、Pro をずっと使えます。 | 65 |
| es-MX | Temporada de regalos Pro | 24 | Tú pagas y la otra persona recibe Pro | 37 | Compra un regalo en Ajustes y obtén un código para enviarlo. Al ingresarlo en la app, Pro es suyo para siempre. | 111 |
| de-DE | Pro als Festtagsgeschenk | 24 | Du zahlst, und die beschenkte Person bekommt Pro | 48 | Kaufe in den Einstellungen ein Geschenk und sende den Code. Wer ihn in der App eingibt, behält Pro dauerhaft. | 109 |
| fr-FR | Pro à offrir pour les fêtes | 27 | Vous réglez, et la personne reçoit Pro | 38 | Achetez un cadeau dans les Réglages et envoyez le code. Une fois saisi dans l’app, Pro lui reste acquis. | 104 |
| it | Pro da regalare per le feste | 28 | Paghi tu, e Pro lo usa chi lo riceve | 36 | Acquista un regalo nelle Impostazioni e invia il codice. Chi lo inserisce nell’app tiene Pro per sempre. | 104 |
| pt-BR | Pro de presente nas festas | 26 | Você paga, e a pessoa presenteada usa o Pro | 43 | Compre um presente nos Ajustes e envie o código. Quem inserir o código no app fica com o Pro para sempre. | 105 |
| th | ของขวัญ Pro ช่วงเทศกาล | 22 | คุณชำระเงิน แล้วอีกฝ่ายใช้ Pro ได้เลย | 37 | ซื้อของขวัญในการตั้งค่าแล้วส่งรหัสให้ผู้รับ เมื่อใส่รหัสในแอป ผู้รับจะใช้ Pro ได้ตลอดไป | 87 |
| vi | Quà tặng Pro mùa lễ | 19 | Bạn thanh toán, người nhận dùng Pro | 35 | Mua quà trong Cài đặt rồi gửi mã. Người nhận nhập mã trong ứng dụng là dùng được Pro mãi mãi. | 93 |
| cs | Pro jako vánoční dárek | 22 | Platíte vy, Pro dostane druhá osoba | 35 | Kupte dárek v Nastavení a pošlete kód. Kdo ho zadá v aplikaci, má Pro natrvalo. | 79 |
| da | Pro som julegave | 16 | Du betaler, og modtageren får Pro | 33 | Køb en gave under Indstillinger, og send koden. Når modtageren indtaster den i appen, har de Pro for altid. | 107 |
| el | Pro για δώρο στις γιορτές | 25 | Εσείς πληρώνετε και ο παραλήπτης αποκτά το Pro | 46 | Αγοράστε ένα δώρο από τις Ρυθμίσεις και στείλτε τον κωδικό. Όποιος τον βάλει στην εφαρμογή κρατά το Pro για πάντα. | 114 |
| fi | Pro joululahjaksi | 17 | Sinä maksat, ja saaja saa Pron | 30 | Osta lahja asetuksista ja lähetä koodi. Kun saaja syöttää sen apissa, Pro jää hänelle pysyvästi. | 96 |
| id | Hadiah Pro Akhir Tahun | 22 | Anda yang membayar, dia yang memakai Pro | 40 | Beli hadiah di Pengaturan, lalu kirim kodenya. Setelah kode dimasukkan di app, Pro bisa dipakai selamanya. | 106 |
| nb | Pro som julegave | 16 | Du betaler, og mottakeren får Pro | 33 | Kjøp en gave under Innstillinger og send koden. Når mottakeren skriver den inn i appen, har de Pro for alltid. | 110 |
| nl | Pro cadeau voor de feestdagen | 29 | Jij betaalt, de ander krijgt Pro | 32 | Koop een cadeau in Instellingen en stuur de code. Wie de code in de app invoert, houdt Pro voorgoed. | 100 |
| pl | Pro w prezencie na święta | 25 | Ty płacisz, a ktoś bliski dostaje Pro | 37 | Kup prezent w Ustawieniach i wyślij kod. Kto wpisze go w aplikacji, zachowa Pro na zawsze. | 90 |
| sv | Pro som julklapp | 16 | Du betalar, och mottagaren får Pro | 34 | Köp en gåva under Inställningar och skicka koden. När mottagaren anger den i appen har hen Pro för alltid. | 106 |
| tr | Yılbaşına Özel Pro Hediyesi | 27 | Siz ödersiniz, Pro'yu sevdiğiniz kişi kullanır | 46 | Ayarlar'dan hediye satın alın ve kodu gönderin. Kodu uygulamaya giren kişi Pro'yu kalıcı olarak kullanır. | 105 |
