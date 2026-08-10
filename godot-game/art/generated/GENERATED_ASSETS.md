# 생성형 에셋 기록 — minimal-v2

이 폴더의 `minimal-v2` 에셋은 내장 이미지 생성 도구로 만든 뒤, Godot에서
픽셀 경계가 흔들리지 않도록 nearest-neighbor 방식과 제한 팔레트로 정리했습니다.

## 공통 프롬프트 방향

- 저작권이 있는 특정 게임이나 캐릭터를 복제하지 않는 오리지널 판타지 세계
- 단순한 실루엣, 굵고 읽기 쉬운 윤곽, 작은 화면에서도 구분되는 형태
- 16비트 콘솔 시대를 떠올리는 제한 색상 레트로 픽셀 아트
- 현대적인 광택, 과도한 장식, 사실적인 3D 렌더링, 글자와 로고 제외

## 프롬프트 세트

1. `lobby`: 달빛 아래 좌우의 두 성과 중앙 길, 검을 든 전사, 메뉴를 올릴 넓은 여백이 있는 16:9 배경.
2. `characters`: 얼굴과 발끝이 모두 보이는 전사·궁사·마법사의 세로형 전신 선택 카드, 동일한 카메라와 비율.
3. `skills`: 검격·연속베기·화염장판·회오리·보호막·번개·검우 등 28종을 정확한 7×4 격자에 배치한 아이콘 아틀라스.
4. `items`: 검·레이피어·대검·단검·목걸이·반지·팔찌를 정확한 4×4 격자에 배치한 아이콘 아틀라스.
5. `factory HUD`: 빈 칸·활성 칸·다리·분열·골드·지속시간·RELOAD·경험치를 정확한 4×2 격자에 배치한 HUD 아틀라스.
6. `terrain WFC`: 잔디 변형·길·물·물가 방향 타일·다리·숲·바위·유적·성 바닥·캠프를 정확한 5×4 격자에 배치한 정사각 타일 아틀라스.
7. `combat VFX`: 검격·장판·회전검·보호막·투사체 효과를 정확한 4×4 격자로 구성하고 단색 크로마 배경을 사용한 효과 아틀라스.
8. `onboarding`: 이동/대시, 왼쪽에서 오른쪽으로 흐르는 딜싸이클, 카드 배치와 공장 확장, 낮/밤 모험을 글자 없이 설명하는 2×2 장면.

## 게임이 실제로 불러오는 파일

- `backgrounds/lobby-minimal-v2.png`
- `characters/swordsman-card-minimal-v2.png`
- `characters/archer-card-minimal-v2.png`
- `characters/mage-card-minimal-v2.png`
- `onboarding/minimal-v2/page-0.png` ~ `page-3.png`
- `ui/skill-atlas-minimal-v2-runtime.png`
- `ui/item-atlas-minimal-v2-runtime.png`
- `ui/factory-hud-atlas-minimal-v2-runtime.png`
- `world/terrain-atlas-wfc-v2-runtime.png`
- `vfx/combat-vfx-minimal-v2-runtime.png`

`*-runtime.png`는 원본 생성 이미지의 구도를 바꾸지 않고 픽셀 크기와 팔레트만
게임 실행 해상도에 맞춘 파일입니다. 원본 `minimal-v2.png`도 같은 폴더에 남겨
추후 다시 조절할 수 있습니다.
