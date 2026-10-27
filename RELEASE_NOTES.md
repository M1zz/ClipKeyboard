# 릴리즈 노트

App Store 의 "이 버전의 새로운 기능" 에 그대로 올라가는 글이다.
DeployBar 가 배포할 때 이 파일의 `## <버전>` 절을 읽어 간다.

쓰는 법은 `CLAUDE.md` 의 "릴리즈 노트 작성 규칙" 을 따른다.
한 줄에 한 문장, 3~5줄, 글머리표와 이모지는 쓰지 않는다.
버전별 긴 기록과 심사 메모는 `docs/release-notes/` 에 있다.

**절 제목에 언어 이름을 적는다.** DeployBar 가 제목을 보고 언어를 가른다.
한국어 이름·영어 이름·현지 이름·로케일 코드를 다 알아본다. 제목이 언어를 말하지 않으면
본문 글자로 판별하는데 그때는 한글·가나·라틴만 갈리므로 중국어·러시아어가 조용히 버려진다.
`deploy.env` 의 `LOCALES` 에 없는 언어는 대조 대상이 아니니, 언어를 늘리면 거기에도 넣는다.

**확인**: `DeployBar --reponotes 클립키보드 5.0.8` 로 무엇을 읽어 가는지 미리 볼 수 있다.

## 5.1.15

### 앱스토어 (한국어)

```
요금제가 무료, Plus, Pro 세 가지로 정리됐어요.
Plus와 Pro는 연 구독과 평생 중에 고를 수 있어요.
구독 중이면 언제든 평생으로 바꿀 수 있어요.
모든 앱을 평생 여는 언제나 평생 패스가 생겼어요.
펼친 iPhone Duo에서 새 단축어와 수정이 오른쪽 화면에 열려요.
```

### App Store (English)

```
Plans are now simply Free, Plus and Pro.
Choose yearly or lifetime for Plus and Pro.
Subscribers can switch to lifetime anytime.
A new Forever Pass unlocks all our apps for life.
On an unfolded iPhone Duo, new and edited snippets open on the right side.
```

### 앱스토어 (중국어 간체)

```
方案整理为免费、Plus 和 Pro 三种。
Plus 和 Pro 可选年订阅或终身买断。
订阅中也能随时改为终身买断。
新增永久通行证，所有应用终身解锁。
在展开的 iPhone Duo 上，新建和编辑短语会在右侧打开。
```

### 앱스토어 (중국어 번체)

```
方案整理為免費、Plus 和 Pro 三種。
Plus 和 Pro 可選年訂閱或終身買斷。
訂閱中也能隨時改為終身買斷。
新增永久通行證，所有 App 終身解鎖。
在展開的 iPhone Duo 上，新增和編輯短語會在右側打開。
```

### 앱스토어 (러시아어)

```
Тарифы теперь простые: Free, Plus и Pro.
Plus и Pro можно взять на год или навсегда.
Подписку легко заменить покупкой навсегда.
Новый вечный пропуск открывает все наши приложения.
На развёрнутом iPhone Duo новые и изменяемые фразы открываются справа.
```

### App Store (Japanese, ja)

```
プランが無料、Plus、Proの3つになりました。
PlusとProは年額か買い切りを選べます。
サブスク中でもいつでも買い切りに切り替えられます。
すべてのアプリがずっと使える永久パスが登場しました。
開いた iPhone Duo では、定型文の作成と編集が右側に開きます。
```

### App Store (Spanish, es-MX)

```
Los planes ahora son Gratis, Plus y Pro.
Elige Plus o Pro anual o de por vida.
Si tienes suscripción, cámbiate a de por vida cuando quieras.
Nuevo pase de por vida para todas nuestras apps.
En un iPhone Duo abierto, crear y editar frases se abre en el lado derecho.
```

### App Store (German, de-DE)

```
Die Tarife heißen jetzt Kostenlos, Plus und Pro.
Plus und Pro gibt es als Jahresabo oder einmalig.
Im Abo kannst du jederzeit auf einmalig wechseln.
Ein neuer Pass schaltet alle unsere Apps dauerhaft frei.
Auf einem aufgeklappten iPhone Duo öffnen sich neue und bearbeitete Textbausteine rechts.
```

### App Store (Thai, th)

```
แพ็กเกจจัดใหม่เป็น ฟรี Plus และ Pro
เลือก Plus และ Pro แบบรายปีหรือซื้อขาดได้
สมาชิกรายปีเปลี่ยนเป็นแบบซื้อขาดได้ทุกเมื่อ
มีบัตรผ่านตลอดชีพใหม่ ปลดล็อกทุกแอปของเรา
บน iPhone Duo ที่กางออก การสร้างและแก้ไขข้อความด่วนจะเปิดทางขวา
```

### App Store (Vietnamese, vi)

```
Các gói nay gọn lại thành Miễn phí, Plus và Pro.
Plus và Pro có gói năm hoặc trọn đời.
Đang đăng ký vẫn chuyển sang trọn đời lúc nào cũng được.
Thẻ trọn đời mới mở khóa mọi ứng dụng của chúng tôi.
Trên iPhone Duo mở ra, tạo và sửa cụm từ mở ở bên phải.
```

### App Store (French, fr-FR)

```
Les formules sont désormais Gratuit, Plus et Pro.
Plus et Pro existent en annuel ou à vie.
Abonné, vous pouvez passer à vie à tout moment.
Nouveau pass à vie pour toutes nos apps.
Sur un iPhone Duo déplié, créer et modifier une phrase s’ouvre à droite.
```

### App Store (Italian, it)

```
I piani ora sono Gratis, Plus e Pro.
Scegli Plus o Pro annuale oppure a vita.
Se sei abbonato puoi passare a vita quando vuoi.
Nuovo pass a vita per tutte le nostre app.
Su un iPhone Duo aperto, creare e modificare frasi si apre a destra.
```

### App Store (Portuguese, pt-BR)

```
Os planos agora são Grátis, Plus e Pro.
Escolha Plus ou Pro anual ou vitalício.
Assinantes podem mudar para vitalício quando quiserem.
Novo passe vitalício para todos os nossos apps.
Em um iPhone Duo aberto, criar e editar frases abre do lado direito.
```

### App Store (Czech, cs)

```
Tarify jsou nově Zdarma, Plus a Pro.
Plus i Pro můžete mít na rok nebo navždy.
Předplatné můžete kdykoli změnit na doživotní.
Nová doživotní propustka odemkne všechny naše aplikace.
Na rozloženém iPhonu Duo se nové a upravované fráze otevírají vpravo.
```

### App Store (Danish, da)

```
Abonnementerne er nu Gratis, Plus og Pro.
Vælg Plus eller Pro årligt eller for livet.
Abonnenter kan skifte til livstid når som helst.
Nyt livstidspas åbner alle vores apps.
På en udfoldet iPhone Duo åbner nye og redigerede fraser i højre side.
```

### App Store (Greek, el)

```
Τα πακέτα είναι πλέον Δωρεάν, Plus και Pro.
Επιλέξτε Plus ή Pro ετήσια ή εφάπαξ.
Οι συνδρομητές περνούν σε εφάπαξ όποτε θέλουν.
Νέο ισόβιο πάσο για όλες τις εφαρμογές μας.
Σε ανοιχτό iPhone Duo, η δημιουργία και η επεξεργασία φράσεων ανοίγει δεξιά.
```

### App Store (Finnish, fi)

```
Tilaukset ovat nyt Ilmainen, Plus ja Pro.
Plus ja Pro ovat saatavilla vuodeksi tai pysyvästi.
Tilaajana voit vaihtaa pysyvään milloin vain.
Uusi ikuinen passi avaa kaikki sovelluksemme.
Avatussa iPhone Duossa fraasin luonti ja muokkaus avautuvat oikealle.
```

### App Store (Indonesian, id)

```
Paket kini jadi Gratis, Plus, dan Pro.
Pilih Plus atau Pro tahunan atau seumur hidup.
Pelanggan bisa beralih ke seumur hidup kapan saja.
Pass seumur hidup baru membuka semua aplikasi kami.
Di iPhone Duo yang dibuka, membuat dan mengedit frasa terbuka di sisi kanan.
```

### App Store (Norsk bokmål, nb)

```
Abonnementene heter nå Gratis, Plus og Pro.
Velg Plus eller Pro årlig eller for livet.
Abonnenter kan bytte til livstid når som helst.
Nytt livstidspass åpner alle appene våre.
På en utbrettet iPhone Duo åpnes nye og redigerte fraser på høyre side.
```

### App Store (Dutch, nl)

```
De abonnementen zijn nu Gratis, Plus en Pro.
Kies Plus of Pro per jaar of levenslang.
Abonnees kunnen altijd overstappen naar levenslang.
Nieuwe levenslange pas opent al onze apps.
Op een opengevouwen iPhone Duo openen nieuwe en bewerkte fragmenten aan de rechterkant.
```

### App Store (Polish, pl)

