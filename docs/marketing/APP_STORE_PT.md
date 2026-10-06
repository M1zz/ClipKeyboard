# 포르투갈어(브라질) 스토어 문안

App Store Connect 의 `pt-BR` 로케일에 넣을 값입니다.
짜임은 [`APP_STORE_DE.md`](APP_STORE_DE.md) 와 같습니다. 순서(ASC 로케일 먼저, `LOCALES` 는 그다음)를 그대로 따릅니다.
스토어에 올라가는 원본은 루트의 `APPSTORE.md` 이고, 이 문서는 왜 그 말을 골랐는지 적어 둔 기록입니다.

## 왜 포르투갈어(브라질)인가 (2026-10-06)

브라질은 남미 최대 App Store 시장이고 영어로 앱을 쓰는 비율이 낮습니다. 포르투갈(pt-PT)이 아니라 브라질을 고른 것은 사용자 수가 훨씬 많고, LeeoKit 도 pt-BR 이기 때문입니다.

## 남은 일 (사람이 해야 함)

> 2026-10-06: 1~2번은 끝났다. ASC 에 `pt-BR` 로케일을 만들어 문안을 넣었고, `LOCALES` 에 더하고 릴리즈노트 절을 노출로 바꿨다.

1. App Store Connect 에서 `pt-BR` 로케일을 만들고 아래 값을 채운다. 인앱 구매 표시 이름도 더한다.
2. 로케일이 생긴 뒤 `deploy.env` 의 `LOCALES` 에 `pt-BR` 를 더한다.
   `RELEASE_NOTES.md` 5.1.7 의 이 언어 절 제목에서 `노출 안 함: ` 을 지운다.
3. 포르투갈어(브라질) 화면을 한 번 본다. 한국어보다 1.5배 안팎 길어서, 앱 화면의 좁은 버튼은 눈으로 봐야 한다.

## 용어

| 한국어 | 포르투갈어(브라질) |
| --- | --- |
| 단축어 | Frase |
| 메모 | Nota |
| 채우는 칸 | campo para preencher |
| 스택 | Pilha |

호칭은 `você` (Apple 브라질 포르투갈어와 같음).

고정값은 `i18n/glossary.json` 에 있습니다.

---

## 이름 · 부제

| 칸 | 값 | 자수 |
| --- | --- | --- |
| 이름 | `Clip Keyboard - Frases rápidas` | 30 |
| 부제 | `Textos prontos com um toque` | 27 |

---

## 설명

```
Pare de digitar a mesma coisa de novo e de novo. Salve uma vez e depois é só um toque.

Guarde como frases os números de conta, o endereço, sua apresentação ou o começo dos e-mails que você usa sempre. No Mensagens, no Mail, no Safari e em qualquer lugar onde dá para digitar, troque para o ClipKeyboard, toque uma vez e o texto vai para o campo.

O que ele faz

Frases: o que você salvou entra exatamente como está. Um toque.
Modelos: deixe as partes que mudam como campos para preencher e complete com valores que você já salvou.
Pilhas: vários valores em um só lugar, para enviar em ordem ou trocar com a seta.
Frases protegidas: bloqueie números de passaporte e de cartão com o Face ID e abra só quando precisar.
Área de transferência inteligente: o que você copia é organizado para você. Reconhece e-mails, telefones, endereços, números de cartão e IBAN, para você achar tudo em um segundo.
Reconhecimento de texto: fotografe um cartão ou documento, passe o dedo sobre a parte que quer e só esse texto vira um valor.
Backup no iCloud: tudo continua com você ao trocar de iPhone, frases com imagem incluídas.

Bom saber

Este é um teclado para inserir textos salvos. Ele não substitui o teclado em que você digita. Troque para ele quando precisar inserir algo e depois volte.

Privacidade

O que você escreve fica no seu dispositivo. Se você ativar o backup no iCloud, ele é guardado criptografado no seu próprio iCloud. Não coletamos o conteúdo das suas frases e não usamos ferramentas de análise de terceiros.

Grátis e Pro

Todos os recursos são grátis nas primeiras 100 inserções. Depois disso, tudo o que você criou continua funcionando; os limites grátis valem só para itens novos. O Pro remove todos os limites, em compra única ou assinatura anual.

Para iPhone e iPad. Em português (Brasil), inglês, coreano, japonês, chinês (simplificado e tradicional), russo, espanhol, alemão, francês, italiano, tailandês e vietnamita.

Contato: leeo@kakao.com
Guia: https://m1zz.github.io/ClipKeyboard/tutorial.html?lang=en
Termos de uso: https://m1zz.github.io/ClipKeyboard/terms.html?lang=en
```

---

## 키워드 (90/100자, 이름·부제 낱말 제외)

```
copiar,colar,modelo,atalho,respostas,assinatura,endereço,pix,notas,macro,teclado,preencher
```

`pix` 는 브라질 사람이 가장 자주 붙여 넣는 값(Pix 키) 중 하나입니다.
⚠️ 기계로 고른 말입니다. 그 나라 검색어 도구로 한 번 확인하는 편이 좋습니다.

---

## 프로모션 텍스트 (153/170자)

```
O que você copia, seus textos de sempre e até sua chave Pix: um toque no teclado e está tudo lá. Agora em português, e o idioma também se escolhe no app.
```

---

## 로케일별 링크

| 로케일 | 개인정보 처리방침 | 지원 · 마케팅 |
| --- | --- | --- |
| pt-BR | `https://m1zz.github.io/ClipKeyboard/privacy.html?lang=en` | `https://m1zz.github.io/ClipKeyboard/tutorial.html?lang=en` |

공개 문서 페이지에 이 언어가 없어 영어를 가리킵니다.
