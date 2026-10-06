# 스페인어 스토어 문안

App Store Connect 의 `es-MX` 로케일에 넣을 값입니다.
한국어·영어는 [`APP_STORE_KO_EN.md`](APP_STORE_KO_EN.md), 일본어는 [`APP_STORE_JA.md`](APP_STORE_JA.md) 에 있습니다.

## 왜 스페인어인가 (2026-09-30)

멕시코가 914건으로 중국(999) 다음입니다. 스페인어는 지원하지 않던 언어라, 이 사람들은 지금 앱을 영어로 씁니다.
효과는 새 유입보다 **전환율과 유지율**에서 먼저 보일 것이므로, 켜기 전 멕시코 수치를 기준선으로 남겨 둡니다.

## 로케일을 어떻게 나눴나

| 어디 | 무엇 | 왜 |
| --- | --- | --- |
| 앱 안 | `es` 하나 | `es-MX` 로만 넣으면 스페인·콜롬비아·아르헨티나 등 다른 스페인어 기기는 영어로 떨어질 수 있다 |
| 번역 어투 | 멕시코 우선 중남미 스페인어, `tú` | `i18n/config.json` 의 `es.note` 가 번역기에 넘어간다 |
| 스토어 | `es-MX` | 근거가 멕시코다. 스페인 시장을 원하면 `es-ES` 를 따로 더한다 |

## 남은 일 (사람이 해야 함)

> 2026-09-30: 1~3번은 끝났다. ASC API 로 로케일을 만들어 이 문안(이름·부제·설명·키워드·프로모션·릴리즈노트)을 채웠고, `LOCALES` 에 넣었다.
> Pro(평생) 인앱 구매 표시 이름도 이 언어로 더했다. 연 구독은 지금 상태에서 API 가 언어 추가를 막아 영어 이름으로 나간다.

1. **App Store Connect 웹에서 스페인어(멕시코) 로케일을 만든다.** ASC API 는 로케일을 새로 만들지 못합니다.
2. 아래 값을 채운다. 인앱 구매 표시 이름도 `es-MX` 로 더한다.
3. 로케일이 생긴 뒤 `deploy.env` 의 `LOCALES` 에 `es-MX` 를 더하고, `RELEASE_NOTES.md` 에
   절을 쓴다(5.1.7 에는 이미 있다). **순서를 지킬 것.** 로케일이 없는데 `LOCALES` 에 먼저 넣으면
   릴리즈노트 게이트가 없는 칸을 찾다가 배포를 멈춥니다.
   `RELEASE_NOTES.md` 5.1.7 의 이 언어 절 제목에서 `노출 안 함: ` 을 지운다. 로케일이 없을 때 제목을 못 알아본 DeployBar 가
   본문 글자로 판별해 라틴 문자를 `en` 으로 읽기 때문에 막아 둔 것이다.
4. 스페인어 화면을 한 번 본다. 한국어보다 1.5배 길어서 키보드 익스텐션의 좁은 버튼이 먼저 깨진다.

앱은 다음 빌드부터 스페인어로 말합니다(`i18n/config.json` · `knownRegions` · `AppLanguage.swift`).

## 용어

| 한국어 | 스페인어 | 왜 |
| --- | --- | --- |
| 단축어 | Frase | `Atajo` 는 iOS 단축어 앱(Atajos)과 겹친다. 러시아어 `Фраза` 와 같은 선택 |
| 메모 | Nota | 단축어와 다른 개념이라 따로 둔다 |
| 보관함 | Recibidos | iOS 메일이 멕시코에서 쓰는 말. `Bandeja de entrada` 는 버튼에 너무 길다 |
| 스택 | Pila | |
| 채우는 칸 | campo para llenar | 멕시코는 `llenar`, 스페인은 `rellenar` |
| `{금액}` | `{monto}` | 멕시코는 `monto`, 스페인은 `importe` |

고정값은 `i18n/glossary.json` 에 있습니다. 문안과 앱이 같은 말을 써야 합니다.

---

## 이름 · 부제

| 칸 | 값 | 자수 |
| --- | --- | --- |
| 이름 | `Clip Keyboard: Frases rápidas` | 29 |
| 부제 | `Copiar y pegar con un toque` | 27 |