```
Plany to teraz Darmowy, Plus i Pro.
Plus i Pro kupisz na rok lub na zawsze.
Subskrypcję możesz w każdej chwili zamienić na dożywotnią.
Nowa dożywotnia przepustka otwiera wszystkie nasze aplikacje.
Na rozłożonym iPhonie Duo tworzenie i edycja fraz otwiera się po prawej.
```

### App Store (Swedish, sv)

```
Planerna heter nu Gratis, Plus och Pro.
Välj Plus eller Pro per år eller för alltid.
Prenumeranter kan byta till livstid när som helst.
Nytt livstidspass öppnar alla våra appar.
På en utfälld iPhone Duo öppnas nya och redigerade fraser till höger.
```

### App Store (Turkish, tr)

```
Planlar artık Ücretsiz, Plus ve Pro.
Plus ve Pro yıllık ya da ömür boyu alınabilir.
Abonelikten istediğiniz an ömür boyuna geçebilirsiniz.
Yeni ömür boyu geçiş tüm uygulamalarımızı açar.
Açık bir iPhone Duo’da ifade oluşturma ve düzenleme sağ tarafta açılır.
```

## 5.1.14

### 앱스토어 (한국어)

```
새로 설치하면 하얀 화면에서 하나씩 해 보며 시작해요.
필요한 기능은 쓸 때가 오면 그 자리에서 알려 드려요.
펼친 iPhone Duo에서 새 단축어와 수정이 오른쪽 화면에 열려요.
설정의 무료 안내와 Pro 화면이 다른 메뉴처럼 열려요.
지금 쓰시던 화면과 단축어는 그대로예요.
```

### App Store (English)

```
New installs start on a clean, simple screen you try step by step.
Features show up right when you need them.
On an unfolded iPhone Duo, new and edited snippets open on the right side.
The free plan and Pro screens in Settings open like every other menu.
Your current screens and snippets stay exactly as they are.
```

### 앱스토어 (중국어 간체)

```
新安装时从简洁的空白界面开始，一步步试着用。
需要的功能会在用到时当场告诉你。
在展开的 iPhone Duo 上，新建和编辑短语会在右侧打开。
设置里的免费说明和 Pro 页面像其他菜单一样打开。
你现在的界面和短语都保持不变。
```

### 앱스토어 (중국어 번체)

```
新安裝時從簡潔的空白畫面開始，一步步試著用。
需要的功能會在用到時當場告訴你。
在展開的 iPhone Duo 上，新增和編輯短語會在右側打開。
設定裡的免費說明和 Pro 頁面像其他選單一樣打開。
你現在的畫面和短語都保持不變。
```

### 앱스토어 (러시아어)

```
Новая установка начинается с чистого экрана, где всё пробуется по шагам.
Нужные функции появляются, когда они действительно нужны.
На развёрнутом iPhone Duo новые и изменяемые фразы открываются справа.
Экраны бесплатного режима и Pro в настройках открываются как обычные меню.
Ваши экраны и фразы остаются как были.
```

### App Store (Japanese, ja)

```
新しくインストールすると、まっさらな画面でひとつずつ試しながら始まります。
必要な機能は、使うときにその場でお知らせします。
開いた iPhone Duo では、定型文の作成と編集が右側に開きます。
設定の無料案内と Pro の画面がほかのメニューと同じように開きます。
今お使いの画面と定型文はそのままです。
```

### App Store (Spanish, es-MX)

```
Las instalaciones nuevas empiezan en una pantalla limpia que pruebas paso a paso.
Las funciones aparecen justo cuando las necesitas.
En un iPhone Duo abierto, crear y editar frases se abre en el lado derecho.
Las pantallas del plan gratis y de Pro en Ajustes se abren como cualquier otro menú.
Tus pantallas y frases actuales siguen igual.
```

### App Store (German, de-DE)

```
Neuinstallationen beginnen auf einem leeren, schlichten Bildschirm, Schritt für Schritt.
Funktionen erscheinen genau dann, wenn du sie brauchst.
Auf einem aufgeklappten iPhone Duo öffnen sich neue und bearbeitete Textbausteine rechts.
Die Seiten zur kostenlosen Nutzung und zu Pro in den Einstellungen öffnen sich wie jedes andere Menü.
Deine bisherigen Ansichten und Textbausteine bleiben, wie sie sind.
```

### App Store (Thai, th)

```
ติดตั้งใหม่จะเริ่มจากหน้าจอโล่ง ๆ ให้ลองทีละขั้น
ฟีเจอร์ที่ต้องใช้จะบอกตรงนั้นเมื่อถึงเวลาใช้
บน iPhone Duo ที่กางออก การสร้างและแก้ไขข้อความด่วนจะเปิดทางขวา
หน้าการใช้ฟรีและ Pro ในการตั้งค่าเปิดเหมือนเมนูอื่น
หน้าจอและข้อความด่วนที่ใช้อยู่ยังเหมือนเดิม
```

### App Store (Vietnamese, vi)

```
Cài mới sẽ bắt đầu từ màn hình trống, thử từng bước một.
Tính năng cần thiết sẽ được giới thiệu đúng lúc bạn cần.
Trên iPhone Duo mở ra, tạo và sửa cụm từ mở ở bên phải.
Màn hình dùng miễn phí và Pro trong Cài đặt mở như các menu khác.
Màn hình và cụm từ bạn đang dùng vẫn giữ nguyên.
```

### App Store (French, fr-FR)

```
Une nouvelle installation commence sur un écran vierge, à essayer pas à pas.
Les fonctions apparaissent au moment où vous en avez besoin.
Sur un iPhone Duo déplié, créer et modifier une phrase s’ouvre à droite.
Les écrans de l’usage gratuit et de Pro dans Réglages s’ouvrent comme les autres menus.
Vos écrans et vos phrases restent tels quels.
```

### App Store (Italian, it)

```
Le nuove installazioni partono da uno schermo pulito da provare passo dopo passo.
Le funzioni compaiono proprio quando ti servono.
Su un iPhone Duo aperto, creare e modificare frasi si apre a destra.
Le schermate dell’uso gratuito e di Pro in Impostazioni si aprono come gli altri menu.
Le tue schermate e frasi restano come sono.
```

### App Store (Portuguese, pt-BR)

```
Instalações novas começam em uma tela limpa, para testar passo a passo.
Os recursos aparecem bem na hora em que você precisa.
Em um iPhone Duo aberto, criar e editar frases abre do lado direito.
As telas do uso grátis e do Pro em Ajustes abrem como qualquer outro menu.
Suas telas e frases atuais continuam iguais.
```

### App Store (Czech, cs)

```
Nová instalace začíná na čisté obrazovce, kde si vše vyzkoušíte krok za krokem.
Funkce se objeví právě ve chvíli, kdy je potřebujete.
Na rozloženém iPhonu Duo se nové a upravované fráze otevírají vpravo.
Obrazovky bezplatného používání a Pro v Nastavení se otevírají jako ostatní nabídky.
Vaše obrazovky a fráze zůstávají beze změny.
```

### App Store (Danish, da)

```
Nye installationer starter på en ren skærm, du prøver trin for trin.
Funktioner dukker op, lige når du har brug for dem.
På en udfoldet iPhone Duo åbner nye og redigerede fraser i højre side.
Skærmene for gratis brug og Pro i Indstillinger åbner som alle andre menuer.
Dine nuværende skærme og fraser er uændrede.
```

### App Store (Greek, el)

```
Οι νέες εγκαταστάσεις ξεκινούν από μια καθαρή οθόνη που δοκιμάζετε βήμα βήμα.
Οι λειτουργίες εμφανίζονται τη στιγμή που τις χρειάζεστε.
Σε ανοιχτό iPhone Duo, η δημιουργία και η επεξεργασία φράσεων ανοίγει δεξιά.
Οι οθόνες δωρεάν χρήσης και Pro στις Ρυθμίσεις ανοίγουν όπως τα άλλα μενού.
Οι οθόνες και οι φράσεις σας μένουν όπως ήταν.
```

### App Store (Finnish, fi)

```
Uusi asennus alkaa tyhjältä näytöltä, jolla kokeilet asiat askel kerrallaan.
Toiminnot tulevat esiin juuri silloin, kun tarvitset niitä.
Avatussa iPhone Duossa fraasin luonti ja muokkaus avautuvat oikealle.
Ilmaisen käytön ja Pron näkymät avautuvat asetuksissa kuten muutkin valikot.
Nykyiset näkymäsi ja fraasisi pysyvät ennallaan.
```

### App Store (Indonesian, id)

```
Instalasi baru dimulai dari layar bersih yang dicoba langkah demi langkah.
Fitur muncul tepat saat Anda membutuhkannya.
Di iPhone Duo yang dibuka, membuat dan mengedit frasa terbuka di sisi kanan.
Layar penggunaan gratis dan Pro di Pengaturan terbuka seperti menu lainnya.
Layar dan frasa yang Anda pakai sekarang tetap sama.
```

### App Store (Norsk bokmål, nb)

