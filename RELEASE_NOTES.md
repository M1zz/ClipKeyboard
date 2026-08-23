# ClipKeyboard Release Notes

## v5.0.1 (build 1)

### 한국어

**아낀 시간을 다시 셌어요**

5.0에서 셈을 고쳤는데, 이번에는 **너무 낮게** 잡혀 있던 걸 바로잡았습니다. 과장한 숫자만 거짓말인 게 아니에요. 지나치게 낮은 숫자는 이 앱이 하는 일을 아예 안 보이게 만듭니다.

- **한 번 쓸 때마다 적어도 2분**: 깃 토큰이 그 예였어요. 40자짜리 무작위 문자열이라 앱은 그냥 "글"로 보고 치는 시간 10초 남짓만 셌습니다. 그런데 실제로 하던 일은 깃허브를 열고, 설정으로 들어가서, 토큰을 찾거나 새로 만들고, 복사해서 돌아오는 것이었죠. 10초일 리가 없어요. 문구로 저장해 뒀다는 것 자체가 "이걸 매번 처리하기 싫다"는 뜻이라, 이제 한 번 꺼내 쓸 때마다 최소 2분은 아낀 것으로 셉니다. 재서 나온 값이 아니라 **저희가 정한 최소치**이고, 사용 기록 화면에도 그렇게 적어 뒀어요.
- **손으로 쳐 넣은 값도 갈래를 찾아냅니다**: 이게 더 큰 구멍이었어요. 값의 갈래는 클립보드나 공유 시트로 들어온 문구에만 붙어 있었습니다. "문구 추가"를 열어 계좌번호를 직접 쳐 넣으면 끝까지 갈래가 없어서, 은행 앱을 열던 값이 인사말과 똑같이 세어졌어요. 갈래를 다섯으로 나눠 놓고 정작 대부분의 문구에 갈래가 안 붙어 있었으니, 나눈 것이 통째로 죽어 있던 셈입니다. 이제 셀 때 값을 보고 알아냅니다.
- **찾아오는 시간을 실제 크기로**: 은행 앱을 여는 걸 28초로 잡고 있었어요. 콜드 스타트에 생체인증에 계좌 화면까지 이동하고 네트워크를 기다리는 걸 직접 재 보면 그 시간에 안 끝납니다. 110초로 올렸어요. 다른 앱에서 찾아오기는 12초에서 55초로, 지갑에서 실물을 꺼내 오기는 45초에서 165초로 올렸습니다. 선택하고 복사해서 돌아오는 손놀림도 8초에서 25초로 올렸어요. 손잡이 끌기는 원래 한 번에 안 맞습니다.
- **그래서 얼마나 달라지냐면**: 계좌번호 한 번이 50초에서 **2분 46초**로, 여권번호가 **3분 13초**로, 깃 토큰과 이메일과 주소는 **2분**이 됩니다.

**그래도 부풀리지는 않아요**

- **한 번의 수고를 여러 번으로 세지 않아요**: 계좌번호를 한 서식에 세 번 넣었다고 은행 앱을 세 번 연 것은 아닙니다. 같은 문구를 10분 안에 다시 쓰면 찾아오는 시간과 복사·붙여넣기 시간은 처음 한 번만 셉니다.
- **손으로 옮겨 적을 글이 아니면 그 위는 안 세요**: 5,000자짜리 문구 하나가 탭 한 번에 "20분을 아꼈다"고 찍히던 걸 고쳤어요. 아무도 그렇게 긴 글을 손으로 치지 않습니다. 어딘가에서 복사해 왔을 것이고, 그 길은 이미 따로 세고 있었어요. 치는 시간은 3분까지만 셉니다.
- **"네", "ok" 같은 건 여전히 0초예요**: 2분 밑값은 못 센 것을 채우는 것이지, 안 아낀 것을 아꼈다고 하는 게 아닙니다.

**어느 쪽이 사실이고 어느 쪽이 어림인지 밝혔어요**

이 앱이 말하는 "아낀 시간"은 **일어나지 않은 일의 소요 시간**이에요. 손으로 했을 세상은 존재한 적이 없으니 저희가 잰 적도 없습니다. 반면 "32번"은 실제로 일어났고 저희가 셌어요. 그런데 화면은 어림값을 가장 크게 띄우고 정작 확실한 것을 각주로 내리고 있었습니다.

