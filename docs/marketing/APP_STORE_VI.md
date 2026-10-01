# 베트남어 스토어 문안

App Store Connect 의 `vi` 로케일에 넣을 값입니다.
짜임은 [`APP_STORE_ES.md`](APP_STORE_ES.md) 와 같습니다. 거기 적힌 "남은 일" 순서(ASC 로케일 먼저, `LOCALES` 는 그다음)를 그대로 따릅니다.

## 왜 베트남어인가 (2026-09-30)

베트남이 330건입니다. 셋 중 레이아웃 위험이 가장 작아 번역만으로 효과를 볼 수 있는 시장입니다.

## 남은 일 (사람이 해야 함)

> 2026-09-30: 1~3번은 끝났다. ASC API 로 로케일을 만들어 이 문안(이름·부제·설명·키워드·프로모션·릴리즈노트)을 채웠고, `LOCALES` 에 넣었다.
> Pro(평생) 인앱 구매 표시 이름도 이 언어로 더했다. 연 구독은 지금 상태에서 API 가 언어 추가를 막아 영어 이름으로 나간다.

1. App Store Connect 웹에서 `vi` 로케일을 만들고 아래 값을 채운다. 인앱 구매 표시 이름도 더한다.
2. 로케일이 생긴 뒤 `deploy.env` 의 `LOCALES` 에 `vi` 를 더한다. `RELEASE_NOTES.md` 의 5.1.7 에는 절이 이미 있다.
   `RELEASE_NOTES.md` 5.1.7 의 이 언어 절 제목에서 `노출 안 함: ` 을 지운다. 로케일이 없을 때 제목을 못 알아본 DeployBar 가
   본문 글자로 판별해 라틴 문자를 `en` 으로 읽기 때문에 막아 둔 것이다.
3. 베트남어 화면을 한 번 본다. 성조 부호가 위아래로 붙어 줄 높이가 조금 달라질 수 있다.

## 용어

| 한국어 | 베트남어 |
| --- | --- |
| 단축어 | Cụm từ |
| 메모 | Ghi chú |
| 채우는 칸 | ô cần điền |
| 스택 | Ngăn xếp |

호칭은 `bạn`.

고정값은 `i18n/glossary.json` 에 있습니다.

---

## 이름 · 부제

| 칸 | 값 | 자수 |
| --- | --- | --- |
| 이름 | `Clip Keyboard: Gõ nhanh cụm từ` | 30 |
| 부제 | `Chèn câu hay dùng chỉ một chạm` | 30 |

---

## 설명

⚠️ 마지막 요금 문단은 5.2 수익 모델(`docs/product/FREE_USE_MODEL.md`) 기준입니다. 연 구독이 ASC 에 없으면 연 구독 부분을 뺍니다.

```
Đừng gõ đi gõ lại cùng một nội dung. Lưu một lần, lần sau chỉ cần một chạm.

Lưu số tài khoản, địa chỉ, lời giới thiệu hay câu mở đầu email thành cụm từ. Trong Zalo, Messenger, Mail, Safari hay bất cứ đâu bạn gõ được, chuyển sang ClipKeyboard, chạm một lần là văn bản vào ô ngay.

Tính năng

Cụm từ: nội dung đã lưu được chèn nguyên văn. Một chạm.
Mẫu: để trống những phần thay đổi thành ô cần điền, rồi điền bằng các giá trị đã lưu.
Ngăn xếp: gom nhiều giá trị vào một chỗ, gửi lần lượt hoặc chuyển qua lại bằng mũi tên.
Cụm từ bảo mật: khóa số hộ chiếu, số thẻ bằng Face ID, chỉ mở khi cần.
Bảng tạm thông minh: nội dung bạn sao chép được tự phân loại. Nhận ra email, số điện thoại, địa chỉ, số thẻ và IBAN để bạn tìm lại trong một giây.
Nhận dạng chữ: chụp thẻ hoặc giấy tờ, vuốt qua phần cần lấy, chỉ đoạn chữ đó trở thành giá trị.
Sao lưu iCloud: đổi điện thoại vẫn còn, kể cả cụm từ hình ảnh.

Trước khi bắt đầu

Đây là bàn phím để chèn văn bản đã lưu, không thay thế bàn phím bạn dùng để gõ. Chuyển sang khi cần chèn gì đó, xong thì chuyển lại.

Quyền riêng tư

Những gì bạn viết chỉ ở trên thiết bị của bạn. Nếu bật sao lưu iCloud, dữ liệu được mã hóa và lưu trong iCloud của chính bạn. Chúng tôi không thu thập nội dung cụm từ và không dùng công cụ phân tích bên thứ ba.

Miễn phí và Pro

Mọi tính năng miễn phí trong 100 lần chèn đầu tiên. Sau đó, những gì bạn đã tạo vẫn dùng như cũ; giới hạn miễn phí chỉ áp dụng cho nội dung mới. Pro mua một lần hoặc đăng ký theo năm, bỏ mọi giới hạn.

Dùng trên iPhone và iPad. Hỗ trợ tiếng Việt, Anh, Hàn, Nhật, Tây Ban Nha, Đức, Trung (giản thể và phồn thể), Nga và Thái.

Liên hệ: leeo@kakao.com
Hướng dẫn: https://m1zz.github.io/ClipKeyboard/tutorial.html?lang=en

Điều khoản sử dụng: https://m1zz.github.io/ClipKeyboard/terms.html?lang=en
```

---

## 키워드 (91/100자, 이름·부제 낱말 제외)

```
bảng tạm,sao chép,dán,mẫu,gõ tắt,số tài khoản,địa chỉ,trả lời nhanh,chữ ký,ghi chú,bàn phím
```

`gõ tắt` 는 베트남 사람이 이런 기능을 부르는 말입니다(Laban Key 등).
⚠️ 기계로 고른 말입니다. 그 나라 검색어 도구로 한 번 확인하는 편이 좋습니다.

---

## 프로모션 텍스트 (158/170자)

```
Nội dung đã sao chép, câu hay dùng, cả số tài khoản: chèn từ bàn phím chỉ với một chạm. Nay đã có tiếng Việt, và bạn có thể chọn ngôn ngữ ngay trong ứng dụng.
```

---

## 로케일별 링크

| 로케일 | 개인정보 처리방침 | 지원 · 마케팅 |
| --- | --- | --- |
| vi | `https://m1zz.github.io/ClipKeyboard/privacy.html?lang=en` | `https://m1zz.github.io/ClipKeyboard/tutorial.html?lang=en` |

공개 문서 페이지에 이 언어가 없어 영어를 가리킵니다.
