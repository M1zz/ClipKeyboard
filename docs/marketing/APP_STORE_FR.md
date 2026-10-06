# 프랑스어 스토어 문안

App Store Connect 의 `fr-FR` 로케일에 넣을 값입니다.
짜임은 [`APP_STORE_DE.md`](APP_STORE_DE.md) 와 같습니다. 순서(ASC 로케일 먼저, `LOCALES` 는 그다음)를 그대로 따릅니다.
스토어에 올라가는 원본은 루트의 `APPSTORE.md` 이고, 이 문서는 왜 그 말을 골랐는지 적어 둔 기록입니다.

## 왜 프랑스어인가 (2026-10-06)

프랑스는 유럽에서 독일 다음으로 큰 App Store 시장이고, 캐나다(퀘벡)·벨기에·스위스·서아프리카까지 한 번에 닿습니다. LeeoKit 은 이미 프랑스어가 있어 의견 창과 결제 화면도 함께 번역됩니다.

## 남은 일 (사람이 해야 함)

1. App Store Connect 에서 `fr-FR` 로케일을 만들고 아래 값을 채운다. 인앱 구매 표시 이름도 더한다.
2. 로케일이 생긴 뒤 `deploy.env` 의 `LOCALES` 에 `fr-FR` 를 더한다.
   `RELEASE_NOTES.md` 5.1.7 의 이 언어 절 제목에서 `노출 안 함: ` 을 지운다.
3. 프랑스어 화면을 한 번 본다. 한국어보다 1.5배 안팎 길어서, 앱 화면의 좁은 버튼은 눈으로 봐야 한다.

## 용어

| 한국어 | 프랑스어 |
| --- | --- |
| 단축어 | Phrase |
| 메모 | Note |
| 채우는 칸 | champ à remplir |
| 스택 | Pile |

호칭은 `vous` (Apple 프랑스어와 같음).

고정값은 `i18n/glossary.json` 에 있습니다.

---

## 이름 · 부제

| 칸 | 값 | 자수 |
| --- | --- | --- |
| 이름 | `Clip Keyboard - Textes rapides` | 30 |
| 부제 | `Vos textes en un seul toucher` | 29 |

---

## 설명

```
Arrêtez de retaper toujours la même chose. Enregistrez-la une fois, ensuite un seul toucher suffit.

Gardez comme phrases vos numéros de compte, votre adresse, votre présentation ou vos débuts d’e-mail. Dans Messages, Mail, Safari et partout où vous pouvez écrire, passez à ClipKeyboard, touchez une fois, et le texte s’insère dans le champ.

Ce que fait l’app

Phrases : ce que vous avez enregistré s’insère tel quel. Un seul toucher.
Modèles : laissez les parties qui changent en champs à remplir, puis remplissez-les avec des valeurs déjà enregistrées.
Piles : plusieurs valeurs au même endroit, à envoyer dans l’ordre ou à changer avec la flèche.
Phrases sécurisées : verrouillez vos numéros de passeport et de carte avec Face ID et ouvrez-les seulement quand il le faut.
Presse-papiers intelligent : ce que vous copiez est trié pour vous. E-mails, numéros de téléphone, adresses, numéros de carte et IBAN sont reconnus, pour les retrouver en une seconde.
Reconnaissance de texte : photographiez une carte ou un document, glissez sur la partie voulue, et seul ce texte devient une valeur.
Sauvegarde iCloud : tout survit à un nouvel iPhone, phrases avec images comprises.

Bon à savoir

C’est un clavier pour insérer des textes enregistrés. Il ne remplace pas le clavier avec lequel vous écrivez. Passez-y quand vous voulez insérer quelque chose, puis revenez.

Confidentialité

Ce que vous écrivez reste sur votre appareil. Si vous activez la sauvegarde iCloud, tout est chiffré dans votre propre iCloud. Nous ne collectons pas le contenu de vos phrases et n’utilisons aucun outil d’analyse tiers.

Gratuit et Pro

Toutes les fonctions sont gratuites pour vos 100 premières insertions. Ensuite, tout ce que vous avez créé continue de fonctionner ; les limites gratuites ne concernent que les nouveaux éléments. Pro lève toutes les limites, en achat unique ou en abonnement annuel.

Pour iPhone et iPad. En français, anglais, coréen, japonais, chinois (simplifié et traditionnel), russe, espagnol, allemand, italien, portugais (Brésil), thaï et vietnamien.

Contact : leeo@kakao.com
Guide : https://m1zz.github.io/ClipKeyboard/tutorial.html?lang=en
Conditions d’utilisation : https://m1zz.github.io/ClipKeyboard/terms.html?lang=en
```

---

## 키워드 (97/100자, 이름·부제 낱말 제외)

```
presse-papiers,modèle,raccourci,réponse,signature,adresse,IBAN,notes,macro,copier,clavier,remplir
```

`IBAN` 은 유럽에서 가장 자주 붙여 넣는 값 중 하나입니다.
⚠️ 기계로 고른 말입니다. 그 나라 검색어 도구로 한 번 확인하는 편이 좋습니다.

---

## 프로모션 텍스트 (167/170자)

```
Ce que vous copiez, vos textes habituels, même votre IBAN : un toucher sur le clavier et tout est là. Maintenant en français, et la langue se choisit aussi dans l’app.
```

---

## 로케일별 링크

| 로케일 | 개인정보 처리방침 | 지원 · 마케팅 |
| --- | --- | --- |
| fr-FR | `https://m1zz.github.io/ClipKeyboard/privacy.html?lang=en` | `https://m1zz.github.io/ClipKeyboard/tutorial.html?lang=en` |

공개 문서 페이지에 이 언어가 없어 영어를 가리킵니다.
