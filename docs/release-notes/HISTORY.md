# ClipKeyboard Release Notes

## v5.0.6 (build 1)

### 한국어

날짜와 시간을 사는 곳의 모양으로 넣습니다.

미국에서 쓰시는 분이 물으셨습니다. 날짜 빈칸을 다른 모양으로 바꿀 수 있느냐고, 미국은 월 일 년 순서로 적는다고. 지금까지 날짜는 어디서나 2026-08-31 이었고 시간은 24시간이었습니다. 손이 덜 가라고 대신 넣어 드리는 것인데 그 나라 모양이 아니면 결국 손으로 고치게 됩니다.

이제 쓰시는 언어와 사시는 지역이 모양을 정합니다. 미국은 08/31/2026 과 9:57 PM, 영국은 31/08/2026, 독일은 31.08.2026 입니다. 한국과 중국과 일본은 일부러 그대로 뒀습니다. 지금까지 넣어 온 모양이라 바꾸면 쓰시던 분의 결과가 어느 날 갑자기 달라집니다.

직접 고르실 수도 있습니다. 설정에서 단축어, 날짜 형식과 시간 형식입니다. 보기마다 오늘 날짜를 그 모양으로 그려서 보여 드립니다. MM/DD/YYYY 는 만든 사람만 읽지만 08/31/2026 은 누구나 읽습니다.

저장할 때 카테고리를 고릅니다.

말씀해 주셨습니다. 저장할 때 카테고리를 정하게 해 달라고, 기본에 저장했다가 다시 옮기는 것이 번거롭다고. 저장 화면에는 카테고리를 고르는 자리가 아예 없었습니다. 이제 본문 바로 아래에 한 줄로 서 있고, 그 자리에서 새 카테고리도 만듭니다. 만드는 길이 없으면 카테고리를 하나도 안 만든 분께는 기본 하나뿐인 고장난 칸으로 보입니다.

저장한 뒤에는 그 단축어가 보이는 자리로 데려갑니다. 예전에는 기본 탭에서 업무를 골라 저장하면 화면은 기본에 남아서, 방금 만든 것이 어디로 갔는지 보이지 않았습니다. 사라진 것처럼 보이는 것이 제일 나쁩니다. 지금 화면에서 이미 보이고 있으면 아무 데도 가지 않습니다. 잘 보이는데 화면을 또 옮기면 그것이야말로 길을 헤매게 합니다.

키보드 높이를 기본 키보드에 맞췄습니다.

높이가 기본 키보드와 달라 위화감이 든다는 이야기와, 올라올 때 높이가 한 번 튄다는 이야기가 있었습니다. 뿌리가 하나였습니다. 우리가 254 라는 숫자를 약하게 걸어 두어서, iOS 가 제 높이로 한 번 세운 뒤 우리 숫자로 끌어내리고 그 과정을 애니메이션하고 있었습니다. 그 254 에는 근거도 없었습니다. 오래전에 없앤 하단 바의 몫이 상수에 남아 있었습니다.

이제 앱이 기기의 시스템 키보드 높이를 재어 두고 키보드가 그 값으로 섭니다. 기기와 방향마다 따로 적으므로 가로로 돌려도 맞습니다. 앱을 아직 안 열어 보셨으면 화면 비율로 어림합니다.

iOS 26 은 지구본과 받아쓰기 줄을 우리 판 바깥에 직접 그립니다. 그것을 모르고 높이를 걸어서 키보드가 시스템 키보드보다 89pt 높았고, 우리 판과 아래 줄의 배경색도 갈려 있었습니다. 이제 그 줄의 몫을 빼고 세우고, 판 뒤에 시스템 재질을 깔아 두 부분이 한 장으로 이어집니다. 색은 하나가 됐습니다.

다만 시스템 키보드와 높이까지 똑같이 세웠더니 이번에는 판이 짜부라졌습니다. 계산은 맞았는데 전제가 틀렸습니다. 시스템 키보드는 그 높이를 통째로 키에 쓰지만, 우리 판은 같은 높이 안에 카테고리 줄을 먼저 얹고 남은 자리에 단축어를 깝니다. 같은 값을 받으면 우리 격자만 한 줄 넘게 굶습니다.

그래서 잰 높이는 격자가 받을 몫으로 보고, 우리에게만 있는 카테고리 줄을 그 위에 얹습니다. 시스템 키보드에 없는 것을 그리는 만큼만 높아집니다. 어떤 기기에서도 단축어 여섯 개는 들어가고, 키를 크게 쓰시는 분은 판도 함께 높아집니다. 가로에서는 화면을 덮지 않도록 위쪽에 울타리를 뒀습니다.

카테고리가 저절로 늘어나던 것을 멈췄습니다.

카테고리가 걷잡을 수 없이 불어난다는 이야기가 있었습니다. 단축어에 적힌 카테고리 이름을 앱이 사용자가 만든 카테고리로 승격시키고 있었고, 동기화가 한 바퀴 돌 때마다 자기가 올린 이름을 자기가 되받아 늘렸습니다. 기기가 하나여도 늘었습니다. 지운 카테고리를 아직 달고 있는 단축어, 다른 언어로 심긴 예시 이름, 가져오기로 들어온 아무 글자도 전부 카테고리가 됐습니다.

이제 카테고리는 직접 만드실 때만 늘어납니다. 이미 쌓인 것은 저절로 줄지 않으므로, 빈 카테고리가 많으면 한 번만 알려 드리고 카테고리 관리 화면으로 모셔다 드립니다. 앱은 아무것도 지우지 않습니다. 어느 것이 만드신 것이고 어느 것이 불어난 것인지 앱은 구분할 수 없습니다.

맥에서 카테고리 탭이 사라지던 것도 같은 뿌리였습니다. 목록을 적게 아는 기기가 자기가 아는 만큼만 올려서 공용 기록을 덮어썼습니다. 아이폰만 쓰시면 끝까지 모르고 맥에서만 사라진 것처럼 보였습니다. 이제 올리기 전에 이미 있는 목록 위에 얹습니다.