브랜드는 영어·일본어처럼 `Clip Keyboard` 그대로 둡니다.

---

## 설명 (약 1960/4000자)

⚠️ "Gratis y Pro" 절은 **5.2 수익 모델**(`docs/product/FREE_USE_MODEL.md`, 100번까지 전부 무료 · 평생 Pro 와 연 구독)
   기준입니다. 다른 로케일 문안은 아직 예전 모델(10개까지 무료 · 7일 체험)이라, 5.2 를 내기 전에 함께 맞춥니다.
   연 구독이 ASC 에 아직 없으면 `o una suscripción anual` 을 뺍니다.

```
Deja de escribir lo mismo una y otra vez. Guárdalo una vez y después es un solo toque.

Guarda como frases tu CLABE, tu dirección, tu presentación o el inicio de tus correos. En WhatsApp, Mail, Safari o cualquier lugar donde puedas escribir, cambia a ClipKeyboard, toca una vez y el texto aparece en el campo.

Lo que hace

Frases: lo que guardaste se escribe tal cual. Un toque.
Plantillas: deja como campos para llenar las partes que cambian y complétalas con valores que ya guardaste.
Pilas: junta varios valores en un solo lugar y envíalos en orden, o cambia entre ellos con la flecha.
Frases seguras: protege con Face ID tu pasaporte o tu tarjeta y ábrelos solo cuando los necesites.
Portapapeles inteligente: lo que copias se ordena solo. Reconoce correos, teléfonos, direcciones, números de tarjeta e IBAN, para que los encuentres en un segundo.
Reconocimiento de texto: toma una foto de una tarjeta o un documento, pasa el dedo sobre la parte que quieres y solo ese texto se vuelve un valor.
Respaldo en iCloud: sobrevive al cambio de celular, incluidas las frases con imagen.

Antes de empezar

Es un teclado para insertar texto guardado. No reemplaza el teclado con el que escribes. Cámbiate a él cuando necesites insertar algo y luego regresa.

Privacidad

Lo que escribes se queda en tu dispositivo. Si activas el respaldo en iCloud, se guarda cifrado en tu propio iCloud. No recopilamos el contenido de tus frases y no usamos herramientas de análisis de terceros.

Gratis y Pro

Todo es gratis durante tus primeras 100 inserciones. Después, lo que ya creaste sigue funcionando igual; el límite gratuito solo aplica a lo nuevo que crees. Pro se compra una vez, o como suscripción anual, y quita todos los límites.

Funciona en iPhone y iPad. Disponible en español, inglés, coreano, japonés, alemán, francés, italiano, portugués (Brasil), chino (simplificado y tradicional), ruso, tailandés y vietnamita.

Contacto: leeo@kakao.com
Guía de uso: https://m1zz.github.io/ClipKeyboard/tutorial.html?lang=en

Términos de uso: https://m1zz.github.io/ClipKeyboard/terms.html?lang=en
```

---

## 키워드 (95/100자, 이름·부제 낱말 제외)

```
portapapeles,plantilla,autocompletar,atajos,respuestas,firma,dirección,CLABE,cuenta,macro,notas
```

`CLABE` 는 멕시코 계좌번호(18자리)라 멕시코 사람이 이런 앱을 찾을 때 실제로 떠올리는 값입니다.
`Frases`·`rápidas`·`copiar`·`pegar`·`toque` 는 이름·부제에 있어 뺐습니다.
⚠️ 기계로 고른 말입니다. 멕시코 검색어 도구(ASO)로 한 번 확인하는 편이 좋습니다.

---

## 프로모션 텍스트 (149/170자, 심사 없이 수시 변경 가능)

```
Lo que copiaste, tus frases de siempre y hasta tu CLABE, desde el teclado con un toque. Ahora en español, y puedes elegir el idioma dentro de la app.
```

---

## 로케일별 링크

| 로케일 | 개인정보 처리방침 | 지원 · 마케팅 |
| --- | --- | --- |
| es-MX | `https://m1zz.github.io/ClipKeyboard/privacy.html?lang=en` | `https://m1zz.github.io/ClipKeyboard/tutorial.html?lang=en` |

⚠️ 공개 문서 페이지에 스페인어가 없어 영어를 가리킵니다. 스페인어 페이지를 만들면 `?lang=es` 로 바꿉니다.
