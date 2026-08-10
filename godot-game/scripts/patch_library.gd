class_name PatchLibrary
extends RefCounted

const PATCHES: Array[Dictionary] = [
	{"id":"multithread", "code":"쌍월", "name":"쌍월의 검무", "symbol":"II", "player_title":"추가 타격", "player_desc":"공격 횟수가 1회 증가합니다.", "debt_title":"마물 증원", "debt_desc":"마왕이 더 많은 부하를 부릅니다."},
	{"id":"firewall", "code":"수호", "name":"왕가의 수호", "symbol":"◇", "player_title":"수호막 2회", "player_desc":"랭크마다 피해 차단막 2회를 얻습니다.", "debt_title":"검은 갑주", "debt_desc":"마왕과 일부 마물이 보호막을 얻습니다."},
	{"id":"overclock", "code":"격노", "name":"붉은 투지", "symbol":"▲", "player_title":"공격과 기동 강화", "player_desc":"공격력·공격 속도·이동 속도가 증가합니다.", "debt_title":"마왕의 격노", "debt_desc":"체력이 낮아진 적이 폭주합니다."},
	{"id":"cache", "code":"생명", "name":"대지의 숨결", "symbol":"▰", "player_title":"생명과 흡수 범위", "player_desc":"최대 체력과 경험치 흡수 범위가 증가합니다.", "debt_title":"쇠약의 안개", "debt_desc":"마왕이 움직임을 늦추는 안개를 만듭니다."},
	{"id":"recursion", "code":"메아리", "name":"메아리 칼날", "symbol":"∞", "player_title":"연쇄 타격", "player_desc":"공격이 다음 적에게 한 번 더 이어집니다.", "debt_title":"분열의 저주", "debt_desc":"일부 마물이 쓰러지며 작은 마물로 갈라집니다."},
	{"id":"targeting", "code":"매눈", "name":"매의 눈", "symbol":"◎", "player_title":"치명타와 관통", "player_desc":"치명타 확률과 관통 횟수가 증가합니다.", "debt_title":"추적의 눈", "debt_desc":"마왕이 플레이어를 쫓는 마탄을 발사합니다."},
	{"id":"rollback", "code":"불사조", "name":"불사조의 맹세", "symbol":"↶", "player_title":"한 번의 부활", "player_desc":"랭크마다 치명상을 한 번 넘깁니다.", "debt_title":"죽음의 거부", "debt_desc":"마왕과 일부 마물이 한 번 되살아납니다."},
	{"id":"hotfix", "code":"성광", "name":"성스러운 파동", "symbol":"✦", "player_title":"8킬마다 성광", "player_desc":"처치가 누적되면 주변에 성광 피해를 줍니다.", "debt_title":"검은 재생", "debt_desc":"마왕과 일부 마물이 체력을 회복합니다."},
	{"id":"cleave", "code":"거인", "name":"거인의 궤적", "symbol":"╱", "player_title":"범위와 위력 강화", "player_desc":"공격 범위와 근접 공격 각도가 넓어집니다.", "debt_title":"대지 파쇄", "debt_desc":"마왕의 육탄 공격이 더 위협적이 됩니다."},
	{"id":"haste", "code":"질풍", "name":"질풍의 발걸음", "symbol":"≫", "player_title":"민첩한 연격", "player_desc":"이동 속도와 공격 속도가 증가합니다.", "debt_title":"폭풍 추격", "debt_desc":"적이 더 빠르게 폭주합니다."},
	{"id":"blood_pact", "code":"흡혈", "name":"붉은 맹약", "symbol":"♥", "player_title":"처치 회복", "player_desc":"적을 처치할 때 체력을 회복합니다.", "debt_title":"피의 재생", "debt_desc":"마왕이 전투 중 빠르게 회복합니다."},
	{"id":"frost_armor", "code":"빙벽", "name":"서리 갑주", "symbol":"※", "player_title":"피해 경감", "player_desc":"받는 피해가 줄고 최대 체력이 증가합니다.", "debt_title":"빙결 안개", "debt_desc":"마왕 주변에서 이동 속도가 감소합니다."},
	{"id":"thunder", "code":"천뢰", "name":"천뢰의 인장", "symbol":"ϟ", "player_title":"연쇄 낙뢰", "player_desc":"일정 처치마다 가까운 적에게 낙뢰가 떨어집니다.", "debt_title":"추적 낙뢰", "debt_desc":"마왕이 추적 마탄을 강화합니다."},
	{"id":"guardian_blade", "code":"수호검", "name":"별의 수호검", "symbol":"✧", "player_title":"회전하는 검", "player_desc":"플레이어 주위를 도는 공격 검이 생깁니다.", "debt_title":"검은 위성", "debt_desc":"마왕의 갑주와 소환 능력이 강화됩니다."},
	{"id":"flame_field", "code":"화진", "name":"잔불의 마법진", "symbol":"◉", "player_title":"주기적 화염 장판", "player_desc":"이동 경로에 지속 피해를 주는 화염 장판을 설치합니다.", "debt_title":"불타는 왕좌", "debt_desc":"마왕의 폭주와 공격 주기가 강화됩니다."},
	{"id":"aura", "code":"결계", "name":"서리숨결 결계", "symbol":"◌", "player_title":"상시 피해 오라", "player_desc":"주변의 적에게 짧은 간격으로 결계 피해를 줍니다.", "debt_title":"쇠약의 영토", "debt_desc":"마왕의 감속 영역이 강화됩니다."},
	{"id":"wisdom", "code":"지혜", "name":"별읽기의 지혜", "symbol":"▣", "player_title":"경험치 획득 +25%", "player_desc":"몬스터가 주는 경험치가 랭크마다 25% 증가합니다.", "debt_title":"탐식의 지식", "debt_desc":"마왕의 체력과 재생 능력이 강해집니다."},
	{"id":"dash_training", "code":"순풍", "name":"순풍의 보석", "symbol":"➤", "player_title":"대시 재사용·거리 강화", "player_desc":"대시 쿨타임이 줄고 같은 무적 시간에 더 멀리 이동합니다.", "debt_title":"마왕의 도약", "debt_desc":"마왕이 더 빠르게 추격하고 폭주합니다."},
	{"id":"dash_blade", "code":"섬격", "name":"유성 섬격", "symbol":"✣", "player_title":"공격하는 대시", "player_desc":"대시로 통과한 적에게 강한 피해를 한 번 줍니다.", "debt_title":"파멸 돌진", "debt_desc":"마왕의 육탄 공격력이 강화됩니다."},
	{"id":"moon_barrier", "code":"월막", "name":"달빛 재생막", "symbol":"⬡", "player_title":"재생하는 보호막", "player_desc":"보호막 용량을 얻고 소모한 막을 일정 시간마다 재생합니다.", "debt_title":"불멸의 갑주", "debt_desc":"마왕의 검은 갑주가 더 자주 돌아옵니다."}
]

static func all() -> Array[Dictionary]:
	return PATCHES.duplicate(true)

static func by_id(id: String) -> Dictionary:
	for patch: Dictionary in PATCHES:
		if patch["id"] == id:
			return patch
	return {}

static func random_two(rng: RandomNumberGenerator) -> Array[Dictionary]:
	var pool := all()
	for index in range(pool.size() - 1, 0, -1):
		var other := rng.randi_range(0, index)
		var temp: Dictionary = pool[index]
		pool[index] = pool[other]
		pool[other] = temp
	return [pool[0], pool[1]]

static func debt_module(id: String) -> String:
	match id:
		"cleave": return "overclock"
		"haste": return "overclock"
		"blood_pact": return "hotfix"
		"frost_armor": return "cache"
		"thunder": return "targeting"
		"guardian_blade": return "firewall"
		"flame_field": return "overclock"
		"aura": return "cache"
		"wisdom": return "hotfix"
		"dash_training": return "overclock"
		"dash_blade": return "targeting"
		"moon_barrier": return "firewall"
		_: return id