백업에서 되살릴 때 카테고리가 통째로 날아가던 것도 고쳤습니다. 카테고리 설정은 메모와 다른 자리에 살아서, 되살리는 길 셋 중 하나만 그것을 챙기고 있었습니다. 파일로 내보내고 가져오는 길에는 아예 실리지 않았고 카테고리 색은 어느 길로도 남지 않았습니다. 이제 셋 다 챙기고, 되살린 직후 화면도 새 목록으로 다시 섭니다.

목록이 번쩍이던 것을 고쳤습니다.

카테고리를 넘길 때마다 번쩍인다는 이야기를 오래 들었습니다. 눈으로 보이는 증상은 눈으로 봐야 했는데 코드만 읽고 짐작했습니다. 화면을 녹화해 프레임으로 재고서야 원인이 하나가 아니라 넷이라는 것을 알았습니다.

카드에 쓰던 유리가 뒤를 실시간으로 읽어야 해서 페이지가 지어졌다 헐리는 자리에서 튀었습니다. 화면 바닥이 카테고리 색을 0.38초에 걸쳐 쓸어 바꾸는데 페이지는 0.25초에 넘어가서, 제목과 카드는 이미 새 카테고리인데 바닥만 뒤늦게 따라오는 구간이 있었습니다. 손으로 넘긴 페이지에 애니메이션이 한 겹 더 걸려 카드가 흐려졌다 돌아왔습니다. 페이지를 미리 짓는 시점을 우리가 정하려다 빈 화면이 스쳤습니다.

전부 걷어냈습니다. 카드는 단색 면 하나가 됐고 페이지 넘기기는 시스템에 맡겼습니다. 갈래가 무엇인지는 카드 색과 좌상단 아이콘이 이미 말하고 있었습니다.

앱이 빨라졌습니다.

단축어가 500개 넘게 쌓인 기기로 재면서 고쳤습니다. 켤 때 화면이 멎던 구간이 0.1초에서 아예 없어졌고, 첫 10초 동안 앱이 쓰는 시간이 절반으로 줄었습니다.

메모 파일을 부르는 자리마다 통째로 다시 읽고 있었습니다. 목록 화면 하나에만 18곳입니다. 이제 파일이 그대로면 다시 풀지 않습니다. 몇 달 전에 끝난 옛 자료 변환을 켤 때마다 확인하느라 파일 전체를 훑던 것, 검색 화면이 화면에 들어올 때마다 전부 다시 읽던 것, 시험용 진단이 배포판에 그대로 실려 돌던 것도 함께 걷어냈습니다.

앱이 갑자기 닫히던 자리 둘을 고쳤습니다.

친구들에게 알리기 영상을 굽는 일이 전부 화면 담당에서 돌고 있었습니다. 1080x1920 짜리 102장이라 그동안 앱이 손가락에 답하지 못합니다. 공유 시트를 여신 분은 전원 그 자리를 지납니다. 이제 화면이 꼭 해야 하는 것만 남기고 나머지는 뒤로 보냈습니다. 시트를 닫으면 굽는 것도 멈춥니다. 예전에는 아무도 안 볼 영상을 끝까지 구웠습니다.

글을 쓰는 칸이 화면을 그리는 도중에 입력 자리를 옮기고 있었습니다. 그러면 화면 전체가 다시 계산되고 그 계산이 다시 같은 자리로 들어옵니다. 이제 한 박자 미뤄 그리기가 끝난 뒤에 옮깁니다.

잠근 단축어에 자물쇠가 늘 보입니다.

생체인증으로 잠근 단축어가 목록에서 보통 단축어와 겉으로 구별되지 않았습니다. 자물쇠를 구분 표시 설정이 켜져 있을 때만 그리고 있었는데 그 설정은 기본이 꺼짐입니다. 대부분의 분께 한 번도 보이지 않았다는 뜻입니다. 구분 표시는 있으면 좋은 꾸밈을 켜는 스위치이지 잠겨 있다는 사실을 감출 스위치가 아닙니다.

새 단축어 화면을 접지 않습니다.

새로 만들 때는 이름과 내용만 보이고 보안과 템플릿과 콤보와 카테고리는 더 설정하기 뒤에 접혀 있었습니다. 접어 두면 있는 줄을 모르고, 쓰려면 한 번 더 눌러야 합니다. 접어서 아끼는 자리보다 못 찾아서 잃는 것이 큽니다. 이제 만들 때도 고칠 때도 같은 화면이고, 처음부터 다 펼쳐져 있습니다.

클립보드를 훔쳐보고 갈래를 맞히던 것을 없앴습니다.

새 단축어 화면이 뜰 때마다 클립보드를 읽어서 이건 이메일 같은데요 하고 물었습니다. 맞혀서 얻는 것이 붙여넣기 한 번뿐이었습니다. 이제 묻지 않습니다. 붙여넣기는 붙여넣을 내용 옆에 단추로 서 있고, 그 단추는 시스템이 대신 처리하므로 붙여넣기를 허용하겠느냐고 묻지도 않습니다.

그 밖에

팁과 안내 줄이 툭 사라지지 않고 닫기 단추 자리로 접힙니다. 누른 것과 사라진 것이 이어집니다.

혹시 이런 분이신가요 판에서 기본으로 권하는 일반과 개인이 맨 위로 올라왔습니다. 처음 여시는 분이 자기와 상관없는 것부터 읽고 내려가야 했습니다.

### English

Dates and times now look the way they look where you live.

Someone in the US asked whether the date placeholder could come out in another shape, since the US writes month, day, year. Until now a date was 2026-08-31 everywhere and a time was 24-hour. The point of filling it in for you is that you do not have to type it, and if it is not the shape your country uses, you end up fixing it by hand anyway.

Now your language and your region decide the shape. The US gets 08/31/2026 and 9:57 PM, the UK gets 31/08/2026, Germany gets 31.08.2026. Korea, China and Japan are deliberately unchanged. That is the shape they have been getting all along, and changing it would mean their results suddenly look different one day.

You can also pick it yourself, in Settings under Snippets, Date format and Time format. Every choice draws today's date in that shape. MM/DD/YYYY is readable to the person who wrote it; 08/31/2026 is readable to everyone.

Pick a category while you save.

