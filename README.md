# Nproject

Nproject는 태국에 거주하거나 여행하는 한국인을 위한 Flutter 기반 중고거래 앱입니다. 첫 목표는 당근마켓의 중고거래 경험을 참고하되, 태국 한인 생활권에 필요한 기능만 남긴 실사용 가능한 MVP를 만드는 것입니다.

## 핵심 방향

- 대상: 방콕, 파타야, 치앙마이 등 태국 거주 한국인과 여행자
- 채팅 없음: 카카오톡, 라인, 연락처 등 외부 연락 수단 사용
- 지도 없음: 거래 희망 장소는 텍스트로 입력
- 사진: 물품당 최대 5장, 상세 화면에서 슬라이드로 표시
- 평판: 매너 온도 없이 거래 횟수만 표시

## 게시판

- `중고거래`: 일반 중고 물품
- `해주세요`: 한국과 태국을 오가는 사람에게 물품 전달을 부탁하는 게시판
- `화폐 교환`: 여행 후 남은 소액의 THB/KRW를 사용자끼리 교환하는 게시판

UI에서는 법적 오해를 줄이기 위해 `환전`이라는 표현 대신 `화폐 교환`을 사용합니다.

## 현재 구현

- 홈 피드와 글쓰기 버튼
- 게시판별 전용 등록 폼
- 회원 가입 화면
- 로그아웃 메뉴
- 카테고리 재편성
  - `여성의류`, `여성잡화` 제거
  - `여성패션/잡화`로 통합
  - `회원권` 추가
- 물품 상세 화면
- Firebase Auth, Firestore, Storage 패키지 설치

## 앱 실행 및 테스트

개발 PC에서 실행:

```powershell
cd C:\NProjects
flutter pub get
flutter run
```

웹으로 빠르게 확인:

```powershell
cd C:\NProjects
flutter run -d chrome
```

정적 분석과 자동 테스트:

```powershell
cd C:\NProjects
flutter analyze
flutter test
```

Android APK 생성:

```powershell
cd C:\NProjects
flutter build apk --release
```

생성된 APK 위치:

```text
C:\NProjects\build\app\outputs\flutter-apk\app-release.apk
```

Android 휴대폰 설치 테스트:

1. 휴대폰에서 개발자 옵션과 USB 디버깅을 켭니다.
2. USB로 PC에 연결합니다.
3. 아래 명령으로 연결을 확인합니다.

```powershell
flutter devices
```

4. 연결된 기기에 바로 실행합니다.

```powershell
flutter run
```

Firebase 실제 연결은 Firebase 프로젝트 생성 후 아래 명령으로 설정 파일을 생성해야 합니다.

```powershell
flutterfire configure
```

그 다음 `lib/main.dart`에 Firebase 초기화 코드를 넣고, 현재 샘플 데이터를 Firestore 데이터로 교체하면 됩니다.