- 영수증의 큰 숫자가 "27분"에서 **"32번"**으로 바뀌었어요. 시간은 "손으로 했다면 (어림)"으로 아래에 둡니다.
- 영수증 꼬리말에 "횟수는 실제로 센 값이고, 시간은 어림한 값이에요"를 적어 뒀어요.
- 자랑 영상 문구도 "다시 치지 않아서 아낀 시간"에서 **"이걸 손으로 했다면"**으로 바꿨습니다. 같은 숫자지만 주장하는 바가 달라요. 대신 "실제로는 단축어 32번"을 같은 크기로 올렸습니다.

**치는 속도만은 재서 씁니다**

문구를 만드실 때 그 값을 저희 편집기에 직접 쳐 넣으시죠. 그 순간이 이 앱에서 "손으로 했다면"이 **실제로 관측되는 유일한 지점**이에요. 그때 걸린 시간을 재 두었다가, 다음부터는 평균치 대신 **그 사람의 속도**로 셈합니다. 가정 하나를 관측으로 바꾼 거예요.

- 붙여넣은 건 안 셉니다. 그건 친 게 아니니까요.
- 무슨 값을 넣을지 고민하며 멈춘 시간도 안 셉니다. 그건 치는 시간이 아니에요.
- 한글은 한 글자에 자판을 두세 번 누르는 걸 감안해서 잽니다. 안 그러면 한국어 쓰는 분이 실제보다 세 배 빠른 걸로 잡혀요.
- 아직 잴 기회가 없었으면 예전 가정으로 셈하고, 사용 기록 화면이 어느 쪽인지 밝힙니다.

**셈을 고치기 전에 쓴 기록도 새 셈으로 보여요**

원장에 적힌 초는 적을 때의 셈이라, 그대로 두면 업데이트 전에 쓴 것만 옛 값으로 남습니다. 깃 토큰 한 번이 이번 주 영수증에는 10초, 전체 영수증에는 2분으로 찍히는 식이죠(전체는 원장이 없어 늘 그때그때 계산해 왔거든요). 같은 한 번이 두 금액을 가지면 둘 중 하나는 거짓말입니다. 이제 문구가 아직 있으면 지난 기록도 지금 셈으로 다시 매겨 보여줍니다. 아낀 시간은 어림값이지 장부에 적힌 돈이 아니니까요.

**내역을 더하면 위의 숫자가 나와요**

사용 기록에서 셈을 펼쳐 보면 더한 줄만 있고 뺀 줄이 없어서, 줄을 더해 보면 늘 위의 큰 숫자보다 컸습니다. 이 앱을 쓰느라 든 시간과 밑값도 각각 한 줄로 적어 뒀어요. 내역은 자랑이 아니라 근거라서, 세어 보면 맞아야 합니다.

**자랑하기가 훨씬 쉬워졌어요**

- **영수증은 보고 있던 기간 그대로**: 사용 기록에서 "이번 주"를 보다가 영수증을 뽑았는데 종이에는 이번 달이 찍혀 있는 일이 없어요. 뽑기 버튼을 누른 그 화면이 곧 그 종이입니다. 시트에는 종이 한 장만 뜨고, 고를 것이 없어요.
- **공유하기 한 번으로 어디로든**: 영수증도 영상도 단추 하나로 시스템 공유 시트가 뜹니다. 사진에 저장하든 메시지로 보내든 스토리에 올리든, 어디로 보낼지는 이미 고르신 대로예요. 앱이 특정 서비스로 가는 길을 따로 들고 있지 않습니다.
- **보내기 전에 먼저 봅니다**: "자랑할 영상 만들기"가 **"친구들에게 알리기"**가 됐어요. 누르면 영상이 먼저 뜨고, 마음에 들면 그때 보냅니다. 남에게 보여줄 물건이라면 본인이 먼저 봐야죠.

---

### English

**Time saved, counted again**

5.0 rebuilt how we count. This release fixes the fact that it was set **too low**. Inflated numbers aren't the only kind of lie: numbers that are far too low make the app's actual work invisible.