You told us: let me set the category as I save, moving it out of Basic afterwards is a chore. The save screen had no way to choose a category at all. It is now one row right under the body, and you can create a new category from there. Without that, someone who has not made any category yet just sees a broken control with Basic in it.

After saving, the list takes you to where that snippet is visible. Before, if you were on the Basic tab and saved into Work, the screen stayed on Basic and you could not see where the thing you just made had gone. Looking like it vanished is the worst outcome. If it is already visible where you are, nothing moves. Moving the screen when you can already see it is what actually makes you lose your place.

The keyboard is the height of the system keyboard now.

Two reports had one root: the height feels off compared to the default keyboard, and the height jumps once as it comes up. We were pinning the number 254 weakly, so iOS stood the keyboard at its own height first, pulled it down to ours, and animated the trip. And 254 had no basis. It still carried the share of a bottom bar we removed long ago.

Now the app measures your device's system keyboard height and the keyboard stands at that value, recorded per device and per orientation, so landscape is right too. If you have not opened the app yet, we estimate from the screen.

iOS 26 draws the globe and dictation row outside our panel. Not knowing that, we stood 89pt taller than the system keyboard and the panel's background color did not match the row below it. Now we stand without that row's share and lay the system material behind the panel, so the two read as one surface. The color is one color.

Matching the system keyboard's height exactly, though, left our panel squashed. The arithmetic was right and the premise was wrong. The system keyboard spends that whole height on keys; ours puts the category row in first and lays snippets in what is left. Given the same number, only our grid goes hungry, by more than a row.

So the measured height is now treated as the grid's share, and the category row we alone draw sits on top of it. We are taller than the system keyboard by exactly what the system keyboard does not draw. Six snippets fit on any device, and if you use large keys the panel grows with them. In landscape there is a ceiling so the keyboard never takes over the screen.

Categories no longer multiply on their own.

Categories were growing out of hand. The app was promoting whatever category name a snippet carried into your list of categories, and sync fed each name back to the device that had just sent it. It grew even with a single device. A snippet still tagged with a category you deleted, a sample name planted in another language, any string that arrived through an import: all of it became a category.

Categories now grow only when you make one. What has already piled up will not shrink by itself, so if you have many empty categories we say so once and take you to category management. The app deletes nothing. It cannot tell which ones you made from which ones multiplied.

Category tabs disappearing on the Mac had the same root. A device that knew fewer categories uploaded only what it knew and overwrote the shared record. If you only use an iPhone you never saw it; it only looked like a loss on the Mac. Uploads are now laid on top of what is already there.

Categories vanishing on restore is fixed too. Category settings live somewhere other than your snippets, and only one of the three restore paths was carrying them. Export and import to a file did not carry them at all, and category colors survived none of the paths. All three carry them now, and the screen redraws with the restored list instead of holding the old one.

The list does not flash anymore.

We heard for a long time that swiping between categories flashed. A symptom you can see has to be looked at, and we kept reading code and guessing instead. Only after recording the screen and measuring it frame by frame did we find that it was not one cause but four.

The glass on the cards had to read what was behind it in real time, so it broke wherever pages were being built and torn down. The background swept to the new category color over 0.38 seconds while the page finished in 0.25, leaving a stretch where the title and cards were already the new category and only the floor was late. A page you moved with your finger got a second animation on top, fading the cards out and back. And deciding ourselves when to build the next page let an empty one slip through.

All of it is gone. A card is a single flat surface, and paging is left to the system. Which kind a snippet is was already being said by the card color and the icon in its corner.

The app is faster.

Measured and fixed on a device with over 500 snippets. The stall at launch went from about a tenth of a second to none, and the work the app does in its first ten seconds is down by half.

The snippet file was being read and parsed in full at every place that asked for it, and the list screen alone asks in 18 places. Now, if the file has not changed, it is not parsed again. We also removed a check for an old data conversion that finished months ago yet scanned the whole file at every launch, a search screen that reloaded everything each time it came back on screen, and a diagnostic meant for testing that was still running in shipped builds.

Two places where the app could close on its own are fixed.

Rendering the share-your-time video was running entirely on the part of the app that draws the screen, 102 frames at 1080x1920, so the app could not answer your finger while it worked, and everyone who opened the share sheet went through it. Only what must happen on screen stays there now. Closing the sheet stops the render; before, it finished a video nobody would see.

The text field was moving the input focus in the middle of drawing the screen, which makes the whole screen recalculate and lands right back in the same place. It now waits a beat and moves after the drawing is done.

Locked snippets always show their lock.

A snippet locked behind Face ID looked exactly like any other in the list. The lock was only drawn when the Distinguish setting was on, and that setting is off by default, which means most people never saw it. Distinguish is a switch for nice-to-have decoration, not a switch that hides the fact that something is locked.

The new-snippet screen is no longer folded up.

Making a new one showed you a name and a body, and hid security, templates, combos and category behind "More options". Folded away, you do not know it is there, and using it costs another tap. What folding saves in space it loses in things nobody finds. Making and editing are now the same screen, open from the start.

We stopped peeking at your clipboard to guess what it was.

Every time the new-snippet screen opened, it read the clipboard and asked "this looks like an email, want it?". All that guessing bought was one paste. It does not ask anymore. Pasting is a button beside the content field, and the system handles it, so it does not ask permission either.

Also

Tips and notices fold into their close button instead of blinking out, so pressing X and the thing leaving are one motion.

In the "does this sound like you?" panel, General and Personal, the one we recommend by default, is at the top. People opening it for the first time had to read past the ones that had nothing to do with them.

## v5.0.5 (build 1)

### 한국어

중국어를 넣었습니다

한 분이 물으셨습니다. 중국어를 지원해 줄 수 있느냐고. 넣었습니다. 간체와 번체 두 벌이고, 앱의 모든 화면과 키보드가 중국어로 서고 앱 이름도 함께 바뀝니다.

번체는 글자만 바꾼 것이 아닙니다. 剪贴板을 剪貼簿로, 設置를 設定으로 적고 인용부호도 그쪽에서 쓰는 것으로 적습니다. 글자만 바꾸면 대만에서 읽는 분에게는 남의 나라 말이 그대로 남습니다. 예시의 은행과 주소와 결제 수단도 그 지역의 것으로 바꿨습니다.