```
Nye installasjoner starter på en ren skjerm du prøver steg for steg.
Funksjoner dukker opp akkurat når du trenger dem.
På en utbrettet iPhone Duo åpnes nye og redigerte fraser på høyre side.
Skjermene for gratis bruk og Pro i Innstillinger åpnes som andre menyer.
Skjermene og frasene du bruker nå, er som før.
```

### App Store (Dutch, nl)

```
Nieuwe installaties beginnen op een leeg scherm dat je stap voor stap probeert.
Functies verschijnen precies wanneer je ze nodig hebt.
Op een opengevouwen iPhone Duo openen nieuwe en bewerkte fragmenten aan de rechterkant.
De schermen voor gratis gebruik en Pro in Instellingen openen zoals elk ander menu.
Je huidige schermen en fragmenten blijven zoals ze zijn.
```

### App Store (Polish, pl)

```
Nowa instalacja zaczyna się od czystego ekranu, który poznajesz krok po kroku.
Funkcje pojawiają się wtedy, gdy ich potrzebujesz.
Na rozłożonym iPhonie Duo tworzenie i edycja fraz otwiera się po prawej.
Ekrany darmowego korzystania i Pro w Ustawieniach otwierają się jak inne menu.
Twoje obecne ekrany i frazy zostają bez zmian.
```

### App Store (Swedish, sv)

```
Nya installationer börjar på en ren skärm som du provar steg för steg.
Funktioner dyker upp precis när du behöver dem.
På en utfälld iPhone Duo öppnas nya och redigerade fraser till höger.
Skärmarna för gratis användning och Pro i Inställningar öppnas som andra menyer.
Dina nuvarande skärmar och fraser är oförändrade.
```

### App Store (Turkish, tr)

```
Yeni kurulumlar, adım adım denediğiniz sade bir ekranla başlar.
Özellikler tam ihtiyaç duyduğunuz anda karşınıza çıkar.
Açık bir iPhone Duo’da ifade oluşturma ve düzenleme sağ tarafta açılır.
Ayarlar’daki ücretsiz kullanım ve Pro ekranları diğer menüler gibi açılır.
Şu anki ekranlarınız ve ifadeleriniz olduğu gibi kalır.
```

## 5.1.13

### 앱스토어 (한국어)

```
키보드가 iPhone 기본 키보드와 같은 모양이 됐어요.
천지인도 iPhone과 같은 배열로 바뀌었어요.
단축어를 넣으면 쓰던 키보드로 돌아가요.
처음 쓰는 화면이 한결 가벼워졌어요.
전체 접근을 켜고 오면 바로 확인돼요.
```

### App Store (English)

```
The keyboard now looks just like the iPhone keyboard.
The Korean Cheonjiin layout now matches iPhone.
After a snippet, you're back on your own keyboard.
Getting started feels lighter and calmer.
Full Access is confirmed as soon as you come back.
```

### 앱스토어 (중국어 간체)

```
键盘外观现在与 iPhone 自带键盘一致。
韩文天地人布局也与 iPhone 相同。
输入短语后，会切回你原来的键盘。
初次使用的界面更简洁了。
打开完全访问后返回，立即就能确认。
```

### 앱스토어 (중국어 번체)

```
鍵盤外觀現在與 iPhone 內建鍵盤一致。
韓文天地人配置也與 iPhone 相同。
輸入短語後，會切回你原本的鍵盤。
初次使用的畫面更簡潔了。
開啟完整取用後返回，立即就能確認。
```

### 앱스토어 (러시아어)

```
Клавиатура теперь выглядит как стандартная на iPhone.
Корейская раскладка Чхонджиин теперь как на iPhone.
После вставки фразы вернётся ваша клавиатура.
Первые шаги стали проще и спокойнее.
Полный доступ виден сразу, как только вы вернётесь.
```

### App Store (Japanese, ja)

```
キーボードがiPhone標準と同じ見た目になりました。
韓国語の天地人もiPhoneと同じ配列になりました。
定型文を入力すると、元のキーボードに戻ります。
はじめての画面がすっきりしました。
フルアクセスをオンにして戻ると、すぐに反映されます。
```

### App Store (Spanish, es-MX)

```
El teclado ahora se ve igual que el del iPhone.
La distribución coreana Cheonjiin ya es como en iPhone.
Al insertar una frase, vuelves a tu teclado.
Empezar es más sencillo y tranquilo.
El acceso total se confirma en cuanto regresas.
```

### App Store (German, de-DE)

```
Die Tastatur sieht jetzt aus wie die iPhone-Tastatur.
Das koreanische Cheonjiin-Layout entspricht dem iPhone.
Nach einem Textbaustein bist du wieder auf deiner Tastatur.
Der Einstieg ist schlichter und ruhiger.
Vollzugriff wird sofort erkannt, wenn du zurückkommst.
```

### App Store (Thai, th)

```
แป้นพิมพ์หน้าตาเหมือนแป้นพิมพ์ของ iPhone แล้ว
แป้นพิมพ์เกาหลีเชียนจีจัดวางแบบเดียวกับ iPhone
ใส่ข้อความด่วนแล้วจะกลับไปที่แป้นพิมพ์เดิม
หน้าจอเริ่มต้นใช้งานเรียบง่ายขึ้น
เปิดการเข้าถึงทั้งหมดแล้วกลับมา จะเห็นผลทันที
```

### App Store (Vietnamese, vi)

```
Bàn phím giờ trông giống hệt bàn phím iPhone.
Bố cục Cheonjiin tiếng Hàn nay giống trên iPhone.
Chèn cụm từ xong, bạn quay lại bàn phím của mình.
Màn hình bắt đầu gọn gàng và nhẹ nhàng hơn.
Bật truy cập đầy đủ rồi quay lại là được xác nhận ngay.
```

### App Store (French, fr-FR)

```
Le clavier ressemble désormais à celui de l’iPhone.
La disposition coréenne Cheonjiin est comme sur iPhone.
Après une phrase, vous revenez à votre clavier.
Les premiers pas sont plus simples et plus calmes.
L’accès complet est confirmé dès votre retour.
```

### App Store (Italian, it)

```
La tastiera ora è identica a quella di iPhone.
Il layout coreano Cheonjiin ora è come su iPhone.
Dopo una frase torni alla tua tastiera.
I primi passi sono più semplici e tranquilli.
L’accesso completo viene confermato appena torni.
```

### App Store (Portuguese, pt-BR)

```
O teclado agora é igual ao teclado do iPhone.
O layout coreano Cheonjiin agora é como no iPhone.
Depois de inserir uma frase, você volta ao seu teclado.
Começar a usar ficou mais simples e tranquilo.
O acesso total é confirmado assim que você volta.
```

### App Store (Czech, cs)

```
Klávesnice teď vypadá stejně jako na iPhonu.
Korejské rozložení Cheonjiin je teď jako na iPhonu.
Po vložení fráze se vrátíte ke své klávesnici.
Začátky jsou jednodušší a klidnější.
Plný přístup se potvrdí hned po návratu.
```

### App Store (Danish, da)

```
Tastaturet ligner nu iPhones eget tastatur.
Det koreanske Cheonjiin-layout er nu som på iPhone.
Når du har indsat en frase, er du tilbage på dit tastatur.
Det er blevet enklere og roligere at komme i gang.
Fuld adgang bekræftes, så snart du kommer tilbage.
```

### App Store (Greek, el)

```
Το πληκτρολόγιο μοιάζει πλέον με αυτό του iPhone.
Η κορεατική διάταξη Τσεονζίν είναι πλέον όπως στο iPhone.
Μετά από μια φράση επιστρέφετε στο πληκτρολόγιό σας.
Τα πρώτα βήματα είναι πιο απλά και πιο ήρεμα.
Η πλήρης πρόσβαση επιβεβαιώνεται μόλις επιστρέψετε.
```

### App Store (Finnish, fi)

```
Näppäimistö näyttää nyt samalta kuin iPhonen oma.
Korealainen Cheonjiin-asettelu on nyt kuin iPhonessa.
Fraasin jälkeen palaat omaan näppäimistöösi.
Alkuun pääsee nyt helpommin ja rauhallisemmin.
Täysi käyttö vahvistuu heti, kun palaat.
```

### App Store (Indonesian, id)

```
Papan ketik kini tampak sama seperti papan ketik iPhone.
Tata letak Cheonjiin Korea kini sama seperti di iPhone.
Setelah memasukkan frasa, Anda kembali ke papan ketik Anda.
Langkah awal kini lebih sederhana dan tenang.
Akses Penuh langsung terkonfirmasi begitu Anda kembali.
```

### App Store (Norsk bokmål, nb)

```
Tastaturet ser nå ut akkurat som iPhone-tastaturet.
Den koreanske Cheonjiin-layouten er nå som på iPhone.
Etter en frase er du tilbake på ditt eget tastatur.
Det er blitt enklere og roligere å komme i gang.
Full tilgang bekreftes med en gang du kommer tilbake.
```

### App Store (Dutch, nl)