- **At least 2 minutes per use.** A git token was the giveaway. It's a 40-character random string, so the app saw "text" and counted about 10 seconds of typing. What you actually did was open GitHub, dig into settings, find or generate the token, copy it, and come back. That is not 10 seconds. Saving something as a snippet means "I don't want to deal with this every time," so every use now counts as at least 2 minutes saved. That is **a minimum we chose**, not something we measured, and the record screen says so.
- **Hand-typed values get classified too.** This was the bigger hole. A category was only attached to snippets arriving from the clipboard or share sheet. Type an account number into "Add snippet" and it never had one, so a value you opened a banking app for counted the same as a greeting. We had five categories and most snippets carried none of them, which meant the whole distinction was dead. Now we work it out at counting time.
- **Fetch times sized to reality.** Opening a banking app was counted as 28 seconds. Time yourself: cold start, biometric auth, navigating to the account screen, waiting on the network. It doesn't finish in 28 seconds, so it's now 110. Fetching from another app went from 12 to 55 seconds, and retrieving a physical document from 45 to 165. The select-copy-return handling went from 8 to 25 seconds, because drag handles never land right the first time.
- **What that changes.** One account number goes from 50 seconds to **2m46s**, a passport number to **3m13s**, and a git token, an email or an address to **2 minutes**.

**Still not inflated**

- **One effort isn't counted as several.** Pasting your account number three times into one form doesn't mean you opened the bank app three times. Reuse the same snippet within 10 minutes and the lookup and copy-paste are charged only once.
- **We stop counting where you'd have stopped typing.** A 5,000-character snippet used to read "20 minutes saved" from a single tap. Nobody types that by hand; they copy it from somewhere, and that path was already counted. Typing time now tops out at three minutes.
- **"ok" is still zero.** The 2-minute baseline fills in what we failed to measure. It doesn't claim savings that weren't there.

**We now say which part is measured and which part is a guess**

"Time saved" is the duration of something that never happened. The world where you did it by hand does not exist, so we never measured it. "32 times," on the other hand, actually happened and we counted it. Yet the screen was showing the estimate large and the certain thing as a footnote.

- The big number on a receipt changed from "27 minutes" to **"32 times."** The time sits below it, labelled "by hand, roughly."
- The receipt footer now reads "The count is measured. The time is an estimate."
- The share video caption changed from "time saved" to **"doing this by hand."** Same number, different claim. In exchange, "Actually: 32 taps" now gets the same size.

**Typing speed, at least, is measured**

When you create a snippet you type its value into our own editor. That is the one moment where "if you'd done it by hand" is **actually observable**. We time it, and from then on we count with your speed instead of an average. One assumption turned into an observation.

- Pasting doesn't count. That isn't typing.
- Neither does time spent stopped, working out what to write. That isn't typing either.
- Korean takes two or three keystrokes per character, and we account for that. Otherwise Korean typists come out three times faster than they are.
- Until we've had a chance to measure, we fall back to the old average, and the record screen tells you which one is in use.

**Uses recorded before the recount show the new numbers too**

The seconds in the ledger are whatever the formula said at the time, so leaving them alone means only pre-update uses keep the old value. One git token would print as 10 seconds on this week's receipt and 2 minutes on the all-time one, since all-time has no ledger and always recalculated. The same single use can't have two prices without one of them being a lie. Now, as long as the snippet still exists, past uses are re-priced with today's formula. Time saved is an estimate, not money in a ledger.

**The breakdown adds up**

The record screen showed only what we added, never what we subtracted, so the rows always came out larger than the headline. The time this app costs you and the baseline each get their own row now. A breakdown is evidence, not a boast, so it has to survive being checked.

**Showing it off got much easier**

- **The receipt matches what you were looking at.** Print one while viewing "This week" and you get this week, not this month. The screen you printed from *is* the slip. The sheet shows the slip and nothing else.
- **One Share button, anywhere you like.** Receipts and videos both open the system share sheet. Save to Photos, send it in a message, post it to a story: where it goes is already your choice. The app doesn't carry its own path to any particular service.
- **See it before you send it.** "Make a brag video" is now **"Tell your friends."** Tap it and the video plays first; you send it only if you like it. If it's going to other people, you should see it first.

---

## v5.0.0 (build 1)

### 한국어

