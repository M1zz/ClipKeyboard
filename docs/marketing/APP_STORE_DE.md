# 독일어 스토어 문안

App Store Connect 의 `de-DE` 로케일에 넣을 값입니다.
짜임은 [`APP_STORE_ES.md`](APP_STORE_ES.md) 와 같습니다. 거기 적힌 "남은 일" 순서(ASC 로케일 먼저, `LOCALES` 는 그다음)를 그대로 따릅니다.

## 왜 독일어인가 (2026-09-30)

독일이 430건입니다. 매출이 큰 시장이고, 영어로 쓰는 사람이 많아도 결제 화면은 모국어일 때 전환이 낫습니다.

## 남은 일 (사람이 해야 함)

1. App Store Connect 웹에서 `de-DE` 로케일을 만들고 아래 값을 채운다. 인앱 구매 표시 이름도 더한다.
2. 로케일이 생긴 뒤 `deploy.env` 의 `LOCALES` 에 `de-DE` 를 더한다. `RELEASE_NOTES.md` 의 5.1.7 에는 절이 이미 있다.
   `RELEASE_NOTES.md` 5.1.7 의 이 언어 절 제목에서 `노출 안 함: ` 을 지운다. 로케일이 없을 때 제목을 못 알아본 DeployBar 가
   본문 글자로 판별해 라틴 문자를 `en` 으로 읽기 때문에 막아 둔 것이다.
3. 독일어 화면을 한 번 본다. 한국어보다 1.7배 길어 열 언어 중 가장 길다. 키보드 안에서 길어지는 것은 VoiceOver 문구뿐이었지만, 앱 화면의 버튼은 눈으로 봐야 한다.

## 용어

| 한국어 | 독일어 |
| --- | --- |
| 단축어 | Textbaustein |
| 메모 | Notiz |
| 채우는 칸 | Ausfüllfeld |
| 스택 | Stapel |

호칭은 Apple 과 같이 `du`.

고정값은 `i18n/glossary.json` 에 있습니다.

---

## 이름 · 부제

| 칸 | 값 | 자수 |
| --- | --- | --- |
| 이름 | `Clip Keyboard: Textbausteine` | 28 |
| 부제 | `Texte mit einem Tipp einfügen` | 29 |

---

## 설명

⚠️ 마지막 요금 문단은 5.2 수익 모델(`docs/product/FREE_USE_MODEL.md`) 기준입니다. 연 구독이 ASC 에 없으면 연 구독 부분을 뺍니다.

```
Schluss damit, immer wieder dasselbe zu tippen. Einmal speichern, danach reicht ein Tipp.

Speichere IBAN, Adresse, deine Vorstellung oder den Anfang deiner E-Mails als Textbausteine. In Nachrichten, Mail, Safari und überall, wo du tippen kannst: zu ClipKeyboard wechseln, einmal tippen, und der Text steht im Feld.

Was es kann

Textbausteine: Was du gespeichert hast, wird genau so eingefügt. Ein Tipp.
Vorlagen: Lass die Teile, die sich ändern, als Ausfüllfelder frei und fülle sie mit Werten, die du schon gespeichert hast.
Stapel: Mehrere Werte an einem Ort, der Reihe nach senden oder mit dem Pfeil wechseln.
Geschützte Textbausteine: Pass- und Kartennummern mit Face ID sperren und nur bei Bedarf öffnen.
Intelligente Zwischenablage: Was du kopierst, wird sortiert. E-Mails, Telefonnummern, Adressen, Kartennummern und IBANs werden erkannt, damit du sie in einer Sekunde wiederfindest.
Texterkennung: Karte oder Dokument fotografieren, über den gewünschten Teil wischen, und nur dieser Text wird zum Wert.
iCloud-Backup: Übersteht ein neues iPhone, Bild-Textbausteine inklusive.

Gut zu wissen

Das ist eine Tastatur zum Einfügen gespeicherter Texte. Sie ersetzt nicht die Tastatur, mit der du schreibst. Wechsle zu ihr, wenn du etwas einfügen willst, und danach zurück.

Datenschutz

Was du schreibst, bleibt auf deinem Gerät. Mit iCloud-Backup wird es verschlüsselt in deiner eigenen iCloud gespeichert. Wir sammeln keine Inhalte deiner Textbausteine und nutzen keine Analysedienste von Drittanbietern.

Gratis und Pro

Für deine ersten 100 Eingaben ist alles gratis. Danach funktioniert alles, was du schon erstellt hast, weiter wie bisher; das Gratis-Limit gilt nur für Neues. Pro gibt es als Einmalkauf oder als Jahresabo und hebt alle Limits auf.

Für iPhone, iPad, Mac und Vision Pro. Auf Deutsch, Englisch, Koreanisch, Japanisch, Spanisch, Chinesisch (vereinfacht und traditionell), Russisch, Thai und Vietnamesisch.

Kontakt: leeo@kakao.com
Anleitung: https://m1zz.github.io/ClipKeyboard/tutorial.html?lang=en
```

---

## 키워드 (97/100자, 이름·부제 낱말 제외)

```
zwischenablage,vorlage,autofill,kurzbefehl,antworten,signatur,adresse,IBAN,notizen,makro,kopieren
```

`IBAN` 은 독일 사람이 가장 자주 붙여 넣는 값 중 하나입니다.
⚠️ 기계로 고른 말입니다. 그 나라 검색어 도구로 한 번 확인하는 편이 좋습니다.

---

## 프로모션 텍스트 (156/170자)

```
Kopiertes, deine Standardtexte und sogar deine IBAN: ein Tipp auf der Tastatur und alles steht da. Jetzt auf Deutsch, die Sprache wählst du auch in der App.
```

---

## 로케일별 링크

| 로케일 | 개인정보 처리방침 | 지원 · 마케팅 |
| --- | --- | --- |
| de-DE | `https://m1zz.github.io/ClipKeyboard/privacy.html?lang=en` | `https://m1zz.github.io/ClipKeyboard/tutorial.html?lang=en` |

공개 문서 페이지에 이 언어가 없어 영어를 가리킵니다.