```
Het toetsenbord ziet er nu uit als dat van de iPhone.
De Koreaanse Cheonjiin-indeling is nu zoals op iPhone.
Na een fragment ben je terug op je eigen toetsenbord.
Beginnen is eenvoudiger en rustiger geworden.
Volledige toegang wordt bevestigd zodra je terugkomt.
```

### App Store (Polish, pl)

```
Klawiatura wygląda teraz jak klawiatura iPhone’a.
Koreański układ Cheonjiin jest teraz jak na iPhonie.
Po wstawieniu frazy wracasz do swojej klawiatury.
Pierwsze kroki są prostsze i spokojniejsze.
Pełny dostęp jest potwierdzany zaraz po powrocie.
```

### App Store (Swedish, sv)

```
Tangentbordet ser nu ut precis som iPhones.
Den koreanska Cheonjiin-layouten är nu som på iPhone.
Efter en fras är du tillbaka på ditt eget tangentbord.
Det har blivit enklare och lugnare att komma igång.
Full åtkomst bekräftas så fort du kommer tillbaka.
```

### App Store (Turkish, tr)

```
Klavye artık iPhone klavyesiyle aynı görünüyor.
Korece Cheonjiin düzeni artık iPhone’daki gibi.
Bir ifade ekledikten sonra kendi klavyenize dönersiniz.
Başlangıç ekranları daha sade ve sakin.
Tam erişim, geri döndüğünüz anda onaylanır.
```

## 5.1.12

### 앱스토어 (한국어)

```
Plus와 Pro 중 나에게 맞는 것을 고를 수 있어요.
복사하고 버튼 한 번이면 키보드에 담겨요.
키보드에 지우기 키가 늘 보여요.
키보드에서 템플릿 값을 앱으로 가서 바로 더해요.
전체 접근이 꺼져 있으면 켜는 법을 알려 드려요.
```

### App Store (English)

```
Choose between Plus and Pro.
Copy, then save it with one button.
The delete key is now always on the keyboard.
Add template values right from the keyboard.
We show you how to turn on Full Access.
```

### 앱스토어 (중국어 간체)

```
现在可以在 Plus 和 Pro 之间选择。
复制后按一下按钮，就能放进键盘。
键盘上始终显示删除键。
在键盘上可直接跳到 App 添加模板值。
未开启完全访问时，会告诉你如何开启。
```

### 앱스토어 (중국어 번체)

```
現在可以在 Plus 和 Pro 之間選擇。
複製後按一下按鈕，就能放進鍵盤。
鍵盤上始終顯示刪除鍵。
在鍵盤上可直接跳到 App 新增範本值。
未開啟完整取用時，會告訴你如何開啟。
```

### 앱스토어 (러시아어)

```
Теперь можно выбрать Plus или Pro.
Копируйте и сохраняйте одной кнопкой.
Клавиша удаления всегда на клавиатуре.
Добавляйте значения шаблонов прямо с клавиатуры.
Подскажем, как включить полный доступ.
```

### App Store (Japanese, ja)

```
PlusとProから選べるようになりました。
コピーしてボタンひとつでキーボードへ。
削除キーがいつもキーボードに表示されます。
キーボードからアプリでテンプレート値を追加。
フルアクセスを有効にする方法をご案内します。
```

### App Store (Spanish, es-MX)

```
Ahora puedes elegir entre Plus y Pro.
Copia y guárdalo con un solo botón.
La tecla de borrar siempre está a la vista.
Agrega valores de plantilla desde el teclado.
Te mostramos cómo activar el acceso total.
```

### App Store (German, de-DE)

```
Wähle jetzt zwischen Plus und Pro.
Kopieren und per Taste ablegen.
Die Löschtaste ist immer sichtbar.
Vorlagenwerte direkt von der Tastatur ergänzen.
Wir zeigen, wie du vollen Zugriff aktivierst.
```

### App Store (Thai, th)

```
เลือกได้ระหว่าง Plus และ Pro
คัดลอกแล้วกดปุ่มเดียว เก็บไว้บนแป้นพิมพ์
ปุ่มลบแสดงบนแป้นพิมพ์ตลอดเวลา
เพิ่มค่าเทมเพลตในแอปได้จากแป้นพิมพ์
แนะนำวิธีเปิดการเข้าถึงแบบเต็ม
```

### App Store (Vietnamese, vi)

```
Giờ bạn có thể chọn Plus hoặc Pro.
Sao chép và lưu bằng một nút.
Phím xóa luôn hiện trên bàn phím.
Thêm giá trị mẫu trong ứng dụng từ bàn phím.
Hướng dẫn bật Cho phép truy cập đầy đủ.
```

### App Store (French, fr-FR)

```
Choisissez entre Plus et Pro.
Copiez et gardez d'un seul bouton.
La touche Effacer est toujours visible.
Ajoutez des valeurs de modèle depuis le clavier.
On vous montre comment activer l’accès complet.
```

### App Store (Italian, it)

```
Ora puoi scegliere tra Plus e Pro.
Copia e salva con un solo tasto.
Il tasto Cancella è sempre visibile.
Aggiungi valori ai modelli dalla tastiera.
Ti mostriamo come attivare l’accesso completo.
```

### App Store (Portuguese, pt-BR)

```
Agora você escolhe entre Plus e Pro.
Copie e guarde com um só botão.
A tecla de apagar fica sempre visível.
Adicione valores de modelo a partir do teclado.
Mostramos como ativar o acesso total.
```

### App Store (Czech, cs)

```
Nově si vyberete mezi Plus a Pro.
Zkopírujte a uložte jedním tlačítkem.
Klávesa mazání je vždy na klávesnici.
Hodnoty šablon přidáte přímo z klávesnice.
Ukážeme vám, jak zapnout plný přístup.
```

### App Store (Danish, da)

```
Vælg nu mellem Plus og Pro.
Kopiér og gem med ét tryk.
Slettetasten er altid på tastaturet.
Tilføj skabelonværdier direkte fra tastaturet.
Vi viser dig, hvordan du slår fuld adgang til.
```

### App Store (Greek, el)

```
Επιλέξτε ανάμεσα σε Plus και Pro.
Αντέγραψε και κράτα το με ένα κουμπί.
Το πλήκτρο διαγραφής φαίνεται πάντα.
Προσθέστε τιμές προτύπων από το πληκτρολόγιο.
Σας δείχνουμε πώς ενεργοποιείτε πλήρη πρόσβαση.
```

### App Store (Finnish, fi)

```
Valitse nyt Plus tai Pro.
Kopioi ja tallenna yhdellä napilla.
Poistonäppäin näkyy aina näppäimistöllä.
Lisää pohjien arvoja suoraan näppäimistöltä.
Neuvomme, miten täysi käyttöoikeus kytketään.
```

### App Store (Indonesian, id)

```
Kini bisa pilih Plus atau Pro.
Salin, lalu simpan dengan satu tombol.
Tombol hapus selalu tampil di keyboard.
Tambah nilai template dari keyboard.
Kami tunjukkan cara mengaktifkan Akses Penuh.
```

### App Store (Norsk bokmål, nb)

```
Velg nå mellom Plus og Pro.
Kopier og lagre med ett trykk.
Slettetasten er alltid på tastaturet.
Legg til malverdier rett fra tastaturet.
Vi viser deg hvordan du slår på full tilgang.
```

### App Store (Dutch, nl)

```
Kies nu tussen Plus en Pro.
Kopieer en bewaar met één knop.
De wistoets staat altijd op het toetsenbord.
Voeg sjabloonwaarden toe vanaf het toetsenbord.
We laten zien hoe je volledige toegang aanzet.
```

### App Store (Polish, pl)

```
Teraz wybierzesz między Plus a Pro.
Skopiuj i zapisz jednym przyciskiem.
Klawisz usuwania jest zawsze widoczny.
Dodawaj wartości szablonów z klawiatury.
Pokażemy, jak włączyć pełny dostęp.
```

### App Store (Swedish, sv)

```
Välj nu mellan Plus och Pro.
Kopiera och spara med en knapp.
Raderingstangenten syns alltid.
Lägg till mallvärden direkt från tangentbordet.
Vi visar hur du slår på full åtkomst.
```

### App Store (Turkish, tr)

```
Artık Plus ve Pro arasında seçim yapın.
Kopyalayın, tek tuşla klavyeye kaydedin.
Silme tuşu her zaman klavyede görünür.
Şablon değerlerini klavyeden ekleyin.
Tam Erişimi nasıl açacağınızı gösteriyoruz.
```

## 5.1.11

### 앱스토어 (한국어)

```
최근 탭에 복사한 글이 저절로 쌓여요.
최근 항목은 왼쪽으로 밀어서 지울 수 있어요.
카드번호, 여권번호를 맞는 모양으로 적어 줘요.
템플릿 값을 고르다가 바로 새 값을 더해요.
```

### App Store (English)

```
Copied text now appears in Recent.
Swipe left to delete a recent item.
Card and passport numbers auto-format.
Add new template values on the spot.
```

### 앱스토어 (중국어 간체)

```
复制的内容会自动出现在“最近”中。
在最近项目上左滑即可删除。
卡号、护照号会自动排成正确格式。
选择模板值时可直接添加新值。
```