**처음 오는 길을 다시 놓았어요**
- **눌러 보고 배웁니다**: 빈 칸부터 내밀지 않아요. 단축어·템플릿·콤보를 한 벌 넣어 두고, 하나씩 눌러 보게 합니다. 셋이 어떻게 다른지 설명 대신 손이 먼저 압니다.
- **넣어 둔 것은 진짜예요**: 튜토리얼이 끝나도 지우지 않아요. 그날부터 바로 쓸 수 있는 셋이 됩니다. 다 끝나면 치울지 한 번 물어봅니다.
- **직접 하나 만들어 보는 마지막 걸음**: 눌러 보는 것과 갖는 것은 다르니까요. 지금 넣을 것이 안 떠오르면 미뤄도 됩니다.
- **파형으로 다음 자리를 알려드려요**: 누를 곳마다 물결이 번집니다. 단축어 키 → 값 고르기 → 입력하기 → 보내기 순서로 손을 잡아 드려요.
- **키보드를 켤 때까지 안내합니다**: 예전에는 안내를 닫기만 해도 다시 안 떴어요. 키보드를 켜지 않으면 이 앱은 아무것도 아니라서, 켠 것이 확인될 때까지 하루에 한 번 다시 알려드립니다. "네, 켰어요"를 누르면 실제로 켜졌는지 확인해요.

**템플릿이 훨씬 쓰기 편해졌어요**
- **빈칸마다 이름이 보여요**: 빈칸이 넷인 템플릿에서 어느 줄이 무슨 값인지 헷갈리지 않아요. 칸마다 이름과 지금 고른 값을 함께 보여주고, 각 칸을 따로 구분해 그립니다.
- **넣기 전에 결과를 봅니다**: 값을 고르면 미리보기가 먼저 바뀌고, 입력하기를 눌러야 들어가요. "이 값 말고 저 값" 을 바꿔 볼 수 있습니다.
- **미리보기가 실제로 들어갈 것을 보여줘요**: 오늘 날짜처럼 자동으로 채워지는 자리는 이제 구멍이 아니라 값으로 보입니다. 내가 고른 값·알아서 채워진 값·아직 빈칸을 색으로 갈라 드려요.
- **저장된 값이 없으면 그 자리에서 만들어요**: 앱을 나갔다 올 필요가 없습니다.
- **처음부터 고를 값이 들어 있어요**: 빈 화면 대신 바로 써도 말이 되는 값이 준비돼 있습니다.

**아낀 시간을 제대로 셉니다**
- 예전에는 **치는 시간만** 셌어요. 그런데 계좌번호를 넣을 때 드는 값은 스물몇 자를 치는 6초가 아니라, 은행 앱을 열고 → 찾고 → 길게 눌러 선택하고 → 복사하고 → 돌아와서 붙여넣는 그 사이입니다.
- 그 손놀림을 전부 세도록 다시 만들었어요. 이메일 4.8초 → 16.9초, 계좌번호 30.6초 → 50.0초. 어떻게 셌는지는 사용 기록 화면에 그대로 펼쳐 둡니다.

**그거 아세요?**
- 며칠에 한 번, 아직 모르실 만한 것을 하나씩 알려드려요. 설정 > 그거 아세요? 에 다 모아 뒀고, 그만 보고 싶으면 언제든 끌 수 있습니다.
- 첫 이야기는 이거예요. **이 앱에는 서버가 없습니다.** 계좌번호도 주민등록번호도 이 폰 안에만 있고, 저희조차 볼 수 없어요. 털릴 서버가 없으니 털릴 방법도 없습니다.

**고친 것**
- **iCloud 데이터가 동의 없이 들어오던 문제**: 앱을 지웠다 깔거나 새 폰을 켜면, "나중에" 를 눌러도 이미 예전 단축어가 들어와 있었어요. 이제 그 기기에서 켜기 전에는 아무것도 당겨오지 않습니다. (맥도 같이 고쳤어요)
- **앱 이름과 아이콘이 되돌아왔어요**: 홈 화면에 다른 이름이 뜨던 것과 아이콘이 비어 있던 것을 바로잡았습니다.
- **키컬러를 주황으로**: 카테고리 색과 섞이지 않아, 눌러야 할 곳이 분명해집니다.
- 앱 안 키보드 미리보기에서 글이 **한 글자씩 흘러 들어갑니다.** 긴 걸 안 쳐도 된다는 게 눈에 보이도록.

---

### English

