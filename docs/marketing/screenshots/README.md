# 스토어 에셋

App Store Connect 에 올리는 것들. 언어마다 한 벌씩 있다.

```
<언어>/                       원본 캡처 5장. **1242x2688** (제출 규격 그대로)
<언어>/marketing/             글과 목업을 입힌 5장. 같은 1242x2688
<언어>/preview/               앱 미리보기 영상 1개. 886x1920, 15~30초
```

언어는 `deploy.env` 의 `LOCALES` 를 따른다: ko · en · zh-Hans · zh-Hant · ru.

## 다시 만들기

1. **데이터 심고 언어 바꾸기**

   ```sh
   sh scripts/demo_setup.sh ko
   ```

   기기를 끄고 심은 뒤 다시 켠다. ⚠️ **켜 둔 채로 앱 그룹 UserDefaults 를 쓰면
   cfprefsd 가 옛 값을 도로 덮어쓴다.** `simctl spawn defaults write group.…` 도
   소용없다. 그 쪽은 앱 그룹 컨테이너가 아니라 시뮬레이터 홈에 쓴다.
   심는 것은 `scripts/demo_seed.py` 에 있다(단축어 8개 · 3칸짜리 스택 하나 ·
   빈칸에 저장해 둔 값 3개).

2. **원본 캡처**: 시뮬레이터를 손으로 몰면서 `xcrun simctl io <UDID> screenshot`.
   6.9인치 시뮬레이터는 1320x2868 로 뱉으므로 제출 규격으로 줄인다.

   ```sh
   ffmpeg -i in.png -vf "scale=1242:2699,crop=1242:2688" out.png
   ```

3. **마케팅 이미지**: `python3 scripts/make_marketing_screenshots.py <언어>`
   글은 그 파일의 `COPY` 에 언어별로 적혀 있다. 기계번역하지 않는다.

4. **미리보기 영상**: 녹화한 뒤 정지 구간을 잘라 규격으로 만든다.

   ```sh
   xcrun simctl io <UDID> recordVideo --codec h264 --force demo.mov
   python3 scripts/make_demo_video.py demo.mov out.mp4 24
   ```

   마지막 숫자는 목표 길이(초). 정지 구간을 몇 초씩 남길지 거꾸로 계산한다.
   손으로 맞추면 언어마다 어긋난다.

## 시연 순서

다섯 언어 모두 같은 순서로 찍는다. 이래야 나중에 한 언어만 다시 찍어도 어긋나지 않는다.

1. 목록에서 단축어 스택을 연다 (칸 이름이 보인다)
2. 키보드 미리보기로 가서 단축어 하나를 누른다 (글이 들어간다)
3. 템플릿을 누르고 저장해 둔 값을 고른다 (5.1.2 에서 고친 순서가 여기 보인다)
4. 설정 > 키보드 > 키보드 레이아웃 에서 키보드 높이를 바꾼다
