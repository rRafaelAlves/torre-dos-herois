extends SceneTree

const RunState = preload("res://systems/run_state.gd")
const Relics = preload("res://data/relics.gd")
const SAVE_A := "user://v42_shop_a.json"
const SAVE_B := "user://v42_shop_b.json"
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("run_all")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)


func clean(path: String) -> void:
	for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))


func create_camp_run(path: String) -> RunState:
	var run := RunState.new()
	run.save_path = path
	run.initialize(path)
	var team: Array[String] = ["guerreiro", "bruxa"]
	check(run.new_attempt(team), "Expedição criada em %s" % path)
	run.attempt["floor"] = 5
	run.attempt["completed"] = 4
	run.attempt["phase"] = "combat"
	check(run.choose_merchant_camp(true), "Acampamento fica disponível em %s" % path)
	return run


func run_all() -> void:
	clean(SAVE_A)
	clean(SAVE_B)
	var run := create_camp_run(SAVE_A)
	run.permanent["coins"] = 0
	check(run.save(), "Saldo inicial salvo")
	var offers: Array = run.ensure_merchant_shop_stock()
	check(offers.size() == 6, "A loja gera seis ofertas")
	var counts := {"simple": 0, "rare": 0, "epic": 0}
	var ids: Dictionary = {}
	var simple_index := -1
	var second_simple_index := -1
	for index in range(offers.size()):
		var offer: Dictionary = offers[index]
		var rarity := str(Relics.DEFINITIONS[offer["id"]]["rarity"])
		counts[rarity] += 1
		ids[offer["id"]] = true
		if rarity == "simple":
			if simple_index < 0:
				simple_index = index
			else:
				second_simple_index = index
	check(counts == {"simple": 3, "rare": 2, "epic": 1}, "Estoque tem 3 simples, 2 raras e 1 épica")
	check(ids.size() == 6, "Ofertas não repetem exemplares")
	check(run.ensure_merchant_shop_stock() == offers, "Reabrir a loja mantém as mesmas ofertas")
	var failed_purchase := run.buy_merchant_relic(simple_index, "temporary")
	check(not failed_purchase["ok"] and int(run.permanent["coins"]) == 0, "Saldo insuficiente não desconta moedas")
	check(not bool(run.attempt["merchant_shop"]["offers"][simple_index]["sold"]), "Compra sem saldo não vende a oferta")
	var temporary_id := str(offers[simple_index]["id"])
	var temporary_price := Relics.shop_price(temporary_id, "temporary")
	run.permanent["coins"] = temporary_price + 700
	check(run.save(), "Saldo suficiente preparado")
	var purchase := run.buy_merchant_relic(simple_index, "temporary")
	check(purchase["ok"], "Compra temporária concluída")
	check(int(run.permanent["coins"]) == 700, "Compra temporária desconta o preço exato")
	check(_inventory_contains(run.attempt.get("relic_inventory", []), temporary_id, purchase["uid"]), "Relíquia temporária vai ao inventário da expedição")
	check(not _inventory_has_uid(run.permanent.get("relic_inventory", []), purchase["uid"]), "Relíquia temporária não contamina inventário permanente")
	var duplicate := run.buy_merchant_relic(simple_index, "permanent")
	check(not duplicate["ok"] and int(run.permanent["coins"]) == 700, "Oferta vendida não pode ser comprada duas vezes")
	var temporary_bearer := "" if str(Relics.DEFINITIONS[temporary_id].get("scope", "hero")) == "team" else "guerreiro"
	check(run.equip_relic(str(purchase["uid"]), temporary_bearer, "camp"), "Compra pode ser equipada imediatamente")
	var stock_before_reload: Array = run.attempt["merchant_shop"]["offers"].duplicate(true)
	var reloaded := RunState.new()
	reloaded.initialize(SAVE_A)
	check(reloaded.attempt["merchant_shop"]["offers"] == stock_before_reload, "Ofertas e vendas sobrevivem à recarga")
	var second_id := str(stock_before_reload[second_simple_index]["id"])
	var permanent_purchase := reloaded.buy_merchant_relic(second_simple_index, "permanent")
	check(permanent_purchase["ok"], "Compra permanente concluída")
	check(_inventory_contains(reloaded.permanent.get("relic_inventory", []), second_id, permanent_purchase["uid"]), "Relíquia permanente fica no salvamento")
	check(int(reloaded.permanent["coins"]) == 0, "Compra permanente usa seu preço centralizado")
	var permanent_bearer := "" if str(Relics.DEFINITIONS[second_id].get("scope", "hero")) == "team" else "guerreiro"
	check(reloaded.equip_relic(str(permanent_purchase["uid"]), permanent_bearer, "camp"), "Relíquia permanente pode ser equipada no acampamento")
	check(reloaded.finish_merchant_camp(), "Acampamento fecha sem interromper expedição")
	check(reloaded.end_attempt("defeat").size() > 0, "Expedição pode terminar após compra")
	check(_inventory_contains(reloaded.permanent.get("relic_inventory", []), second_id, permanent_purchase["uid"]), "Relíquia permanente sobrevive à derrota")
	check(reloaded.attempt.is_empty(), "Relíquias temporárias são limpas ao encerrar tentativa")
	check(reloaded.new_attempt(["guerreiro"]), "Nova expedição inicia")
	check(reloaded.attempt["merchant_shop"] == {}, "Nova expedição descarta o estoque anterior")
	var other := create_camp_run(SAVE_B)
	var other_stock := other.ensure_merchant_shop_stock()
	check(other_stock.size() == 6 and other.permanent["coins"] == 0, "Outro salvamento recebe loja e saldo independentes")
	var check_a := RunState.new()
	check_a.initialize(SAVE_A)
	check(check_a.permanent.get("relic_inventory", []).size() == 1, "Trocar de salvamento preserva inventário permanente isolado")
	for path in [SAVE_A, SAVE_B]:
		clean(path)
	if failures.is_empty():
		print("V42 SHOP: %d checks passed" % checks)
		quit(0)
	else:
		push_error("V42 SHOP: %d/%d checks failed: %s" % [failures.size(), checks, ", ".join(failures)])
		quit(1)


func _inventory_contains(inventory: Array, relic_id: String, uid: String) -> bool:
	for item in inventory:
		if str(item.get("id", "")) == relic_id and str(item.get("uid", "")) == uid:
			return true
	return false


func _inventory_has_uid(inventory: Array, uid: String) -> bool:
	for item in inventory:
		if str(item.get("uid", "")) == uid:
			return true
	return false