기기 언어와 읽고 싶은 언어가 다른 분을 위해 설정에 언어를 뒀습니다. 고르는 즉시 바뀌고 앱을 껐다 켜지 않아도 됩니다. 키보드는 다음에 열 때부터 같은 언어로 섭니다.

키보드 안에서 문구 순서를 바꿉니다

저장한 순서대로만 서 있어서 자주 쓰는 것이 뒤에 있었습니다. 앱에는 순서 바꾸기가 있었지만 문구를 실제로 고르는 자리는 키보드입니다. 순서를 고치려고 앱까지 다녀와야 하면 대개 안 고칩니다. 이제 키보드 안에서 바로 옮깁니다. 보이는 것 전체를 한 줄로 늘어놓고 옮기기 때문에 1번 페이지의 것을 2번 페이지 맨 위로 보낼 수 있습니다. 손을 뗄 때마다 적어 두므로 옮겨 놓고 다른 앱으로 넘어가도 그대로 남습니다.

빈칸 이름을 바꾸고, 안 쓰는 빈칸을 지웁니다

한 분이 알려 주셨습니다. 빈칸 관리에서 값은 하나씩 지울 수 있는데 빈칸 자체는 못 지운다고, 안 쓰는 이름이 쌓여 목록이 지저분해진다고. 맞는 말이었습니다.

이름을 바꾸면 그 이름을 쓰는 단축어의 내용도 함께 바뀝니다. 내용에 옛 이름을 둔 채 이름만 바꾸면 바꾼 빈칸이 그 자리에서 미아가 되고 단축어들은 여전히 옛 이름을 가리킵니다. 저장해 두신 글을 고치는 일이라 몇 개가 바뀌는지 누르기 전에 먼저 보여 드립니다.

지우기는 쓰는 단축어가 하나도 없는 빈칸에만 나옵니다. 쓰는 곳이 있는 빈칸은 지워도 다음에 내용을 읽을 때 되살아납니다. 눌러도 지워지지 않는 삭제 버튼을 내놓느니 아예 보여 드리지 않기로 했습니다.

단축어를 만들다 앱이 죽던 것을 고쳤습니다

같은 분이 알려 주셨습니다. 이어지는 단계를 하나 지우는 순간이었고, 화면이 방금 사라진 칸의 번호를 한 번 더 읽으면서 죽었습니다. 가끔인 이유는 화면이 다시 그려지는 시점에 달려 있었기 때문입니다.

의견을 보내실 때 답장 받을 자리를 뒀습니다. 이름과 이메일 둘 다 선택이고, 적어 주시면 다음에는 자동으로 채워 드립니다. 그 값은 이 기기에만 저장됩니다.

별점은 키보드에서 한 번이라도 붙여넣어 보신 뒤에 여쭙니다. 만들어만 두고 키보드는 아직 못 켜신 분께 별점을 물으면 답은 정해져 있습니다.

### English

Chinese is in, both Simplified and Traditional. Every screen and the keyboard speak Chinese, and the app name changes with them. Traditional is not just the characters swapped: it says the words Taiwan uses and quotes the way Taiwan quotes, and the banks, addresses and payment methods in the examples were changed to local ones. For people whose device language and reading language differ, there is now a language setting that takes effect the moment you pick it.

You can reorder snippets from inside the keyboard. They stood in the order you saved them, so the ones you use most ended up at the back. The app had reordering, but the place you actually pick a snippet is the keyboard, and if fixing the order means a trip back to the app, most people never fix it. Everything visible is laid out in a single line while you move, so page one can go to the top of page two, and each move is written down as you let go.

You can rename a blank, and delete the ones no snippet uses. Renaming changes the name inside every snippet that uses it, and because that edits text you wrote, we show how many snippets will change before you commit. Delete only appears on blanks nothing uses: one still in use would come back the next time we read your text.

Fixed a crash while making a snippet. Removing one of the follow up steps made the screen read the number of the row that had just disappeared, one more time.

Feedback now takes a name and email to reply to, both optional and stored on your device only. And we ask for a rating only after you have pasted from the keyboard at least once.

### 안에서 무슨 일이었나

크래시는 `MemoAdd` 가 `ForEach(continuations.indices, id: \.self)` 로 돌면서 그 인덱스로 배열에 바인딩을 건 것이었다. 한 칸을 지우면 SwiftUI 가 아직 살아 있는 옛 인덱스로 바인딩을 한 번 더 읽는다. 단계마다 id 를 갖는 `ContinuationStep` 으로 바꿨다.

빈칸을 지울 때 지워야 할 자리가 셋이다. App Group 의 값, 표준 UserDefaults 의 옛 값, 그리고 단축어에 붙어 있는 사본. 사본을 남기면 키보드가 폴백으로 읽어 되살린다. 이름 바꾸기는 여기에 본문과 `templateVariables` 까지 넷이다.

번체는 손으로 관리하지 않는다. `scripts/make_zh_hant.py` 가 간체에서 다시 뽑는다. ICU 는 글자만 바꿔서 대륙 어휘가 남으므로 `scripts/zh_hant_vocab.py` 의 표가 대만 말과 인용부호를 맡는다. 자세한 것은 `5.0.5.md` 의 배포 메모에 있다.

## v5.0.4 (build 1)

### 한국어

아낀 시간을 다른 것에 빗대어 보여줍니다

친구들에게 알리기로 만드는 영상에서 큰 자리에 서던 것이 아낀 시간이었습니다. 그런데 시간은 크기가 잡히지 않는 단위입니다. 한 시간 반을 아꼈다는 말을 읽고 그게 큰지 작은지 알려면 머릿속에서 한 번 더 환산해야 하는데, 남의 스토리에서 넘겨 보는 3초 안에 그 환산은 일어나지 않습니다.

이제 큰 자리에는 환산이 끝난 것이 섭니다. 12.5km 달릴 수 있는 시간, 드라마 여덟 편, 책 세 권, 마라톤 네 번, 최저임금으로 쳐도 커피 열두 잔. 열 가지 중에서 열 때마다 다른 것이 뽑히고, 다른 걸로 버튼으로 굴려 볼 수 있습니다.