### 앱스토어 (중국어 번체)

```
複製的內容會自動出現在「最近」中。
在最近項目上左滑即可刪除。
卡號、護照號碼會自動排成正確格式。
選擇範本值時可直接新增新值。
```

### 앱스토어 (러시아어)

```
Скопированное теперь появляется в «Недавних».
Смахните влево, чтобы удалить запись.
Номера карт и паспортов форматируются сами.
Новое значение шаблона можно добавить сразу.
```

### App Store (Japanese, ja)

```
コピーした内容が「最近」に自動でたまります。
最近の項目は左にスワイプして削除できます。
カード番号やパスポート番号を正しい形に整えます。
テンプレートの値を選ぶときに新しい値を追加できます。
```

### App Store (Spanish, es-MX)

```
Lo que copias ya aparece en Recientes.
Desliza a la izquierda para borrar un reciente.
Tarjetas y pasaportes se formatean solos.
Agrega un valor nuevo desde la plantilla.
```

### App Store (German, de-DE)

```
Kopierte Texte erscheinen jetzt unter „Zuletzt“.
Nach links wischen löscht einen Eintrag.
Karten- und Passnummern werden richtig formatiert.
Neue Vorlagenwerte direkt hinzufügen.
```

### App Store (Thai, th)

```
ข้อความที่คัดลอกจะแสดงในแท็บล่าสุดทันที
ปัดซ้ายเพื่อลบรายการล่าสุดได้
เลขบัตรและหนังสือเดินทางจัดรูปแบบให้อัตโนมัติ
เพิ่มค่าใหม่ได้ทันทีขณะเลือกค่าในเทมเพลต
```

### App Store (Vietnamese, vi)

```
Nội dung đã sao chép tự hiện trong Gần đây.
Vuốt sang trái để xóa một mục gần đây.
Số thẻ và số hộ chiếu tự định dạng đúng.
Thêm giá trị mới ngay khi chọn mẫu.
```

### App Store (French, fr-FR)

```
Ce que vous copiez apparaît dans Récents.
Balayez à gauche pour supprimer un élément.
Numéros de carte et de passeport bien formatés.
Ajoutez une valeur depuis le modèle.
```

### App Store (Italian, it)

```
Ciò che copi ora compare in Recenti.
Scorri a sinistra per eliminare un elemento.
Numeri di carta e passaporto formattati da soli.
Aggiungi un nuovo valore dal modello.
```

### App Store (Portuguese, pt-BR)

```
O que você copia agora aparece em Recentes.
Deslize para a esquerda para apagar um item.
Cartão e passaporte já saem formatados.
Adicione um novo valor direto no modelo.
```

### App Store (Czech, cs)

```
Zkopírovaný text se teď objeví v Nedávných.
Přejetím doleva položku smažete.
Čísla karet a pasů se naformátují sama.
Novou hodnotu šablony přidáte hned.
```

### App Store (Danish, da)

```
Det, du kopierer, vises nu under Seneste.
Stryg til venstre for at slette et element.
Kort- og pasnumre formateres automatisk.
Tilføj en ny værdi direkte fra skabelonen.
```

### App Store (Greek, el)

```
Ό,τι αντιγράφετε εμφανίζεται στα Πρόσφατα.
Σύρετε αριστερά για να διαγράψετε στοιχείο.
Κάρτες και διαβατήρια μορφοποιούνται σωστά.
Προσθέστε νέα τιμή από το πρότυπο.
```

### App Store (Finnish, fi)

```
Kopioimasi teksti näkyy nyt Viimeisimmissä.
Poista kohde pyyhkäisemällä vasemmalle.
Kortin- ja passinnumerot muotoillaan oikein.
Lisää uusi arvo suoraan mallista.
```

### App Store (Indonesian, id)

```
Teks yang disalin kini muncul di Terbaru.
Geser ke kiri untuk menghapus item.
Nomor kartu dan paspor diformat otomatis.
Tambah nilai baru langsung dari template.
```

### App Store (Norsk bokmål, nb)

```
Det du kopierer, vises nå under Nylige.
Sveip til venstre for å slette et element.
Kort- og passnumre formateres automatisk.
Legg til en ny verdi rett fra malen.
```

### App Store (Dutch, nl)

```
Wat je kopieert, staat nu bij Recent.
Veeg naar links om een item te verwijderen.
Kaart- en paspoortnummers netjes opgemaakt.
Voeg direct een nieuwe waarde toe.
```

### App Store (Polish, pl)

```
Skopiowany tekst pojawia się w Ostatnich.
Przesuń w lewo, aby usunąć element.
Numery kart i paszportów formatują się same.
Nową wartość dodasz prosto z szablonu.
```

### App Store (Swedish, sv)

```
Det du kopierar visas nu under Senaste.
Svep åt vänster för att radera ett objekt.
Kort- och passnummer formateras automatiskt.
Lägg till ett nytt värde direkt från mallen.
```

### App Store (Turkish, tr)

```
Kopyaladıklarınız artık Son Kullanılanlar'da.
Bir öğeyi silmek için sola kaydırın.
Kart ve pasaport numaraları kendiliğinden biçimlenir.
Şablondan hemen yeni bir değer ekleyin.
```

## 5.1.10

### 앱스토어 (한국어)

```
키보드가 열리다 꺼지던 문제를 고쳤어요.
키보드가 더 빨리 뜨고 부드럽게 움직여요.
사진을 넣은 단축어가 공간을 덜 차지해요.
폴란드어, 튀르키예어 등 10개 언어를 새로 지원해요.
예시 문구가 이제 쓰는 언어로 나와요.
```

### App Store (English)

```
Fixed a crash when opening the keyboard.
The keyboard opens faster and smoother.
Photo snippets now take up less space.
10 new languages, including Polish.
Examples now show in your language.
```

### 앱스토어 (중국어 간체)

```
修复了键盘打开时闪退的问题。
键盘弹出更快，滑动更流畅。
带图片的短语占用空间更少。
新增波兰语、土耳其语等 10 种语言。
示例文字现在会以你的语言显示。
```

### 앱스토어 (중국어 번체)

```
修正了鍵盤開啟時閃退的問題。
鍵盤跳出更快，滑動更流暢。
含圖片的短語佔用空間更少。
新增波蘭文、土耳其文等 10 種語言。
範例文字現在會以你的語言顯示。
```

### 앱스토어 (러시아어)

```
Исправлен вылет при открытии клавиатуры.
Клавиатура открывается быстрее.
Фразы с фото занимают меньше места.
Ещё 10 языков, включая польский.
Примеры теперь на вашем языке.
```

### App Store (Japanese, ja)

```
キーボードを開くと落ちる問題を修正しました。
キーボードの表示と動きが速くなりました。
画像付き定型文の保存容量が減りました。
ポーランド語、トルコ語など10言語を追加。
例文がお使いの言語で表示されます。
```

### App Store (Spanish, es-MX)

```
Ya no se cierra al abrir el teclado.
El teclado abre más rápido y fluido.
Frases con foto ocupan menos espacio.
Ahora en 10 idiomas más, como polaco.
Los ejemplos ahora salen en tu idioma.
```

### App Store (German, de-DE)

```
Ein Absturz der Tastatur ist behoben.
Die Tastatur öffnet schneller.
Textbausteine mit Bild sind kleiner.
10 neue Sprachen, etwa Polnisch.
Beispiele sind jetzt in deiner Sprache.
```

### App Store (Thai, th)

```
แก้ปัญหาคีย์บอร์ดปิดเองตอนเปิด
คีย์บอร์ดเปิดเร็วขึ้นและลื่นขึ้น
ข้อความด่วนที่มีรูปใช้พื้นที่น้อยลง
เพิ่มอีก 10 ภาษา เช่น โปแลนด์ ตุรกี
ตัวอย่างข้อความแสดงเป็นภาษาของคุณแล้ว
```

### App Store (Vietnamese, vi)

```
Sửa lỗi bàn phím bị thoát khi mở.
Bàn phím mở nhanh và mượt hơn.
Cụm từ có ảnh chiếm ít dung lượng hơn.
Thêm 10 ngôn ngữ như Ba Lan, Thổ Nhĩ Kỳ.
Văn bản mẫu nay theo ngôn ngữ của bạn.
```

### App Store (French, fr-FR)

```
Le clavier ne plante plus à l'ouverture.
Le clavier s'ouvre plus vite.
Les phrases avec image pèsent moins.
10 langues de plus, dont le polonais.
Exemples affichés dans votre langue.
```

### App Store (Italian, it)

```
La tastiera non si chiude più all'avvio.
La tastiera si apre più in fretta.
Le frasi con foto occupano meno spazio.
10 nuove lingue, tra cui il polacco.
Gli esempi ora sono nella tua lingua.
```

### App Store (Portuguese, pt-BR)

```
O teclado não fecha mais ao abrir.
O teclado abre mais rápido.
Frases com foto ocupam menos espaço.
Mais 10 idiomas, como polonês.
Exemplos agora aparecem no seu idioma.
```

