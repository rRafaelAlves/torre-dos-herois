extends RefCounted

const ICONS := {
	"attack": preload("res://assets/ui_icons/attack.svg"),
	"defend": preload("res://assets/ui_icons/defend.svg"),
	"rescue": preload("res://assets/ui_icons/rescue.svg"),
	"skills": preload("res://assets/ui_icons/skills.svg"),
	"bonuses": preload("res://assets/ui_icons/bonuses.svg"),
	"golpe_poderoso": preload("res://assets/ui_icons/golpe_poderoso.svg"),
	"guarda_protetora": preload("res://assets/ui_icons/guarda_protetora.svg"),
	"disparo_duplo": preload("res://assets/ui_icons/disparo_duplo.svg"),
	"flecha_debilitante": preload("res://assets/ui_icons/flecha_debilitante.svg"),
	"raio_arcano": preload("res://assets/ui_icons/raio_arcano.svg"),
	"maldicao_venenosa": preload("res://assets/ui_icons/maldicao_venenosa.svg"),
	"cura": preload("res://assets/ui_icons/cura.svg"),
	"purificacao": preload("res://assets/ui_icons/purificacao.svg"),
	"bola_de_fogo": preload("res://assets/ui_icons/bola_de_fogo.svg"),
	"onda_arcana": preload("res://assets/ui_icons/onda_arcana.svg"),
	"golpe_carrasco": preload("res://assets/ui_icons/golpe_carrasco.svg"),
	"fortaleza_inabalavel": preload("res://assets/ui_icons/fortaleza_inabalavel.svg"),
	"instinto_predador": preload("res://assets/ui_icons/instinto_predador.svg"),
	"chuva_flechas": preload("res://assets/ui_icons/chuva_flechas.svg"),
	"maldicao_coletiva": preload("res://assets/ui_icons/maldicao_coletiva.svg"),
	"vampirismo_arcano": preload("res://assets/ui_icons/vampirismo_arcano.svg"),
	"prece_restauradora": preload("res://assets/ui_icons/prece_restauradora.svg"),
	"milagre_divino": preload("res://assets/ui_icons/milagre_divino.svg"),
	"ruptura_arcana": preload("res://assets/ui_icons/ruptura_arcana.svg"),
	"tempestade_arcana": preload("res://assets/ui_icons/tempestade_arcana.svg"),
}


static func texture_for(icon_id: String) -> Texture2D:
	return ICONS.get(icon_id)
