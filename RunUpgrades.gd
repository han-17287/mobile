extends RefCounted
## Run-only weapon branches. Equipment grades and the base economy are untouched.
const NAMES={"rifle":"소총","katana":"카타나","hammer":"망치","bat":"방망이","shield":"방패"}
const EVOLUTIONS={"rifle":"탄막 폭풍","katana":"월광 난무","hammer":"지진 분쇄기","bat":"메테오 홈런","shield":"철벽 행진"}
const STEPS={
	"rifle":["동시 발사 +1 · 피해 +15%","3발 발사 · 관통 +1","4발 발사 · 적 사이 도탄","5발 발사 · 적중 시 폭발"],
	"katana":["참격 범위 확대 · 피해 증가","콤보 마지막에 자동 검기","매 타격마다 자동 검기","넓은 참격 · 검기 추가 관통"],
	"hammer":["강타 범위 확대 · 피해 증가","강타마다 원형 충격파","충격파 확대 · 차지 강화","광역 충격파 · 회전 반경 확대"],
	"bat":["범위·밀치기 증가","밀린 적끼리 충돌 피해","홈런 공이 적 사이 도탄","홈런 공 3개 동시 발사"],
	"shield":["타격 범위 확대 · 피해 증가","2연타 후 반격 충격파","돌진 범위 확대 · 재사용 단축","주변을 쓸어내는 반격 파동"]}
const EVO_TEXT={"rifle":"탄환 +2 · 관통·도탄·대형 폭발","katana":"매 공격 3방향 검기 · 전방을 절단","hammer":"거대 강타 · 연쇄 지진 충격파","bat":"3콤보 자동 홈런 · 특수 5연발 폭발","shield":"3연타 · 광역 반격 · 넓은 무적 돌진"}
static func rank(skills: Dictionary,kind: String) -> int:
	return int(skills.get("weapon_"+kind,0))
static func evolved(skills: Dictionary,kind: String) -> bool:
	return int(skills.get("evolve_"+kind,0))>0
static func support(kind: String) -> String:
	return "spread" if kind=="rifle" else "area"
static func ready(skills: Dictionary,kind: String) -> bool:
	return rank(skills,kind)>=4 and int(skills.get(support(kind),0))>=2 and not evolved(skills,kind)
static func description(key: String,skills: Dictionary) -> Array:
	if key.begins_with("evolve_"):
		var kind=key.trim_prefix("evolve_")
		return [EVOLUTIONS[kind],EVO_TEXT[kind],"EVOLUTION"]
	var kind=key.trim_prefix("weapon_")
	var tier=rank(skills,kind)
	return [NAMES[kind]+" 강화",STEPS[kind][mini(tier,3)],"WEAPON"]