갈래마다 아래 문턱과 위 천장이 함께 있습니다. 천장이 없던 첫 판에서는 오래 쓴 분에게 라면 1,218봉지, 지하철 4,250정거장이 나왔습니다. 그건 자랑이 아니라 농담으로 읽힙니다. 머릿속에 그려지지 않는 숫자는 크기를 전달하지 못할 뿐 아니라, 아래 작은 줄의 진짜 횟수까지 같이 못 믿게 만듭니다.

돈으로 셈하는 것은 사는 나라의 최저임금과 물건값으로 합니다. 금액을 그대로 적지 않고 커피 잔 수로 바꾸는 데는 이유가 있습니다. 금액은 해마다 조금씩 틀려지지만 잔 수는 오래 버팁니다. 최저임금과 커피값이 대체로 같이 오르기 때문입니다. 우리가 쓰는 것은 두 값의 비율이고, 비율은 물가를 타지 않습니다. 그래도 표가 3년 넘게 낡거나 사는 곳이 표에 없으면 그 갈래는 통째로 빠집니다. 낡은 값을 계속 내보내느니 접는 편이 낫습니다.

최저임금은 내 시간값이 아니라 바닥값입니다. 그래서 그 시간에 일했으면 얼마라고 적지 않고 최저임금으로 쳐도라고 적습니다. 같은 숫자가 하한선이 되면서 더 세집니다.

아낀 시간과 실제 횟수는 사라지지 않고 아래에 작게 남습니다. 큰 글씨는 어림한 것이고 그 줄만 실제로 센 것이라, 어림한 숫자만 있는 그림은 자랑이 아니라 광고가 됩니다.

사용 기록 화면의 카드 두 장을 한 장으로 합쳤습니다

세 시간을 벌었다는 축하 카드와, 그 아래 다시 치지 않은 횟수 카드가 위아래로 나란히 서서 같은 말을 두 번 하고 있었습니다. 하나는 세 시간을 벌었어요, 하나는 대략 3시간을 아꼈어요. 이제 한 장입니다. 축하할 일이 있는 날에는 그 카드가 물듭니다.

빗대는 줄은 눌러서 바꿉니다. 영화 한 편이 안 와닿으면 눌러 보세요. 30km 달릴 수 있는 시간, 드라마 네 편, 책 135쪽, 최저임금으로 쳐도 커피 일곱 잔으로 바뀝니다. 크기를 잡아 주려고 둔 줄인데 한 가지 자로만 재면 그 자를 모르는 사람은 여전히 크기를 못 잡습니다. 무작위가 아니라 순서대로 넘어갑니다. 무작위로 뽑으면 눌렀는데 같은 것이 다시 나오고, 그건 안 눌린 것과 구별되지 않습니다.

체크 도장은 언제나 연두입니다. 축하 카드의 도장만 혼자 키 컬러를 따라가고 있었습니다. 이 앱에서 됐다는 말은 사람이 고르는 색이 아닙니다.

키보드에서 어떤 키는 눌러도 아무 일이 없었습니다

그 키가 고장 난 것이 아니라, 옆에 있던 이미지 단축어가 그 위를 덮고 있었습니다. 가로로 긴 사진을 담은 단축어는 자기 칸보다 넓게 누워 있었습니다. 사진이 칸을 채울 때까지 커지는데 폭을 붙잡아 두는 것이 없어서, 넘친 만큼이 옆 칸으로 흘러 들어갔습니다.

눈에는 사진이 반듯하게 잘려 보였습니다. 자르는 것은 그림만 자르고 손가락이 닿는 자리는 그대로 두기 때문입니다. 그래서 옆 키를 눌러도 손가락은 사진에 닿고 있었고, 옆 키는 고장 난 것처럼 보였습니다.

파노라마나 잘라낸 화면처럼 아주 긴 사진이면 옆 키가 통째로 가려졌습니다. 영수증이나 명함처럼 조금 긴 사진이면 옆 키의 한쪽 끝만 안 눌렸습니다. 사진이 세로거나 정사각이면 아무 일도 없었습니다. 키를 몇 줄로 놓았는지, 키 높이를 얼마로 두었는지에 따라서도 갈렸습니다. 어떤 분에게는 늘 그랬고 어떤 분에게는 한 번도 없었던 이유가 이것입니다.

이제 사진이 아무리 길어도 키는 자기 칸 안에 머뭅니다. 옆 키는 옆 키가 됩니다. 이미지 단축어의 둥근 모서리도 이제 눌립니다. 예전에는 네 귀퉁이가 손가락을 받지 않는 죽은 자리였습니다.

### English

Your saved time, said in something you can picture

The video you share used to put the saved time itself in the big type. Time is a unit you cannot size up. Reading that you saved an hour and a half tells you nothing about whether that is a lot until you convert it in your head, and nobody does that in the three seconds a story gets.

Now the big type holds the conversion already done. Far enough to run 12.5km. Eight episodes. Three books. Four marathons. Twelve cups of coffee, even at minimum wage. Ten of them, a different one each time you open it, with a Try another button.

Every one has a floor and a ceiling. Without the ceiling, a long time user got 1,218 packs of instant noodles and 4,250 subway stops. That reads as a joke, not a brag. A number you cannot picture fails to convey size, and it takes the real count on the small line down with it.

The ones counted in money use the minimum wage and prices where you live. There is a reason we say cups instead of an amount: an amount drifts wrong a little every year, and a cup count holds far longer, because minimum wage and the price of coffee move together. What we use is the ratio, and ratios do not track inflation. Even so, if the table is more than three years old or we have no prices for where you are, that whole group drops out.

Minimum wage is not what your time is worth, it is the floor. So we do not say what you would have earned, we say even at minimum wage. The same number gets stronger as a lower bound.

The saved time and the real count stay, small, underneath. The big number is an estimate and that line is the part we actually counted. A picture with nothing but estimates on it is not a brag, it is an ad.

Two cards on the usage screen became one