**The first-run path, rebuilt**
- **Learn by tapping, not by filling in blanks.** We plant a snippet, a template, and a combo, then walk you through tapping each one. Your hands learn the difference before any explanation would.
- **What we planted is real.** Nothing gets deleted when the tutorial ends, so you start with three things you can actually use. At the end we ask once whether you'd like them cleared.
- **A final step: make one of your own.** Trying is not the same as having. If nothing comes to mind, you can put it off.
- **A ripple shows you what's next.** It travels from the snippet key to picking a value, to Insert, to Send.
- **We keep asking until the keyboard is actually on.** Closing the guide used to count as done. It doesn't anymore. Tap "Yes, it's on" and we check for real.

**Templates are far easier to fill**
- **Every blank is labeled.** With four blanks you no longer have to guess which row belongs to which value. Each blank shows its name, the value you picked, and sits in its own boxed area.
- **See the result before it goes in.** Picking a value updates the preview; nothing is typed until you tap Insert, so you can try a different one.
- **The preview shows what will actually be typed.** Auto-filled blanks like today's date now show the value instead of looking like an empty hole. Your picks, auto-filled values, and empty blanks each get their own color.
- **No saved values? Create one right there.** No trip back to the app.
- **Values are ready from the start**, and they're ones you can use as-is.

**Time saved, counted honestly**
- We used to count **typing time only**. But the real cost of an account number isn't the six seconds of typing. It's opening the bank app, finding it, long-pressing to select, copying, coming back, and pasting.
- Now we count all of it. Email 4.8s → 16.9s, account number 30.6s → 50.0s. Your record screen shows exactly how we counted.

**Did you know?**
- Every few days, one thing you might not know yet. All of them live in Settings > Did you know?, and you can turn them off any time.
- The first one: **this app has no server.** Your account numbers and ID numbers live only on this phone, and even we can't see them. There's no server to breach, so there's nothing to breach.

**Fixed**
- **iCloud data arriving without your say-so.** After a reinstall or on a new phone, your old snippets showed up even if you tapped "Later". Nothing is pulled down now until you turn sync on from that device. (Fixed on Mac too.)
- **The app name and icon are back to normal.** The home screen showed the wrong name and the icon was missing.
- **A new orange key color** that doesn't blend into the category colors, so the thing to tap is obvious.
- In the in-app keyboard preview, text now **types itself in, one character at a time**, so you can see the length you didn't have to type.

---

## v4.0.1 (build 3)

### 한국어

**Mac 앱이 완전히 새로워졌어요**
- **빠른 붙여넣기 패널**: ⌃⇧V로 어디서든 메모 패널을 띄우고, 클릭하면 바로 원래 입력 중이던 곳에 붙여넣습니다. 포커스를 잃지 않아요.
- **메뉴바 검색**: 메뉴바 아이콘을 클릭하면 즉시 검색 팝오버. Fuzzy 매치, ↑↓ 방향키로 이동, ⌘1~9로 상위 9개 즉시 선택.
- **⌥Enter로 직접 붙여넣기**: Enter는 복사, ⌥Enter는 복사 후 전경 앱에 바로 ⌘V. Preferences에서 기본값을 "바로 붙여넣기"로 바꿀 수 있어요.
- **로그인 시 자동 실행**, Preferences에서 토글 한 번.
- **우클릭 컨텍스트 메뉴**, 메모 위에서 우클릭하면 복사·즐겨찾기·수정·삭제 바로 접근.
- **네이티브 Mac Preferences**: General/Shortcuts/About 탭 구성, Mac 기본 설정 창 스타일.
- **단축키 전면 재설계**, ⌃⇧V·⌃⇧M·⌃⇧N·⌃⇧H·⌃⇧B로 통일. 다른 앱과 거의 겹치지 않아요.

**iOS 리스트 화면 리뉴얼**
- **한 줄 프리뷰**, 메모 제목 아래 실제 내용이 한 줄 보여요. 보안 메모의 카드·계좌번호는 `•••• 4829`로 자동 마스킹.
- **타입별 고유 아이콘**, 이메일·URL·카드·IBAN 등 22개 타입 각각 전용 아이콘과 컬러. 스캔 속도가 확 빨라집니다.
- **시간 기반 섹션**, 방금 / 자주 쓰는 것 / 이번 주 / 더 오래. 오래된 메모가 자연스럽게 아래로 내려가요.
- **히어로 카드**, 방금 쓴 메모가 리스트 상단에 부각되어 표시.
- **상대 시간 + 사용 빈도**: "3분 전", "오늘 2번" 같은 부드러운 신호.
- **하단 툴바 재정의**: 검색과 새 메모를 주인공으로, 나머지는 ⋯ 메뉴로 정리.