### App Store (Czech, cs)

```
Klávesnice už při otevření nepadá.
Klávesnice se otevírá rychleji.
Fráze s obrázky zabírají méně místa.
Nově i česky a v dalších 9 jazycích.
Ukázky jsou nyní ve vašem jazyce.
```

### App Store (Danish, da)

```
Rettet nedbrud, når tastaturet åbnes.
Tastaturet åbner hurtigere.
Fraser med billeder fylder mindre.
Nu på dansk og 9 andre nye sprog.
Eksempler vises nu på dit sprog.
```

### App Store (Greek, el)

```
Διορθώθηκε κλείσιμο του πληκτρολογίου.
Το πληκτρολόγιο ανοίγει πιο γρήγορα.
Φράσεις με εικόνα πιάνουν λιγότερο χώρο.
Τώρα και στα ελληνικά, μαζί με 9 ακόμα.
Τα παραδείγματα είναι στη γλώσσα σας.
```

### App Store (Finnish, fi)

```
Korjattu näppäimistön kaatuminen.
Näppäimistö aukeaa nopeammin.
Kuvafraasit vievät vähemmän tilaa.
Nyt suomeksi ja 9 muulla kielellä.
Esimerkit näkyvät nyt omalla kielelläsi.
```

### App Store (Indonesian, id)

```
Keyboard tak lagi tertutup saat dibuka.
Keyboard terbuka lebih cepat.
Frasa bergambar kini lebih hemat ruang.
Kini ada bahasa Indonesia dan 9 lainnya.
Contoh teks kini dalam bahasa Anda.
```

### App Store (Norsk bokmål, nb)

```
Retter krasj når tastaturet åpnes.
Tastaturet åpner raskere.
Fraser med bilder tar mindre plass.
Nå på norsk og 9 andre nye språk.
Eksempler vises nå på ditt språk.
```

### App Store (Dutch, nl)

```
Toetsenbord crasht niet meer bij openen.
Het toetsenbord opent sneller.
Fragmenten met foto nemen minder ruimte.
Nu in het Nederlands en 9 andere talen.
Voorbeelden staan nu in je eigen taal.
```

### App Store (Polish, pl)

```
Naprawiono zamykanie się klawiatury.
Klawiatura otwiera się szybciej.
Frazy ze zdjęciem zajmują mniej miejsca.
Teraz po polsku i w 9 innych językach.
Przykłady są teraz w Twoim języku.
```

### App Store (Swedish, sv)

```
Tangentbordet kraschar inte längre.
Tangentbordet öppnas snabbare.
Fraser med bilder tar mindre plats.
Nu på svenska och 9 andra nya språk.
Exempel visas nu på ditt språk.
```

### App Store (Turkish, tr)

```
Klavyenin açılırken kapanması giderildi.
Klavye artık daha hızlı açılıyor.
Görselli ifadeler daha az yer kaplıyor.
Türkçe dahil 10 yeni dil eklendi.
Örnekler artık kendi dilinizde.
```

## 5.1.9

### 앱스토어 (한국어)

```
빈칸 값이 길면 세로 목록으로 보여요.
보낸 의견에 온 답장을 앱에서 읽어요.
프랑스어, 이탈리아어, 포르투갈어도 지원해요.
앱이 더 빨리 열려요.
```

### App Store (English)

```
Long blank values now show as a list.
Read feedback replies in the app.
Now in French, Italian and Portuguese.
The app opens faster.
```

### 앱스토어 (중국어 간체)

```
空位的值较长时，改为竖向列表显示。
可以在应用里查看反馈的回复。
新增法语、意大利语和葡萄牙语。
应用打开得更快了。
```

### 앱스토어 (중국어 번체)

```
空位的值較長時，改為直向列表顯示。
可以在 App 裡查看意見的回覆。
新增法文、義大利文和葡萄牙文。
App 開啟得更快了。
```

### 앱스토어 (러시아어)

```
Длинные значения полей идут списком.
Ответы на отзывы теперь в приложении.
Добавлены французский и ещё два языка.
Приложение открывается быстрее.
```

### App Store (Japanese, ja)

```
長い入力欄の値は縦のリストで表示します。
送ったご意見への返信をアプリで読めます。
フランス語、イタリア語、ポルトガル語に対応。
アプリの起動が速くなりました。
```

### App Store (Spanish, es-MX)

```
Los campos largos se ven en lista.
Ve las respuestas a tus comentarios.
Ahora en francés, italiano y portugués.
La app abre más rápido.
```

### App Store (German, de-DE)

```
Lange Werte erscheinen als Liste.
Antworten auf Feedback in der App.
Drei neue Sprachen, etwa Französisch.
Die App startet schneller.
```

### App Store (Thai, th)

```
ค่ายาวในช่องกรอกแสดงเป็นรายการ
อ่านคำตอบความคิดเห็นของคุณได้ในแอป
รองรับฝรั่งเศส อิตาลี และโปรตุเกส
แอปเปิดเร็วขึ้น
```

### App Store (Vietnamese, vi)

```
Giá trị dài hiện thành danh sách dọc.
Xem trả lời góp ý ngay trong ứng dụng.
Thêm tiếng Pháp, tiếng Ý, Bồ Đào Nha.
Ứng dụng mở nhanh hơn.
```

### App Store (French, fr-FR)

```
Les valeurs longues sont en liste.
Les réponses à vos avis, dans l'app.
En français, italien et portugais.
L'app s'ouvre plus vite.
```

### App Store (Italian, it)

```
I valori lunghi ora sono in elenco.
Leggi le risposte al tuo feedback.
Ora in francese, italiano e portoghese.
L'app si apre più in fretta.
```

### App Store (Portuguese, pt-BR)

```
Valores longos agora aparecem em lista.
Veja as respostas ao seu feedback.
Agora em francês, italiano e português.
O app abre mais rápido.
```

## 5.1.8

### 앱스토어 (한국어)

```
키보드 맨 앞에 최근 탭이 생겼어요.
복사한 글을 키보드에서 바로 저장해요.
저장하기 전에 무엇이 들어갈지 보여요.
복사한 글이 30일 동안 남아요.
목록이 제목 밑에 가려지던 문제를 고쳤어요.
```

### App Store (English)

```
A new Recent tab, first on the keyboard.
Save copied text from the keyboard.
See what will be saved before you tap.
Copied text now stays for 30 days.
Fixed the list hiding under the title.
```

### 앱스토어 (중국어 간체)

```
键盘最前面新增“最近”标签。
在键盘上直接保存复制的文字。
保存前就能看到要存入的内容。
复制的文字可保留 30 天。
修复了列表偶尔被标题遮住的问题。
```

### 앱스토어 (중국어 번체)

```
鍵盤最前面新增「最近」標籤。
在鍵盤上直接儲存複製的文字。
儲存前就能看到要存入的內容。
複製的文字可保留 30 天。
修正了列表偶爾被標題遮住的問題。
```

### 앱스토어 (러시아어)

```
На клавиатуре новая вкладка «Недавние».
Сохраняйте текст прямо с клавиатуры.
Видно, что сохранится, ещё до нажатия.
Скопированное хранится 30 дней.
Список не прячется под заголовком.
```

### App Store (Japanese, ja)

```
キーボードの先頭に「最近」タブが加わりました。
コピーした文章をキーボードから保存できます。
保存する前に中身を確かめられます。
コピーした文章が30日間残ります。
一覧がタイトルの下に隠れる問題を直しました。
```

### App Store (Spanish, es-MX)

```
Nueva pestaña Recientes en el teclado.
Guarda lo que copiaste desde el teclado.
Ve qué se guardará antes de tocar.
Lo que copias se queda 30 días.
La lista ya no se oculta bajo el título.
```

### App Store (German, de-DE)

```
Neuer Tab „Zuletzt“ ganz vorn.
Kopierten Text in der Tastatur sichern.
Du siehst vorher, was gesichert wird.
Kopierter Text bleibt jetzt 30 Tage.
Der Titel verdeckt die Liste nicht mehr.
```

### App Store (Thai, th)

```
คีย์บอร์ดมีแท็บล่าสุดอยู่หน้าสุดแล้ว
บันทึกข้อความที่คัดลอกได้จากคีย์บอร์ด
เห็นก่อนแตะว่าจะบันทึกอะไร
ข้อความที่คัดลอกอยู่ได้ 30 วัน
แก้ปัญหารายการถูกหัวข้อบังบางครั้ง
```

### App Store (Vietnamese, vi)

```
Bàn phím có thêm tab Gần đây ở đầu.
Lưu văn bản đã chép ngay trên bàn phím.
Thấy trước nội dung sẽ được lưu.
Văn bản sao chép được giữ 30 ngày.
Đã sửa lỗi danh sách bị tiêu đề che.
```

## 5.1.7

### 앱스토어 (한국어)

```
단축어를 100번 넣을 때까지 모든 기능이 무료예요.
일본어, 스페인어, 프랑스어 등 여덟 언어로도 쓸 수 있어요.
업무와 개인 카테고리를 미리 만들어 뒀어요.
다크 모드에서 키보드 키가 또렷하게 보여요.
키보드가 뜰 때 가끔 닫히던 문제를 고쳤어요.
```