A card saying you had earned three hours sat right above a card saying you had saved about three hours. The same sentence, twice, one under the other. It is one card now, and it takes on color on a day worth celebrating.

The comparison line changes when you tap it. If a movie does not land for you, tap. Far enough to run 30km. Four episodes. 135 pages. Seven cups of coffee, even at minimum wage. A line meant to give you a sense of scale fails at that job if it only ever measures with one ruler. It steps through them in order rather than at random: pick at random and a tap can land on what was already there, which is indistinguishable from the tap not registering.

The check seal is always yellow green. The one on the old celebration card was the only place still following the key color. In this app, saying yes is not a color anyone picks.

Some keys on the keyboard did nothing when tapped

The key was not broken. An image snippet beside it was lying on top of it. A snippet holding a wide photo was laid out wider than its own cell. The photo grows until it covers the cell, and nothing was holding its width, so the overflow spilled into the cell next door.

On screen the photo still looked neatly cropped, because cropping trims the picture and leaves the touch area where it was. Tapping the key beside it meant putting your finger on the photo, and that key looked broken.

With a very wide photo, a panorama or a cropped screenshot, the neighboring key was covered entirely. With a mildly wide one, a receipt or a business card, only one edge of it went dead. A portrait or square photo did nothing at all. How many columns of keys you use and how tall you set them changed it too. That is why this happened constantly to some people and never to others.

Now the key stays inside its own cell no matter how long the photo is. The key next door is the key next door again. The rounded corners of an image snippet key now respond as well. They used to be dead spots that would not take a finger.

### 안에서 무슨 일이었나

`ImageMemoButton` 이 `scaledToFill` 한 사진에 높이만 걸고 폭은 걸지 않았다. 그 사진이 `ZStack` 의 폭을 정해 버려서 키가 `LazyVGrid` 셀을 넘었다. `clipShape` 는 그림만 자르고 배치와 히트 테스트는 그대로 둔다. 실측하면 5:1 파노라마가 65.8pt 칸에 225.3pt 로 눕는다.

사진을 `overlay` 로 옮겼다. `overlay` 의 자식은 부모 크기를 제안받고 자기 크기는 부모 배치에 영향을 주지 않는다. 자세한 것은 `5.0.4.md` 의 배포 메모에 있다.

## v5.0.3 (build 1)

### 한국어

누를 곳의 색을 직접 고릅니다

설정 안에 키 컬러가 생겼습니다. 기본색, 먹, 테라코타, 쪽, 솔, 자두, 노을 일곱 가지 중에서 고르면 앱과 키보드가 함께 그 색으로 바뀝니다. 고르는 화면 아래에 실제 카드와 버튼이 놓여 있어서, 색을 누르는 순간 내 화면이 어떻게 되는지 바로 보입니다.

기본값은 아이폰이 쓰는 그 파랑입니다. 값을 적어 두지 않고 시스템에서 받아 오기 때문에, 애플이 그 파랑을 손보면 이 앱도 같이 따라갑니다. 이 앱은 남의 앱 안에 키보드로 올라가 있는 시간이 대부분이라, 어느 앱에서 왔는지 티가 나지 않는 편이 낫습니다. 예전 주황을 그대로 쓰고 싶으면 테라코타를 고르면 되고, 색을 아예 빼고 싶으면 먹이 있습니다.

화면 전체의 색조도 함께 손봤습니다. 배경과 글자에 옅게 섞여 있던 노란 기를 걷어내고 중립색으로 세웠습니다. 삭제와 저장과 주의를 알리는 빨강, 초록, 노랑은 그대로 남겼습니다. 그건 취향이 아니라 신호라서 색이 사라지면 안 됩니다. 갈래를 알리는 카테고리 색도 그대로입니다.

체크 표시는 언제나 연두입니다

무엇을 골랐는지, 무엇이 끝났는지 알리는 표시까지 키 컬러를 따라가면 자두를 고른 사람에게는 자주색 체크가, 먹을 고른 사람에게는 검은 체크가 뜹니다. 골랐다는 말은 원래 자기 색을 갖고 있습니다. 체크만은 키 컬러에서 떼어 냈습니다.

키보드가 몇 가지를 스스로 배웁니다

`{커서}` 와 `{빈칸}` 은 이 앱에서 쓸모가 가장 큰데, 문법을 알아야 존재를 압니다. 알려 주는 방식은 설정을 뒤져 볼 몇 명에게만 닿습니다. 그래서 알려 주는 대신, 이미 그 일을 손으로 하고 있는 사람에게만 말을 겁니다.

넣고 나서 매번 같은 자리로 커서를 옮겨 이어 쓰면, 세 번째부터 앱이 커서를 그 자리에 세웁니다. 배운 값은 본문이 아니라 따로 둡니다. 본문에 토큰을 꽂아 넣으면 사용자가 안 쓴 글자가 자기 단축어에 박히고, 맥으로 동기화되면 거기서도 보이고, 되돌리려면 손으로 지워야 합니다. 본문 밖에 두면 셋 다 없고 끄는 것도 값 하나 지우면 끝입니다. 본문이 바뀌면 배운 값을 버립니다. 틀린 자동화는 없는 것만 못합니다.

넣고 나서 매번 같은 자리를 고치면 갈래가 셋이고 셋 다 다른 답이 필요합니다. 같은 자리에 다른 값이면 그 자리는 빈칸이니 템플릿으로 만들지 묻습니다. 같은 자리에 같은 값이면 저장해 둔 글이 낡은 것이니 그 값으로 바꿀지 묻습니다. 자리가 매번 다르면 그냥 딴 글을 쓴 것이라 아무 말도 하지 않습니다. 세 번째가 제일 중요합니다. 여기서 말을 걸면 그때부터 잔소리가 됩니다.

한 번에 정리하기를 찾아오게 하지 않습니다

대량 가져오기는 단축어 목록의 더하기 안에 있습니다. 안내 문구가 위치를 말로 알려 줘야 한다는 것 자체가 자리가 틀렸다는 뜻입니다. 자리를 옮기는 대신 필요한 순간 셋에 각각 내놓습니다. 여러 줄을 붙여넣는 중일 때, 아직 단축어가 몇 개 없을 때, 손으로 줄줄이 만들고 있을 때. 첫 번째가 압도적으로 진하고 나머지 둘은 추측이라 문턱을 높였습니다. 한 번 물리면 다시 묻지 않습니다.