**글로벌 프리랜서 기능 추가**
- **스마트 분류 확장**: 이제 IBAN(체크섬 검증), SWIFT/BIC, VAT 번호, 비트코인·이더리움·TRON 지갑 주소, PayPal.me 링크까지 자동 인식.
- **영어 템플릿 30개 내장**: 프리랜서 인트로, 견적, IBAN 인보이스, 타임존 답장, 일정 조율, 우아한 거절 등. 비원어민도 바로 꺼내 쓰도록.
- **새 템플릿 변수**: `{timezone}`, `{currency}`, `{greeting_time}` (시간대 따라 Good morning/afternoon/evening), `{date}`/`{time}` 영어 alias.

**개선 사항**
- 키보드 익스텐션 백스페이스 롱프레스 1초 이후 단어 단위 삭제로 가속.
- 리뷰 배너 좁은 화면에서 버튼 라벨 잘림 해결.
- 메모 리스트 스와이프 삭제 기능.
- iCloud 백업 안정성 개선 (CKAsset 사용, 재시도 로직, race condition 해결).
- Mac 모든 창에서 콘텐츠가 잘리는 현상 해결 (모든 창 크기 조절 가능).
- iOS 설정 화면에 Mac 앱 소개 진입점.
- Mac Catalyst 창 기본 크기 조정.

---

### English

**A brand-new Mac app**
- **Quick Paste Panel**: Press ⌃⇧V anywhere. Click a memo and it's pasted right into the text field you were typing in. Focus stays where it was.
- **Menu bar search**: Click the menu bar icon for an instant search popover. Fuzzy matching, arrow-key navigation, ⌘1~9 for top 9 picks.
- **⌥Enter for direct paste**: Enter copies, ⌥Enter copies and pastes into the frontmost app. Flip the default in Preferences.
- **Launch at login**: One toggle in Preferences.
- **Right-click context menu** (Copy, favorite, edit, delete) right on memos.
- **Native Mac Preferences**: General / Shortcuts / About tabs, built like a real Mac settings window.
- **Redesigned shortcuts**: Unified to ⌃⇧V · ⌃⇧M · ⌃⇧N · ⌃⇧H · ⌃⇧B. Very unlikely to conflict with other apps.

**iOS list refresh**
- **Single-line preview**: See what's actually in each memo at a glance. Sensitive types like cards and accounts mask to `•••• 4829` automatically.
- **Type-specific icons** (Email, URL, card, IBAN and more) 22 types with their own icon + color. Scan-friendly.
- **Time-based sections**: Just now / Frequent / This week / Older. Older items gracefully sink.
- **Hero card**: The memo you just used floats to the top.
- **Relative time + usage counts**: "3 min ago", "Used 2× today" ambient signals.
- **Bottom toolbar redesign**: Search and "+" get the spotlight. Everything else moves into a ⋯ menu.

**Built for global freelancers**
- **Smart detection expanded**: Now recognizes IBAN (with mod-97 checksum), SWIFT/BIC, VAT numbers, BTC/ETH/TRON wallets, and PayPal.me links.
- **30 English templates built in**: Client intro, rate quote, IBAN invoice, timezone auto-reply, meeting reschedule, polite decline, and more. Designed for non-native English speakers.
- **New template variables**: `{timezone}`, `{currency}`, `{greeting_time}` (Good morning/afternoon/evening based on time), plus English aliases like `{date}` and `{time}`.

**Improvements**
- Keyboard extension: hold backspace over 1s to accelerate to word-by-word deletion.
- Review banner no longer clips on narrow screens.
- Swipe-to-delete in memo list.
- iCloud backup reliability fixes (CKAsset, retry logic, race condition resolved).
- Every Mac window is now resizable, no more clipped content.
- iOS Settings now has a "Use on other devices" card introducing the Mac app.
- Mac Catalyst default window size adjusted.

---

## v4.0.0

### 한국어
- 잠금화면 위젯 - 즐겨찾기 메모를 바로 복사할 수 있습니다

### English
- Lock Screen Widget - Copy your favorite memos instantly from the lock screen