### App Store (English)

```
Every feature is free for 100 inserts.
Eight new languages, Japanese included.
Work and Personal categories are ready.
Keys are easier to see in Dark Mode.
The keyboard no longer closes on open.
```

### 앱스토어 (중국어 간체)

```
前 100 次输入，所有功能全部免费。
新增日语、西班牙语、法语等八种语言。
已预先建好“工作”和“个人”分类。
深色模式下，键盘按键更清晰。
修复了键盘打开时偶尔关闭的问题。
```

### 앱스토어 (중국어 번체)

```
前 100 次輸入，所有功能全部免費。
新增日文、西班牙文、法文等八種語言。
已預先建好「工作」和「個人」分類。
深色模式下，鍵盤按鍵更清晰。
修正了鍵盤開啟時偶爾關閉的問題。
```

### 앱스토어 (러시아어)

```
Все функции бесплатны первые 100 раз.
Восемь новых языков, включая японский.
Категории «Работа» и «Личное» готовы.
Клавиши лучше видны в тёмном режиме.
Клавиатура больше не закрывается сама.
```

### App Store (Japanese, ja)

```
最初の100回の入力まで、すべての機能が無料です。
日本語、スペイン語、フランス語など8つの言語に対応しました。
「仕事」と「プライベート」のカテゴリを用意しました。
ダークモードでキーが見やすくなりました。
キーボードを開くと閉じてしまうことがある問題を修正しました。
```

### App Store (Spanish, es-MX)

```
Todo gratis en tus primeras 100 veces.
Ocho idiomas nuevos, incluido español.
Nuevas categorías: Trabajo y Personal.
Las teclas se ven mejor en modo oscuro.
El teclado ya no se cierra al abrirse.
```

### App Store (German, de-DE)

```
Die ersten 100 Eingaben: alles gratis.
Acht neue Sprachen, auch Deutsch.
Neue Kategorien: Arbeit und Privat.
Tasten im Dunkelmodus besser sichtbar.
Die Tastatur schließt sich nicht mehr.
```

### App Store (Thai, th)

```
ใช้ทุกฟีเจอร์ฟรีใน 100 ครั้งแรก
เพิ่ม 8 ภาษาใหม่ รวมถึงภาษาไทย
มีหมวดหมู่งานและส่วนตัวให้พร้อมใช้
ปุ่มคีย์บอร์ดเห็นชัดขึ้นในโหมดมืด
แก้ปัญหาคีย์บอร์ดปิดเองตอนเปิด
```

### App Store (Vietnamese, vi)

```
Miễn phí mọi tính năng 100 lần đầu.
Thêm 8 ngôn ngữ, có cả tiếng Việt.
Có sẵn danh mục Công việc và Cá nhân.
Phím dễ nhìn hơn ở chế độ tối.
Bàn phím không còn tự đóng khi mở.
```

### App Store (French, fr-FR)

```
Tout est gratuit pour 100 insertions.
Huit nouvelles langues, dont le français.
Catégories Travail et Perso déjà prêtes.
Touches plus lisibles en mode sombre.
Le clavier ne se ferme plus à l’ouverture.
```

### App Store (Italian, it)

```
Tutto gratis per i primi 100 inserimenti.
Otto nuove lingue, incluso l’italiano.
Categorie Lavoro e Personale già pronte.
Tasti più leggibili in modalità scura.
La tastiera non si chiude più all’apertura.
```

### App Store (Portuguese, pt-BR)

```
Tudo grátis nas primeiras 100 inserções.
Oito idiomas novos, incluindo português.
Categorias Trabalho e Pessoal já prontas.
Teclas mais visíveis no modo escuro.
O teclado não fecha mais ao abrir.
```

## 5.1.6

### 앱스토어 (한국어)

```
복사하면 누른 카드에 바로 복사됨이 표시돼요.
구매 복원을 누르면 결과를 바로 알려 드려요.
iCloud 동기화가 더 안정적으로 동작해요.
앱 안의 키보드가 실제 키보드와 똑같이 보여요.
키보드 글자가 흐려 보이던 문제를 고쳤어요.
```

### App Store (English)

```
The card you tap now shows that it was copied.
Restore Purchases now tells you how it went.
iCloud sync is more reliable.
The keyboard inside the app matches the real one.
Keyboard labels no longer look blurry.
```

### 앱스토어 (중국어 간체)

```
复制后，点按的卡片上会直接显示已复制。
恢复购买后会清楚告诉你结果。
iCloud 同步更加稳定。
应用内的键盘与实际键盘完全一致。
修复了键盘文字看起来模糊的问题。
```

### 앱스토어 (중국어 번체)

```
複製後，點按的卡片上會直接顯示已複製。
回復購買後會清楚告訴你結果。
iCloud 同步更加穩定。
App 內的鍵盤與實際鍵盤完全一致。
修正了鍵盤文字看起來模糊的問題。
```

### 앱스토어 (러시아어)

```
Нажатая карточка сразу показывает, что текст скопирован.
Восстановление покупок теперь сообщает результат.
Синхронизация iCloud стала надёжнее.
Клавиатура в приложении выглядит как настоящая.
Надписи на клавиатуре больше не размыты.
```

## 5.1.5

### 앱스토어 (한국어)

```
목록 맨 위에서 나에게 꼭 필요한 단축어 세 가지를 빈칸만 채워 만들 수 있어요.
계좌, 송금 정보, 명함, 학번처럼 불쑥 묻는 것은 키보드 빠른 줄 같은 자리에 늘 있어요.
설정의 나에게 맞추기에서 먼저 챙겨 드리는 세 가지를 볼 수 있어요.
시, 분, 초를 따로 넣어 {시}:{분}:{초} 처럼 원하는 모양으로 적을 수 있어요.
```

### App Store (English)

```
Create the three snippets you need most right from the top of your list, just fill in the blanks.
Things people ask for out of the blue, like your bank account, payment details or student ID, always sit in the same spot on the keyboard quick row.
See the three things we set up first for you in Settings under Fit to Me.
Insert the hour, minute, and second separately, like {hour}:{minute}:{second}.
```

### 앱스토어 (중국어 간체)

```
在列表顶部填好空格，就能创建你最需要的三条短语。
银行账户、收款信息、名片、学号这类随时会被问到的内容，会一直固定在键盘快捷栏的同一位置。
在设置的为我调整中，可以看到优先为你准备的三项。
时、分、秒可以分别插入，按 {hour}:{minute}:{second} 这样随意排列。
```

### 앱스토어 (중국어 번체)

```
在列表頂部填好空格，就能建立你最需要的三條短語。
銀行帳戶、收款資訊、名片、學號這類隨時會被問到的內容，會一直固定在鍵盤快捷列的同一位置。
在設定的為我調整中，可以看到優先為你準備的三項。
時、分、秒可以分別插入，依 {hour}:{minute}:{second} 這樣隨意排列。
```

### 앱스토어 (러시아어)

```
Создавайте три самые нужные фразы прямо в начале списка, просто заполнив поля.
То, что спрашивают внезапно, например номер счёта, платёжные данные или номер студенческого, всегда стоит на одном месте в быстрой строке клавиатуры.
В настройках, в разделе Под меня, видно три вещи, которые мы готовим для вас первыми.
Часы, минуты и секунды можно вставлять по отдельности, например {hour}:{minute}:{second}.
```

## 5.1.4

### 앱스토어 (한국어)

```
쓰임새를 고르지 않아도 저장한 단축어를 보고 알아서 맞춰요.
매주·매달 같은 때 쓰는 단축어는 그때가 오면 키보드 맨 앞에 서요.
같은 글을 자주 복사하면 단축어로 저장하자고 알려 드려요.
금액처럼 새로 친 값도 그 자리에서 저장해 둘 수 있어요.
카드가 살짝 떠 보이고, 누르면 쫀득하게 반응해요.
```

### App Store (English)

```
No need to pick a profile. The app adapts to the snippets you save.
Snippets you use weekly or monthly move to the front of the keyboard when their time comes.
Copy the same text often and we will offer to save it as a snippet.
Amounts you type can be saved right where you type them.
Cards lift off the background and squish softly when tapped.
```

### 앱스토어 (중국어 간체)

```
无需选择使用类型，应用会根据你保存的短语自动调整。
每周或每月固定使用的短语，到时间会排在键盘最前面。
经常复制同一段文字时，会提醒你保存为短语。
新输入的金额可以就地保存下来。
卡片微微浮起，按下时会有柔软的回弹。
```

### 앱스토어 (중국어 번체)

```
無需選擇使用類型，App 會根據你儲存的短語自動調整。
每週或每月固定使用的短語，到時間會排在鍵盤最前面。
經常複製同一段文字時，會提醒你儲存為短語。
新輸入的金額可以就地儲存下來。
卡片微微浮起，按下時會有柔軟的回彈。
```

### 앱스토어 (러시아어)

