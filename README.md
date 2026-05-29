# 📄 DeskGPT: Standalone macOS ChatGPT Application

<p align="center">
  <img src="/Users/hunchulchoi/.gemini/antigravity/brain/46601610-fd48-492e-bdeb-86cf24510bea/deskgpt_flat_icon_1780031119679.png" width="160" height="160" alt="DeskGPT Flat App Icon" />
</p>

**DeskGPT**는 `https://chatgpt.com`을 macOS 데스크톱 환경에서 독립된 프리미엄 프로그램으로 가동해 주는 초경량 네이티브 애플리케이션입니다. 

Electron 이나 Chromium 계열의 무거운 크로스 플랫폼 프레임워크 대신, macOS 시스템의 순수 **Cocoa (AppKit)** 프레임워크와 **WebKit (WKWebView)** 엔진을 엮어 빌드하여 **용량이 극도로 작고(1MB 미만) 자원 점유가 매우 낮으며 즉시 실행**됩니다.

---

## ✨ 핵심 핵심 기능 (Key Features)

* **쿠키 및 세션 완벽 보존**: 영구 웹 데이터 저장소(`WKWebsiteDataStore.default()`)를 연동하여, 앱을 끄고 다시 켜도 자동 로그인이 그대로 유지됩니다.
* **봇 차단 우회**: OpenAI와 Cloudflare의 웹뷰/봇 감지 보안 필터를 우회하기 위해 최신 Safari 표준 User Agent를 주입합니다.
* **항상 위에 유지 (Always on Top) ⭐️**: 코딩이나 문서 작성 중 ChatGPT를 구석에 띄우고 참고할 수 있도록 창 플로팅 모드를 완벽히 제공합니다. (`Cmd + Shift + T` 단축키 토글)
* **PDF Chunker & Smart Injector 📁**: 대용량 PDF 파일을 끌어올리면 macOS 내장 **`PDFKit`**이 텍스트를 고속 추출하고, 원하는 글자수(기본 4,000자)로 쪼개어 버튼 클릭 한 번으로 ChatGPT 입력창에 React 감지 이벤트와 함께 스마트하게 주입합니다. (`Cmd + Shift + P` 단축키 토글)
* **네이티브 파일 업/다운로드**: 대화 중 코드 파일이나 이미지를 업로드하고, 결과물 데이터를 로컬에 저장할 때 macOS 네이티브 패널(`NSOpenPanel`, `NSSavePanel`)과 완벽히 연동됩니다.
* **네이티브 브라우징 & 줌 단축키**: 새로고침(`Cmd+R`), 뒤로가기(`Cmd+[`), 앞으로가기(`Cmd+]`), 화면 배율 조절(`Cmd+=` / `Cmd+-` / `Cmd+0`) 단축키를 브라우저처럼 똑같이 매핑했습니다.
* **세션 비상 리셋**: 로그인 상태가 꼬였거나 캐시 청소가 필요할 경우 Help 메뉴를 통해 완전 초기화 후 강제 리로드가 가능합니다.

---

## 📂 파일 구조 (File Structure)

```text
├── src/
│   ├── main.swift             # 앱의 부트스트랩 및 이벤트 런타임 가동
│   ├── AppDelegate.swift      # 애플리케이션 수명 주기, 시스템 메뉴바 및 윈도우 생성/제어
│   ├── DeskGPTViewController.swift # WKWebView 웹뷰 연동, 영속성 저장소, 파일 업/다운로드, 텍스트 주입
│   ├── DeskGPTPDFViewController.swift # PDFKit 기반 텍스트 추출, 청킹 알고리즘 및 텍스트 자동 주입 UI
│   └── Info.plist             # 앱의 메타데이터 및 아이콘 리소스 맵
├── build.sh                   # 원터치 자동 컴파일 & 앱 패키징 빌드 스크립트
├── README.md                  # 프로젝트 설명서
└── docs/                      # 프로젝트 상세 설계(Specs) 및 개발 문서
```

---

## 🛠️ 빌드 및 설치 방법 (Build & Run)

시스템에 Xcode Command Line Tools (`swiftc` 컴파일러 내장)만 깔려 있다면, 터미널에서 원터치로 직접 빌드할 수 있습니다.

1. **리포지토리 클론 및 터미널 이동**:
   ```bash
   cd gpt_exe
   ```

2. **빌드 스크립트 실행 (원터치 컴파일 & 아이콘 패키징)**:
   ```bash
   chmod +x build.sh
   ./build.sh
   ```
   *스크립트가 실행되면 고해상도 앱 아이콘 PNG를 규격별로 sips 리사이징한 뒤 `AppIcon.icns`로 묶고, Swift 파일을 기민하게 컴파일하여 `build/DeskGPT.app` 번들을 완성합니다.*

3. **앱 실행**:
   ```bash
   open build/DeskGPT.app
   ```

> [!TIP]
> 완성된 `DeskGPT.app` 번들을 macOS의 `/Applications` (응용 프로그램) 디렉토리로 드래그하여 이동시키면, Launchpad 및 Spotlight 검색(`Cmd + Space -> DeskGPT`)에서 즉시 다른 정식 독립 프로그램들과 같이 완전하게 상시 구동할 수 있습니다!

---

## 🔮 향후 로드맵 (Future RAG Extensions)

추후 앱의 고도화 패치로 아래 기능의 확장이 가능하도록 아키텍처가 설계되어 있습니다.
* **로컬 오프라인 RAG 시스템**: Apple Silicon(M 시리즈)의 신경망 가속(ANE)을 위해 `CoreML`로 구동되는 다국어 임베딩 모델(`Multilingual-MiniLM`) 연동.
* **멀티 Vector DB**: macOS Application Support 디렉토리에 카테고리별 SQLite 벡터 스토어(`Category.db`)를 구축하여 주제별 격리 문서 학습 지원.
