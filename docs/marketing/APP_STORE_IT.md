# 이탈리아어 스토어 문안

App Store Connect 의 `it` 로케일에 넣을 값입니다.
짜임은 [`APP_STORE_DE.md`](APP_STORE_DE.md) 와 같습니다. 순서(ASC 로케일 먼저, `LOCALES` 는 그다음)를 그대로 따릅니다.
스토어에 올라가는 원본은 루트의 `APPSTORE.md` 이고, 이 문서는 왜 그 말을 골랐는지 적어 둔 기록입니다.

## 왜 이탈리아어인가 (2026-10-06)

이탈리아는 유럽 App Store 상위 시장이고 영어로 앱을 쓰는 비율이 낮은 편이라, 모국어 화면의 차이가 큽니다. LeeoKit 에 이미 이탈리아어가 있습니다.

## 남은 일 (사람이 해야 함)

> 2026-10-06: 1~2번은 끝났다. ASC 에 `it` 로케일을 만들어 문안을 넣었고, `LOCALES` 에 더하고 릴리즈노트 절을 노출로 바꿨다.

1. App Store Connect 에서 `it` 로케일을 만들고 아래 값을 채운다. 인앱 구매 표시 이름도 더한다.
2. 로케일이 생긴 뒤 `deploy.env` 의 `LOCALES` 에 `it` 를 더한다.
   `RELEASE_NOTES.md` 5.1.7 의 이 언어 절 제목에서 `노출 안 함: ` 을 지운다.
3. 이탈리아어 화면을 한 번 본다. 한국어보다 1.5배 안팎 길어서, 앱 화면의 좁은 버튼은 눈으로 봐야 한다.

## 용어

| 한국어 | 이탈리아어 |
| --- | --- |
| 단축어 | Frase |
| 메모 | Nota |
| 채우는 칸 | campo da compilare |
| 스택 | Pila |

호칭은 `tu` (Apple 이탈리아어와 같음).

고정값은 `i18n/glossary.json` 에 있습니다.

---

## 이름 · 부제

| 칸 | 값 | 자수 |
| --- | --- | --- |
| 이름 | `Clip Keyboard - Frasi rapide` | 28 |
| 부제 | `Testi pronti con un tocco` | 25 |

---

## 설명

```
Basta digitare sempre le stesse cose. Salvale una volta, poi basta un tocco.

Salva come frasi i numeri di conto, l’indirizzo, la tua presentazione o l’inizio delle email che usi spesso. In Messaggi, Mail, Safari e ovunque puoi scrivere, passa a ClipKeyboard, tocca una volta e il testo finisce nel campo.

Cosa fa

Frasi: quello che hai salvato viene inserito così com’è. Un tocco.
Modelli: lascia le parti che cambiano come campi da compilare, poi riempili con valori già salvati.
Pile: più valori in un unico posto, da inviare in ordine o da cambiare con la freccia.
Frasi protette: blocca numeri di passaporto e di carta con Face ID e aprili solo quando servono.
Appunti intelligenti: quello che copi viene ordinato per te. Riconosce email, numeri di telefono, indirizzi, numeri di carta e IBAN, così li ritrovi in un secondo.
Riconoscimento del testo: fotografa una carta o un documento, scorri sulla parte che ti serve e solo quel testo diventa un valore.
Backup su iCloud: resiste al cambio di iPhone, frasi con immagini comprese.

Da sapere

È una tastiera per inserire testi salvati. Non sostituisce la tastiera con cui scrivi. Passa a questa quando devi inserire qualcosa, poi torna indietro.

Privacy

Quello che scrivi resta sul tuo dispositivo. Se attivi il backup su iCloud, viene salvato cifrato nel tuo iCloud. Non raccogliamo il contenuto delle tue frasi e non usiamo strumenti di analisi di terze parti.

Gratis e Pro

Tutte le funzioni sono gratis per i primi 100 inserimenti. Dopo, tutto quello che hai creato continua a funzionare; i limiti gratuiti valgono solo per i nuovi elementi. Pro toglie ogni limite, con acquisto una tantum o abbonamento annuale.

Per iPhone e iPad. In italiano, inglese, coreano, giapponese, cinese (semplificato e tradizionale), russo, spagnolo, tedesco, francese, portoghese (Brasile), thailandese e vietnamita.

Contatto: leeo@kakao.com
Guida: https://m1zz.github.io/ClipKeyboard/tutorial.html?lang=en
Termini di utilizzo: https://m1zz.github.io/ClipKeyboard/terms.html?lang=en
```

---

## 키워드 (93/100자, 이름·부제 낱말 제외)

```
appunti,modello,scorciatoia,risposte,firma,indirizzo,IBAN,note,macro,copia,tastiera,compilare
```

`IBAN` 은 유럽에서 가장 자주 붙여 넣는 값 중 하나입니다.
⚠️ 기계로 고른 말입니다. 그 나라 검색어 도구로 한 번 확인하는 편이 좋습니다.

---

## 프로모션 텍스트 (152/170자)

```
Quello che copi, i testi di sempre e perfino il tuo IBAN: un tocco sulla tastiera ed è tutto lì. Ora in italiano, e la lingua si sceglie anche nell’app.
```

---

## 로케일별 링크

| 로케일 | 개인정보 처리방침 | 지원 · 마케팅 |
| --- | --- | --- |
| it | `https://m1zz.github.io/ClipKeyboard/privacy.html?lang=en` | `https://m1zz.github.io/ClipKeyboard/tutorial.html?lang=en` |

공개 문서 페이지에 이 언어가 없어 영어를 가리킵니다.