```
Больше не нужно выбирать профиль: приложение подстраивается под ваши фразы.
Фразы, которые вы используете раз в неделю или месяц, в нужный день встают первыми на клавиатуре.
Если вы часто копируете один и тот же текст, приложение предложит сохранить его как фразу.
Введённую сумму можно сохранить прямо там, где вы её набрали.
Карточки слегка приподняты и мягко пружинят при нажатии.
```

## 5.1.3

### 앱스토어 (한국어)

```
보내기 키를 설정에서 켜고 끌 수 있어요.
새 단축어는 적는 대로 임시저장돼요.
키보드에서 금액 칸이 비어 있어 바로 적어요.
카테고리를 넘길 때 목록이 흔들리지 않아요.
스택이 쌓인 카드로 보여 한눈에 구별돼요.
```

### App Store (English)

```
Turn the send key on or off in Settings.
Drafts save as you type a new snippet.
Amount fields start empty on the keyboard.
Lists stay steady as you swipe categories.
Stacks now look like a pile of cards.
```

### 앱스토어 (중국어 간체)

```
发送键可以在设置里打开或关闭。
新建短语时会边写边自动保存草稿。
键盘上的金额栏默认留空，直接输入。
左右切换分类时列表不再晃动。
短语堆显示为叠起的卡片，一眼就能认出。
```

### 앱스토어 (중국어 번체)

```
傳送鍵可以在設定裡開啟或關閉。
新增短語時會邊寫邊自動儲存草稿。
鍵盤上的金額欄預設留空，直接輸入。
左右切換分類時清單不再晃動。
短語堆顯示為疊起的卡片，一眼就能認出。
```

### 앱스토어 (러시아어)

```
Клавишу отправки можно включить в настройках.
Новая фраза сохраняется как черновик.
Поле суммы на клавиатуре теперь пустое.
Список не дёргается при смене категорий.
Стопки фраз выглядят как стопка карточек.
```

## 5.1.2

### 앱스토어 (한국어)

```
키보드 높이를 기본 키보드와 같게 맞출 수 있어요.
지우기와 보내기 키, 단축어 높이도 원하는 만큼 조절해요.
여러 값을 묶은 단축어 스택은 칸마다 이름이 붙어요.
빈칸에 넣어 둔 값의 순서가 더 이상 뒤집히지 않아요.
목록을 열고 편집할 때 화면이 덜컹이지 않아요.
```

### App Store (English)

```
Match the keyboard height to your system one.
Resize the delete and send keys, and snippet height.
A snippet stack now gives every slot a name.
Saved blank values keep the order you put them in.
The list stays still while you open and edit it.
```

### 앱스토어 (중국어 간체)

```
可以把键盘高度调成和系统键盘一样。
删除键、发送键和短语高度都能调。
短语堆的每一格现在都有名字。
填空里存过的值不再颠倒顺序。
打开和编辑列表时画面不再抖动。
```

### 앱스토어 (중국어 번체)

```
可以把鍵盤高度調成和系統鍵盤一樣。
刪除鍵、傳送鍵和短語高度都能調。
短語堆的每一格現在都有名字。
填空裡存過的值不再顛倒順序。
開啟和編輯清單時畫面不再抖動。
```

### 앱스토어 (러시아어)

```
Высота клавиатуры совпадает с системной.
Клавиши удаления, отправки и высота фраз настраиваются.
У каждой ячейки стопки фраз теперь есть имя.
Сохранённые значения полей держат свой порядок.
Список не дёргается, когда вы его открываете и правите.
```

## 5.1.1

### 앱스토어 (한국어)

```
설정을 갈래별로 정리해 찾기 쉬워졌습니다.
앱을 켤 때 화면이 흔들리지 않습니다.
키보드 미리보기가 한 번에 부드럽게 오르내립니다.
갈래를 넘기다 엉뚱한 곳으로 가지 않습니다.
Pro로 누리는 혜택을 한눈에 볼 수 있습니다.
```

### App Store (English)

```
Settings are now neatly grouped.
The app no longer jolts when it opens.
Keyboard preview now slides smoothly.
Swiping categories no longer jumps away.
See the Pro benefits you're using.
```

### 앱스토어 (중국어 간체)

```
设置按分类整理，更好找了。
打开 App 时画面不再晃动。
键盘预览会整体顺滑地升起和收起。
左右切换分类时不再跳到别处。
可以一眼看到正在享受的 Pro 权益。
```

### 앱스토어 (중국어 번체)

```
設定依分類整理，更好找了。
開啟 App 時畫面不再晃動。
鍵盤預覽會整體順暢地升起和收起。
左右切換分類時不再跳到別處。
可以一眼看到正在享受的 Pro 權益。
```

### 앱스토어 (러시아어)

```
Настройки удобно разложены по разделам.
При запуске экран больше не дёргается.
Превью клавиатуры движется плавно.
Смена категорий свайпом стала точной.
Видно, какие преимущества Pro у вас.
```

## 5.1.0

### 앱스토어 (한국어)

```
지구본을 눌러 다른 키보드로 넘어갑니다.
길게 누르면 이모지 키보드로 바로 갑니다.
지구본이 언제나 같은 자리에 있습니다.
보던 갈래가 그대로 열립니다.
단축어가 늘면 최근 쓴 것이 위에 뜹니다.
```

### App Store (English)

```
Tap the globe to switch keyboards.
Press and hold to jump straight to emoji.
The globe now always stays in place.
It opens on the category you were using.
Recent snippets show up as you add more.
```

### 앱스토어 (중국어 간체)

```
点地球键即可切换到其他键盘。
长按可直接切换到表情键盘。
地球键现在一直在原来的位置。
打开时还是上次看的分类。
短语变多后，最近用过的会排在上面。
```

### 앱스토어 (중국어 번체)

```
點地球鍵即可切換到其他鍵盤。
長按可直接切換到表情鍵盤。
地球鍵現在一直在原來的位置。
開啟時還是上次看的分類。
短語變多後，最近用過的會排在上面。
```

### 앱스토어 (러시아어)

```
Нажмите глобус, чтобы сменить клавиатуру.
Удерживайте, чтобы сразу открыть эмодзи.
Глобус теперь всегда на своём месте.
Открывается та категория, где вы были.
Частые фразы поднимаются наверх.
```

## 5.0.9

### 앱스토어 (한국어)

```
키보드에 보내기 키가 생겼습니다.
잠근 단축어도 여러 값 중에 골라 넣습니다.
키보드에서 사진이 붙여넣어집니다.
글과 사진을 함께 담아도 사진이 빠지지 않습니다.
함께 쓰면 좋은 앱을 설정에서 소개합니다.
```

### App Store (English)

```
The keyboard now has a send key.
Locked snippets let you pick which value goes in.
Images paste from the keyboard.
Snippets with text and a photo keep both.
Settings introduces apps worth pairing with this one.
```

### 앱스토어 (중국어 간체)

```
键盘上有发送键了。
锁住的短语也能挑一条值再填。
图片可以从键盘粘贴了。
图文一起存的短语，图片不会丢了。
设置里介绍了值得搭配使用的应用。
```

### 앱스토어 (중국어 번체)

```
鍵盤上有傳送鍵了。
鎖住的短語也能挑一條值再填。
圖片可以從鍵盤貼上了。
圖文一起存的短語，圖片不會不見了。
設定裡介紹了值得搭配使用的應用程式。
```

### 앱스토어 (러시아어)

```
На клавиатуре появилась клавиша отправки.
В закрытой фразе можно выбрать нужное значение.
Картинки вставляются прямо с клавиатуры.
Во фразе с текстом и фото фото больше не теряется.
В настройках собраны приложения, подходящие друг другу.
```

## 5.0.8

### 앱스토어 (한국어)

```
키보드에 지우기 키가 생겼습니다.
복사한 글에서 필요한 부분만 붙입니다.
키보드에서 빈칸을 한 칸씩 채웁니다.
날짜와 시간 서식을 직접 만듭니다.
번역이 모든 기기에서 되고 러시아어가 더해졌습니다.
```

### App Store (English)

```
The keyboard now has a delete key.
Paste only the part you need.
Fill placeholders one at a time.
Build your own date and time formats.
Translation on any device, plus Russian.
```


### 앱스토어 (중국어 간체)

```
键盘上有删除键了。
复制的内容里只粘贴需要的那部分。
键盘里的空位一个一个填。
日期和时间的样式可以自己做。
翻译在所有设备上都能用，还新增了俄语。
```

### 앱스토어 (중국어 번체)

```
鍵盤上有刪除鍵了。
複製的內容裡只貼上需要的那部分。
鍵盤裡的空位一個一個填。
日期和時間的樣式可以自己做。
翻譯在所有裝置上都能用，還新增了俄語。
```

### 앱스토어 (러시아어)

```
На клавиатуре появилась клавиша удаления.
Из скопированного вставляется только нужная часть.
Пустые поля заполняются по одному.
Формат даты и времени можно собрать самому.
Перевод работает на любом устройстве, добавлен русский.
```