남에게 보여주는 그림도 다시 그렸습니다

아낀 시간을 담은 영상은 모래빛 베이지(#EED2A7) 한 장으로 고정돼 있었습니다. 그 색은 앱 어디에도 없어서 남의 스토리에 올라갔을 때 이 앱의 그림으로 안 읽혔고, 흰 시계를 얹으려니 바탕이 탁해야만 했습니다. 흰 바탕으로 바꾸고, 시계는 키 컬러로, 배지의 체크는 연두로 나눠 칠했습니다. 환급 영수증의 누런 종이빛과 짙은 청록도 같은 이유로 걷어냈습니다.

다크 모드를 따릅니다. 예전에는 일부러 안 따랐습니다. 만든 사람이 다크였다는 이유로 어두운 그림이 나가면 안 된다고 봤습니다. 뒤집었습니다. 자기 화면에서 본 그대로 나가는 쪽이 놀랄 일이 없습니다.

두 그림 다 ImageRenderer 로 굽는데, 이건 화면 밝기와 무관하게 라이트 트레이트로 그립니다. 동적 색을 그대로 쓰면 어두운 화면에서 뽑은 그림만 혼자 밝게 나옵니다. 밝기를 밖에서 넣어 주도록 고쳤습니다. 구워 놓고 눈으로 보기 전에는 안 보이는 종류의 어긋남이었습니다.

콤보를 배우는 자리를 다시 만들었습니다

콤보는 한 번 눌러서는 값 하나가 들어갈 뿐이라 보통 단축어와 똑같이 생겼고, 값을 여러 개 갖고 있다는 사실이 화면 어디에도 나타나지 않았습니다. 이제 다섯 걸음으로 데려갑니다. 키의 왼쪽을 눌러 값을 넣고, 보내고, 오른쪽 화살표로 다음 값으로 넘기고, 다시 넣고, 다시 보냅니다. 서로 다른 값 두 개가 나란히 올라온 것을 보고 나서 한 번 짚어 드립니다.

이 탭에 화면이 둘이라는 것

카드 목록과 키보드 화면을 오가는 방법을 아무도 알려 주지 않았습니다. 무대에서 시작한 분은 자기 목록이 어디 있는지 모른 채로 남고, 목록에서 시작한 분은 키보드 화면을 아예 못 봤습니다. 다 배우고 나면 한 번만 짚어 드립니다. 머리말의 단추와 아래 키보드 탭을 한 번 더 누르는 것, 두 길을 같이 적었습니다.

기다리는 시간과 없앤 화면

장과 장 사이에 기다리던 5초를 3초로 줄였고, 그 동그라미를 누르면 곧바로 넘어갑니다. 예전에는 눌러도 아무 일이 없어서 앱이 굳은 것처럼 보였습니다.

붙여넣기 연습 화면은 통째로 뺐습니다. 카드를 누른 순간 값은 이미 들어간 뒤라, 같은 값을 한 번 더 붙여넣어 보라고 전체 화면으로 막아서는 화면이었습니다.

템플릿을 배우는 자리에서 빈칸을 채우고 넣기를 누르면, 시트가 내려간 뒤에 키가 한 번 더 물결치다 꺼졌습니다. 다 끝난 걸음이 다시 빛나서 아직 저기를 눌러야 하나로 읽혔습니다. 이제 곧바로 보내기로 옮겨 붙습니다.

빈칸 버튼 줄을 접었습니다

단축어를 만들 때 내용 칸에 커서가 닿는 순간 파란 버튼 아홉 개가 통째로 올라왔습니다. 대부분은 그냥 글을 적으러 온 분이라, 그 줄은 도움이 아니라 이걸 다 골라야 하나라는 물음이었습니다. 이제 쓸 때 채우는 칸 줄을 눌러야 펼쳐집니다. 한 번 펼치면 그대로 남습니다.

### English

Pick the color of what you tap

Settings now has a Key color. Choose from seven, and the app and the keyboard both switch to it. A real card and a real button sit under the swatches, so you see what your screen becomes the moment you tap a color.

The default is the blue iPhone itself uses, read from the system rather than written down, so it follows along if Apple ever adjusts it. This app spends most of its life as a keyboard inside someone else's app, so it is better when nothing gives away which app it came from. If you want the old orange, pick Terracotta. If you want no color at all, there is Ink.

The rest of the palette was reset with it. The faint yellow cast in backgrounds and text is gone, replaced by a neutral gray. Red, green and yellow stay exactly as they were. Those are signals, not taste, and a delete button must never look like a save button. Category colors stay too.

Checkmarks are always yellow green

If the mark that says picked or done followed your key color, someone who chose Plum would get a purple checkmark and someone who chose Ink would get a black one. Saying yes has a color of its own, so checkmarks were taken off the key color entirely.

The keyboard learns a few things on its own

Cursor tokens and fill in blanks are the most useful things this app has, and both require knowing a brace syntax to even discover. Telling people reaches only the few who read settings. So instead of telling, we speak only to people already doing the work by hand.

If you keep moving the cursor to the same spot after inserting and typing from there, the app places the cursor there for you from the third time on. What it learns is kept outside your text. Injecting a token into the body would put characters the user never typed into their own snippet, show up on the Mac after syncing, and require deleting by hand to undo. Kept outside, none of that happens and turning it off is deleting one value. If the body changes, what was learned is discarded. Automation that is wrong is worse than none.

Corrections after inserting come in three kinds, and each needs a different answer. Same spot, different value each time means that spot is a blank, so we offer to make it a template. Same spot, same value means the saved text is out of date, so we offer to update it. A different spot each time just means you wrote something else, so we say nothing. The third case matters most: speak there and it becomes nagging.

Bulk import comes to you

Bulk import lives inside the plus button on the snippets list. Needing a sentence to explain where it is means the placement is wrong. Rather than move it, it now appears at three moments: while you are pasting several lines, when you still have very few snippets, and when you are creating several by hand in a row. The first is by far the strongest signal; the other two are guesses, so their thresholds are higher and declining once means never asking again.

The pictures you share were redrawn

The saved time video was fixed to a single sand beige (#EED2A7). That color appears nowhere in the app, so on someone's story it did not read as this app, and the white clock on it only worked because the ground was muddy. The ground is white now, the clock carries your key color, and the badge check is yellow green. The refund receipt lost its yellowed paper and dark teal for the same reason.

Both follow dark mode now. They deliberately did not before: it seemed wrong to export a dark picture just because the author happened to be in dark mode. That is reversed. What leaves should look like what you saw.

Both are baked with ImageRenderer, which draws in the light trait regardless of the screen. Using a dynamic color there means a picture exported from a dark screen comes out light on its own. Brightness is now passed in explicitly. This is the kind of mismatch you cannot see until you bake one and look at it.

Combos are taught properly now

Tapped once, a combo inserts a single value and looks exactly like an ordinary snippet, so nothing on screen said it was holding several. The tutorial now walks five steps. Tap the left side of the key to insert a value, send it, tap the arrow on the right to switch to the next value, insert again, send again. Then we name what you just saw.

This tab has two screens

Nothing had ever explained how to move between the card list and the keyboard. Anyone who started on the keyboard never found their own list, and anyone who started on the list never saw the keyboard screen. Once you finish learning, we point it out once, and we name both routes: the button in the header, and tapping the Keyboard tab again.

Waiting, and a screen we removed

The pause between tutorial chapters is down from five seconds to three, and tapping the countdown skips it. It used to do nothing when tapped, which reads as a frozen app.

The paste practice screen is gone entirely. The value is already in place the moment you tap a card, so a full screen asking you to paste the same thing again was asking you to redo what you had just done.

In the template chapter, filling in the blank and tapping Insert used to leave the key rippling for another moment after the sheet came down. A finished step lighting up again reads as do I still need to tap there. It now moves straight to the send button.

The fill in field row is folded away

Creating a snippet used to spring nine blue buttons up the instant your cursor touched the content field. Most people are there to write a line of text, so that row was not help, it was a question: do I have to choose one of these. Tap the fill in field row to open it. Once opened, it stays open.

## v5.0.2 (build 1)

### 한국어

사진에서 필요한 글자만 문질러 담습니다

통장에 적힌 계좌번호나 명함의 전화번호를 보고 옮겨 적지 않아도 됩니다. 단축어를 만들다가 스캔해서 글자 넣기로 사진을 찍고, 필요한 곳 위를 손가락으로 문지르면 지나간 글자만 내용으로 들어옵니다.

사진 한 장에는 필요한 것보다 많은 글자가 들어 있습니다. 통장 사진이라면 은행 이름과 예금주와 상품명이 계좌번호와 함께 찍힙니다. 읽은 것을 전부 넣으면 결국 지우는 일을 하게 됩니다. 손가락이 지나간 자리만 담기니까 계좌번호만 집어 올 수 있습니다.

잘못 담았으면 지우개로 다시 문지르면 빠집니다. 글자가 작으면 두 손가락으로 벌려 확대하세요. 확대할수록 더 정밀하게 짚힙니다. 하이픈 없는 긴 숫자는 다섯 자씩 나뉘어 있어서 필요한 자리까지만 담을 수 있습니다.

문지르기가 어려우면 오른쪽 위 줄로 고르기를 누르세요. 읽어낸 줄이 목록으로 떠서 눌러 고를 수 있고, 여러 줄을 이어 붙일 수도 있습니다.

사진은 저장되지 않습니다. 글자만 꺼내 쓰고 사진은 버립니다. 읽는 일은 iPhone 안에서 끝나기 때문에 사진도 글자도 어디로도 전송되지 않습니다.

스캔과 이미지를 갈라 놓았습니다

붙여넣을 내용 아래에 단추가 셋이라 글자가 잘렸고, 남은 둘은 둘 다 사진 이야기로 읽혀 무엇이 다른지 흐렸습니다. 한 줄에 하나씩 놓고 무엇이 값이 되는지 적었습니다. 스캔해서 글자 넣기는 사진 속 글자만 읽어 오고 사진은 버립니다. 이미지 붙이기는 사진을 그대로 담아서, 단축어를 누르면 그림이 복사됩니다.

앱을 다시 열 때 잠깐 멈추던 것을 고쳤습니다

맥에서 무언가 복사한 직후 앱을 앞으로 부르면, 그 내용을 옆 기기에서 끌어오느라 화면이 잠깐 굳었습니다. 기다리는 자리를 화면 밖으로 옮겼습니다. 클립보드에 그림이 들어 있을 때 그것을 줄이고 저장하던 일도 함께 옮겼습니다.

### English

Swipe a photo to take only the text you need

You no longer have to retype an account number from a bankbook or a phone number from a business card. While creating a shortcut, tap Scan text in, take a photo, and swipe your finger over the part you need. Only the text your finger passes over becomes the content.

A photo holds more text than you need. A bankbook photo carries the bank name, the account holder and the product name along with the account number. Pour all of it into the value and you end up deleting most of it. Swiping takes just the account number.

Picked something by mistake? Swipe over it again with the eraser and it comes back out. Pinch with two fingers to zoom in on small text, and the more you zoom the more precisely it selects. Long numbers without hyphens are split into five character pieces, so you can take just the part you need.

If swiping is hard, tap Pick by line at the top right. The recognized lines appear as a list you can tap, and you can join several lines together.

The photo is never saved. The text is taken out and the photo is discarded. Recognition happens entirely on your iPhone, so neither the photo nor the text is sent anywhere.

Scanning and attaching now look like the different things they are

Three buttons shared one row, the labels were cut off, and the two that remained both read as something about photos. Each now gets its own row that says what becomes the value. Scan text in takes only the text from the photo and discards the photo. Attach an image keeps the photo itself, so tapping the shortcut copies the image.

Fixed a brief freeze when reopening the app

Copy something on your Mac, bring the app forward, and the screen would freeze for a moment while it pulled that content across from the other device. That wait now happens away from the screen, along with the resizing and storing of images left on the clipboard.

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
