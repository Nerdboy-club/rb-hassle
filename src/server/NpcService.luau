-- NPC острова: диалоги, задания, лавки, казино, выход. Каждая роль (role) — таблица talk/choose.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Cards = require(Shared.Cards)
local Npcs = require(Shared.Npcs)
local Remotes = require(Shared.Remotes)
local Util = require(Shared.Util)
local Zones = require(Shared.Zones)

local Binder = require(script.Parent.Binder)
local CardRegistry = require(script.Parent.CardRegistry)
local PlayerData = require(script.Parent.PlayerData)
local QuizService = require(script.Parent.QuizService)
local RigBuilder = require(script.Parent.RigBuilder)
local ShopService = require(script.Parent.ShopService)
local Status = require(script.Parent.Status)
local WorldBuilder = require(script.Parent.WorldBuilder)

local NpcService = {}

type Option = { id: string, label: string }
type Context = {
	player: Player,
	profile: PlayerData.Profile,
	npcId: string,
	npc: Npcs.Npc,
	say: (text: string, options: { Option }?) -> (),
	close: () -> (),
}

local ids = {
	TICKET = 9,
	SWORD = 4,
	BEACH = 27,
	GOLD = 5,
	BANDIT_GEM = 2,
	CATDINER = 44,
	KING_CARD = 31,
	MEDICINE = 201,
	SANDWICH = 203,
	FIRST = 95,
}

local TICKET_PRICE = 5000
local GUARD_BRIBE = 8000
local DUEL_COOLDOWN = 30

local allowed: { [Player]: { npcId: string, options: { [string]: boolean } } } = {}
local lastDuel: { [Player]: { [string]: number } } = {}
local rng = Random.new()

-- NPC с этими ролями бродят вокруг своего поста; остальные стоят, но дышат и поворачиваются к игроку
local ROAMING = { eta = true, portmaster = true, razor = true, host = true, catdiner = true, goldgirl = true, beachnpc = true, ging = true }
local ROAM_RADIUS = 9
local WALK_SPEED = 3.5
local NOTICE_DISTANCE = 18

type Actor = {
	model: Model,
	scale: number,
	home: Vector3,
	position: Vector3,
	roam: boolean,
	goal: Vector3?,
	waitUntil: number,
	phase: number,
	facing: Vector3,
}

local actors: { Actor } = {}
local npcHome: { [string]: Vector3 } = {}
local MAX_TALK_DISTANCE = 40 -- выбор в диалоге принимается, только пока игрок рядом с NPC

local function say(player: Player, npcId: string, npc: Npcs.Npc, text: string, options: { Option }?)
	local list = options or {}
	local set = {}
	for _, option in list do
		set[option.id] = true
	end
	allowed[player] = { npcId = npcId, options = set }
	Remotes.Dialog:FireClient(player, { npcId = npcId, name = npc.name, text = text, options = list })
end

local function context(player: Player, profile: PlayerData.Profile, npcId: string, npc: Npcs.Npc): Context
	return {
		player = player,
		profile = profile,
		npcId = npcId,
		npc = npc,
		say = function(text, options)
			say(player, npcId, npc, text, options)
		end,
		close = function()
			allowed[player] = nil
			Remotes.Dialog:FireClient(player, { close = true })
		end,
	}
end

--- Бросок «дуэли»: шанс растёт от заклинания «Удача».
local function duelWins(player: Player, baseChance: number): boolean
	local chance = baseChance + (Status.has(player, "fortune") and 0.1 or 0)
	return rng:NextNumber() < chance
end

local function onCooldown(player: Player, key: string): number
	local last = lastDuel[player] and lastDuel[player][key] or -1e9
	local left = DUEL_COOLDOWN - (os.clock() - last)
	return left > 0 and left or 0
end

local function markDuel(player: Player, key: string)
	lastDuel[player] = lastDuel[player] or {}
	lastDuel[player][key] = os.clock()
end

local function missingFrom(profile: PlayerData.Profile, needed: { number }): { string }
	local missing = {}
	for _, id in needed do
		if not Binder.hasId(profile, id) then
			local card = Cards.get(id)
			table.insert(missing, card and card.name or tostring(id))
		end
	end
	return missing
end

-- ===================== роли =====================

local roles: { [string]: { talk: (Context) -> (), choose: (Context, string) -> () } } = {}

roles.eta = {
	talk = function(ctx)
		local first = not ctx.profile.flags.metEta
		if first then
			ctx.profile.flags.metEta = true
			Binder.grant(ctx.player, ids.FIRST)
			Binder.grant(ctx.player, ids.SANDWICH)
			Binder.grant(ctx.player, ids.SANDWICH)
			PlayerData.push(ctx.player)
		end
		ctx.say(
			(first and "Добро пожаловать на Остров Жадности! Вот начальные карты: Пик и пара бутербродов.\n\n" or "")
				.. "Я — Эта, гейм-мастер входа. Цель игры — собрать все 100 карт и заполнить слоты книги.",
			{
				{ id = "rules", label = "Как устроена игра" },
				{ id = "cards", label = "Где брать карты" },
				{ id = "controls", label = "Управление" },
				{ id = "next", label = "Куда идти дальше?" },
				{ id = "bye", label = "Спасибо" },
			}
		)
	end,
	choose = function(ctx, option)
		if option == "rules" then
			ctx.say(
				"Предмет, подобранный на острове, становится картой в руке. У вас есть минута, чтобы вложить её в книгу (клавиша B), иначе она снова станет предметом.\n\nУ каждого ранга карт свой лимит копий на сервере: пока он выбран, предмет в карту не превращается. Лишние копии кладутся в свободные слоты, их 45.",
				{ { id = "back", label = "Назад" } }
			)
		elseif option == "cards" then
			ctx.say(
				"Карты лежат в мире (подберите), выпадают из монстров, продаются в лавках, даются за задания. Особые карты Дориаса достаются только в азартных играх. Заклинания продаются лишь в Масадоре.\n\nЙены на острове хранятся в виде карты «Кошелёк» — книга покажет баланс.",
				{ { id = "back", label = "Назад" } }
			)
		elseif option == "controls" then
			ctx.say(
				"Бить монстров — левая кнопка мыши (на телефоне — кнопка «УДАР»). E — взять предмет и говорить с жителями. B — книга, G — приращение, T — Тен (урон по вам вдвое меньше), Z — Зетсу (монстры вас почти не замечают).\n\nСтрелка вверху экрана и золотой маркер в мире ведут к текущей цели.",
				{ { id = "back", label = "Назад" } }
			)
		elseif option == "next" then
			local profile = ctx.profile
			local hint
			if not profile.flags.firstMonster then
				hint = "Для начала победите любого монстра — они бродят на лугах к северу и востоку отсюда. Подберите предмет (E) и вложите карту в книгу."
			elseif not profile.flags.boughtSpell then
				hint = "Идите на запад в Масадору: там продаются заклинания. Йены можно выручить, продав лишние карты в лавке Антокибы."
			else
				hint = "Ищите недостающие карты: в книге есть карта острова и список слотов. Города лежат вокруг Дерева Шисо — идите по тропам."
			end
			ctx.say(hint, { { id = "back", label = "Назад" } })
		elseif option == "back" then
			roles.eta.talk(ctx)
		else
			ctx.close()
		end
	end,
}

roles.elena = {
	talk = function(ctx)
		ctx.say(
			"Я — Елена, гейм-мастер выхода. Чтобы покинуть остров, нужен «Транспортный билет» от начальника порта, или заклинание «Покинуть».",
			{ { id = "leave", label = "Покинуть остров" }, { id = "stay", label = "Остаться" } }
		)
	end,
	choose = function(ctx, option)
		if option ~= "leave" then
			ctx.close()
			return
		end
		if Binder.hasId(ctx.profile, ids.TICKET) then
			ctx.close()
			require(script.Parent.GameService).exitGame(ctx.player)
		else
			ctx.say("Билета у вас нет. Зайдите к начальнику порта.", { { id = "stay", label = "Хорошо" } })
		end
	end,
}

roles.portmaster = {
	talk = function(ctx)
		if Binder.hasId(ctx.profile, ids.TICKET) then
			ctx.say("Билет у вас уже есть. Идите к башне Елены.", { { id = "bye", label = "Спасибо" } })
			return
		end
		ctx.say(
			"Единственный порт на острове. «Транспортный билет» можно купить или выбить из меня. Попытка — раз в полминуты.",
			{
				{ id = "buy", label = "Купить билет (" .. Util.formatYen(TICKET_PRICE) .. ")" },
				{ id = "fight", label = "Сразиться" },
				{ id = "bye", label = "Уйти" },
			}
		)
	end,
	choose = function(ctx, option)
		if option == "buy" then
			if ctx.profile.yen < TICKET_PRICE then
				ctx.say("У вас не хватает йен.", { { id = "bye", label = "Понятно" } })
				return
			end
			local ok, reason = Binder.grant(ctx.player, ids.TICKET)
			if ok then
				ctx.profile.yen -= TICKET_PRICE
				PlayerData.push(ctx.player)
				ctx.say("Вот ваш билет.", { { id = "bye", label = "Спасибо" } })
			else
				ctx.say(reason or "Билетов нет.", { { id = "bye", label = "Понятно" } })
			end
		elseif option == "fight" then
			local wait = onCooldown(ctx.player, "port")
			if wait > 0 then
				ctx.say(("Отдохните ещё %d с."):format(math.ceil(wait)), { { id = "bye", label = "Ладно" } })
				return
			end
			markDuel(ctx.player, "port")
			if duelWins(ctx.player, 0.35) then
				local ok = Binder.grant(ctx.player, ids.TICKET)
				ctx.say(ok and "Ты победил. Забирай билет." or "Ты победил, но билетов больше нет.", { { id = "bye", label = "Спасибо" } })
			else
				ctx.say("Слабоват. Приходи позже.", { { id = "bye", label = "Ладно" } })
			end
		else
			ctx.close()
		end
	end,
}

roles.razor = {
	talk = function(ctx)
		ctx.say(
			"Я Рейзор. Остров Жадности — сложная игра. Хочешь собрать все 100 карт — не пропускай монстров: Пузырьковая лошадь ловится «Зетсу, затем Тен», а Циклоп сдаётся от удара в глаз.",
			{ { id = "tip", label = "Дай совет" }, { id = "bye", label = "Пока" } }
		)
	end,
	choose = function(ctx, option)
		if option == "tip" then
			ctx.say(
				"Радиокрыса падает в обморок при виде тебя. Жук-олень слетит с дерева только от серии из четырёх ударов подряд. А у ящерицы цель — родинка на спине.",
				{ { id = "bye", label = "Запомнил" } }
			)
		else
			ctx.close()
		end
	end,
}

-- ===== казино Дориаса: особые карты только из азартных игр =====

local function casinoPrize(profile: PlayerData.Profile): number?
	local pool = {}
	for _, id in { 29, 30, 32 } do
		if not profile.slots[id] and CardRegistry.canMint(id) then
			table.insert(pool, id)
		end
	end
	if #pool == 0 then
		return nil
	end
	return pool[rng:NextInteger(1, #pool)]
end

local function roulette(ctx: Context, bet: number)
	if ctx.profile.yen < bet then
		ctx.say("Не хватает йен для такой ставки.", { { id = "again", label = "Назад" } })
		return
	end
	ctx.profile.yen -= bet
	local roll = rng:NextInteger(1, 100) + (Status.has(ctx.player, "fortune") and 8 or 0)
	local text
	-- матожидание ставки слегка отрицательное (≈ -5%), иначе рулетка — бесконечный источник йен
	if roll <= 64 then
		text = ("Выпало красное. Вы проиграли %s."):format(Util.formatYen(bet))
	elseif roll <= 91 then
		ctx.profile.yen += bet * 2
		text = ("Победа! Выигрыш %s."):format(Util.formatYen(bet * 2))
	elseif roll <= 98 then
		ctx.profile.yen += bet * 3
		text = ("Крупный выигрыш: %s!"):format(Util.formatYen(bet * 3))
	else
		local prize = casinoPrize(ctx.profile)
		if prize and Binder.grant(ctx.player, prize) then
			text = "ДЖЕКПОТ! Король казино вручает особую карту: " .. Cards.get(prize).name .. "."
		else
			ctx.profile.yen += bet * 10
			text = ("Джекпот! %s."):format(Util.formatYen(bet * 10))
		end
	end
	PlayerData.push(ctx.player)
	ctx.say(text, { { id = "again", label = "Ещё раз" }, { id = "bye", label = "Хватит" } })
end

roles.casino = {
	talk = function(ctx)
		ctx.say(
			"Добро пожаловать в Дориас. Здесь особые карты достаются только за игру. Рулетка или дуэль со мной?",
			{
				{ id = "r500", label = "Рулетка: 500" },
				{ id = "r2000", label = "Рулетка: 2000" },
				{ id = "duel", label = "Дуэль с Королём (1000)" },
				{ id = "bye", label = "Не сегодня" },
			}
		)
	end,
	choose = function(ctx, option)
		if option == "again" then
			roles.casino.talk(ctx)
		elseif option == "r500" then
			roulette(ctx, 500)
		elseif option == "r2000" then
			roulette(ctx, 2000)
		elseif option == "duel" then
			if ctx.profile.yen < 1000 then
				ctx.say("Нужно 1000 йен.", { { id = "again", label = "Назад" } })
				return
			end
			ctx.profile.yen -= 1000
			if duelWins(ctx.player, 0.3) then
				local ok = not ctx.profile.slots[ids.KING_CARD] and Binder.grant(ctx.player, ids.KING_CARD)
				if not ok then
					ctx.profile.yen += 2500
				end
				PlayerData.push(ctx.player)
				ctx.say(
					ok and "Вы меня обыграли. Держите карту «Начинающий игрок»." or "Вы меня обыграли. Карта у вас уже есть — вот 2500 йен.",
					{ { id = "again", label = "Ещё" }, { id = "bye", label = "Хватит" } }
				)
			else
				PlayerData.push(ctx.player)
				ctx.say("Король усмехается: «Не в этот раз».", { { id = "again", label = "Ещё" }, { id = "bye", label = "Хватит" } })
			end
		else
			ctx.close()
		end
	end,
}

-- ===== финал =====

roles.finalquiz = {
	talk = function(ctx)
		if ctx.profile.won then
			ctx.say("Вы прошли игру. Идите в башню Елены — или оставайтесь и играйте дальше.", { { id = "bye", label = "Спасибо" } })
			return
		end
		local owned = PlayerData.ownedNumbered(ctx.profile)
		if ctx.profile.slots[Cards.BLESSING_ID] then
			owned -= 1
		end
		if owned < Config.NumberedSlots - 1 then
			ctx.say(
				("Я Дван. Финальная викторина — для тех, кто собрал все остальные карты. У вас: %d из %d."):format(owned, Config.NumberedSlots - 1),
				{ { id = "bye", label = "Понял" } }
			)
			return
		end
		ctx.say(
			("Вы собрали всё, кроме Благословения правителя. Ответьте верно хотя бы на %d из %d вопросов."):format(Config.FinalQuizPass, Config.FinalQuizQuestions),
			{ { id = "start", label = "Начать викторину" }, { id = "bye", label = "Позже" } }
		)
	end,
	choose = function(ctx, option)
		ctx.close()
		if option == "start" then
			QuizService.startFinal(ctx.player)
		end
	end,
}

roles.ging = {
	talk = function(ctx)
		if ctx.profile.won then
			ctx.say("Я Гинг. Ты сделал то, что удаётся немногим. Игра — это всего лишь игра, но с ней весело, верно?", { { id = "bye", label = "Да!" } })
		else
			ctx.say("Я Гинг, создатель острова. Хочешь победить — собери все 100 карт.", { { id = "bye", label = "Постараюсь" } })
		end
	end,
	choose = function(ctx)
		ctx.close()
	end,
}

-- ===== Антокиба =====

roles.catdiner = {
	talk = function(ctx)
		ctx.say(
			"Мяу! Это «Кошачья закусочная». Покушаете? Или принесёте всё для особого блюда: рыбу Галгайда, мёд диких пчёл и сушёную рыбу — тогда отдадим карту заведения.",
			{
				{ id = "menu", label = "Меню" },
				{ id = "quest", label = "Особое блюдо" },
				{ id = "bye", label = "Пока" },
			}
		)
	end,
	choose = function(ctx, option)
		if option == "menu" then
			ctx.close()
			ShopService.open(ctx.player, "catdiner")
		elseif option == "quest" then
			if ctx.profile.slots[ids.CATDINER] then
				ctx.say("Карта закусочной уже у вас. Мяу!", { { id = "bye", label = "Спасибо" } })
				return
			end
			local missing = missingFrom(ctx.profile, { 43, 61, 67 })
			if #missing > 0 then
				ctx.say("Нужно ещё: " .. table.concat(missing, ", ") .. ".", { { id = "bye", label = "Принесу" } })
				return
			end
			local ok, reason = Binder.grant(ctx.player, ids.CATDINER)
			ctx.say(ok and "Мур! Вот карта «Кошачья закусочная»." or (reason or "Не вышло."), { { id = "bye", label = "Спасибо" } })
		else
			ctx.close()
		end
	end,
}

roles.host = {
	talk = function(ctx)
		local seconds = QuizService.secondsToContest()
		ctx.say(
			("Конкурс Антокибы проходит раз в «месяц». Следующий — через %d с. Встаньте у сцены; побеждает самый быстрый верный ответ. Приз — рыба Галгайда."):format(seconds),
			{ { id = "bye", label = "Приду" } }
		)
	end,
	choose = function(ctx)
		ctx.close()
	end,
}

-- ===== Аиай: Девушка из золотой пыли =====

roles.goldguard = {
	talk = function(ctx)
		if ctx.profile.flags.guardBeaten or ctx.profile.slots[ids.GOLD] then
			ctx.say("Проходи. Девушка ждёт.", { { id = "bye", label = "Спасибо" } })
			return
		end
		ctx.say(
			"Я охраняю Девушку из золотой пыли. Чтобы пройти — заплати, покажи Меч Истины или сразись.",
			{
				{ id = "pay", label = "Заплатить " .. Util.formatYen(GUARD_BRIBE) },
				{ id = "sword", label = "Показать Меч Истины" },
				{ id = "fight", label = "Сразиться" },
				{ id = "bye", label = "Уйти" },
			}
		)
	end,
	choose = function(ctx, option)
		local function pass(text: string)
			ctx.profile.flags.guardBeaten = true
			ctx.say(text, { { id = "bye", label = "Спасибо" } })
		end
		if option == "pay" then
			if ctx.profile.yen >= GUARD_BRIBE then
				ctx.profile.yen -= GUARD_BRIBE
				PlayerData.push(ctx.player)
				pass("Деньги приняты. Проходи.")
			else
				ctx.say("Не хватает йен.", { { id = "bye", label = "Ладно" } })
			end
		elseif option == "sword" then
			if ctx.profile.flags.sword or Binder.hasId(ctx.profile, ids.SWORD) then
				pass("Меч Истины… Проходи.")
			else
				ctx.say("У тебя нет Меча Истины.", { { id = "bye", label = "Ладно" } })
			end
		elseif option == "fight" then
			local wait = onCooldown(ctx.player, "guard")
			if wait > 0 then
				ctx.say(("Подожди ещё %d с."):format(math.ceil(wait)), { { id = "bye", label = "Ладно" } })
				return
			end
			markDuel(ctx.player, "guard")
			if duelWins(ctx.player, 0.4) then
				pass("Ты сильнее. Проходи.")
			else
				ctx.say("Ты проиграл. Попробуй позже.", { { id = "bye", label = "Ладно" } })
			end
		else
			ctx.close()
		end
	end,
}

roles.goldgirl = {
	talk = function(ctx)
		if ctx.profile.slots[ids.GOLD] then
			ctx.say("Золотая пыль уже с вами.", { { id = "bye", label = "Спасибо" } })
		elseif ctx.profile.flags.guardBeaten then
			ctx.say("Страж пропустил вас. Возьмите карту «Девушка из золотой пыли».", { { id = "take", label = "Взять" } })
		else
			ctx.say("Я не могу говорить, пока рядом страж…", { { id = "bye", label = "Понятно" } })
		end
	end,
	choose = function(ctx, option)
		if option == "take" then
			local ok, reason = Binder.grant(ctx.player, ids.GOLD)
			ctx.say(ok and "Пожалуйста! Береги её." or (reason or "Не вышло."), { { id = "bye", label = "Спасибо" } })
		else
			ctx.close()
		end
	end,
}

roles.beach = {
	talk = function(ctx)
		if ctx.profile.slots[ids.BEACH] then
			ctx.say("Участок на пляже уже ваш.", { { id = "bye", label = "Спасибо" } })
			return
		end
		ctx.say(
			"Хотите участок на пляже? Принесите карты «Ракушка», «Песок в мешочке» и «Ракушка-эхо» — и он ваш.",
			{ { id = "give", label = "Показать карты" }, { id = "bye", label = "Позже" } }
		)
	end,
	choose = function(ctx, option)
		if option ~= "give" then
			ctx.close()
			return
		end
		local missing = missingFrom(ctx.profile, { 89, 94, 37 })
		if #missing > 0 then
			ctx.say("Не хватает: " .. table.concat(missing, ", ") .. ".", { { id = "bye", label = "Принесу" } })
			return
		end
		local ok, reason = Binder.grant(ctx.player, ids.BEACH)
		ctx.say(ok and "Участок ваш!" or (reason or "Не вышло."), { { id = "bye", label = "Спасибо" } })
	end,
}

-- ===== деревня горных бандитов: десять больных жителей =====

roles.villager = {
	talk = function(ctx)
		local index = ctx.npc.index or 0
		if ctx.profile.cured[index] then
			ctx.say("Спасибо, мне уже лучше!", { { id = "bye", label = "Выздоравливайте" } })
			return
		end
		ctx.say(
			"Я не бандит, я болен. Эта болезнь начинается с лихорадки и через месяц убивает. Поможет только карта «Лекарство».",
			{ { id = "cure", label = "Дать Лекарство" }, { id = "bye", label = "Позже" } }
		)
	end,
	choose = function(ctx, option)
		if option ~= "cure" then
			ctx.close()
			return
		end
		local index = ctx.npc.index or 0
		if ctx.profile.cured[index] then
			ctx.close()
			return
		end
		if not Binder.takeFree(ctx.profile, ids.MEDICINE) then
			ctx.say("У вас нет карты «Лекарство». Её продают в Wig & Pen.", { { id = "bye", label = "Куплю" } })
			return
		end
		ctx.profile.cured[index] = true
		local count = 0
		for _ in ctx.profile.cured do
			count += 1
		end
		PlayerData.push(ctx.player)
		if count >= 10 and not ctx.profile.flags.bandits then
			ctx.profile.flags.bandits = true
			local ok = Binder.grant(ctx.player, ids.BANDIT_GEM)
			ctx.say(
				ok and "Вы вылечили всех! В награду — Александрит «Дикая удача»." or "Все вылечены. Александрит уже выдан или недоступен.",
				{ { id = "bye", label = "Спасибо" } }
			)
		else
			ctx.say(("Вылечен! Исцелено жителей: %d из 10."):format(count), { { id = "bye", label = "Дальше" } })
		end
	end,
}

roles.shop = {
	talk = function(ctx)
		ctx.close()
		ShopService.open(ctx.player, ctx.npc.shop :: string)
	end,
	choose = function(ctx)
		ctx.close()
	end,
}

-- ===================== подключение =====================

local function open(player: Player, npcId: string)
	local npc = Npcs[npcId]
	local profile = PlayerData.get(player)
	if not npc or not profile or not profile.inGame then
		return
	end
	local role = roles[npc.role]
	if role then
		role.talk(context(player, profile, npcId, npc))
	end
end

local function onChoice(player: Player, data: any)
	if type(data) ~= "table" or type(data.npcId) ~= "string" or type(data.optionId) ~= "string" then
		return
	end
	local state = allowed[player]
	if not state or state.npcId ~= data.npcId or not state.options[data.optionId] then
		return
	end
	local npc = Npcs[data.npcId]
	local profile = PlayerData.get(player)
	if not npc or not profile then
		return
	end
	local role = roles[npc.role]
	if not role then
		return
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local home = npcHome[data.npcId]
	if not profile.inGame or not root or (home and ((root :: BasePart).Position - home).Magnitude > MAX_TALK_DISTANCE) then
		allowed[player] = nil
		Remotes.Dialog:FireClient(player, { close = true })
		return
	end
	local ctx = context(player, profile, data.npcId, npc)
	if data.optionId == "bye" then
		ctx.close()
		return
	end
	role.choose(ctx, data.optionId)
end

--- Ближайший игрок в игре в пределах distance от точки: (позиция, дистанция).
local function nearestPlayerPosition(from: Vector3, distance: number): (Vector3?, number)
	local best: Vector3? = nil
	local bestDistance = distance
	for _, player in Players:GetPlayers() do
		local profile = PlayerData.get(player)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and profile and profile.inGame then
			local position = (root :: BasePart).Position
			local d = (position - from).Magnitude
			if d < bestDistance then
				best, bestDistance = position, d
			end
		end
	end
	return best, bestDistance
end

function NpcService.animate(actor: Actor, dt: number, now: number)
	local watching, distance = nearestPlayerPosition(actor.position, NOTICE_DISTANCE)
	local moving = false

	if watching then
		actor.facing = watching
	end

	if actor.roam and (not watching or distance > 7) then
		if actor.goal and (actor.goal - actor.position).Magnitude > 0.8 then
			local direction = actor.goal - actor.position
			local flat = Vector3.new(direction.X, 0, direction.Z)
			if flat.Magnitude > 0.01 then
				local unit = flat.Unit
				if WorldBuilder.pathBlocked(actor.position, unit, WALK_SPEED * dt + 2.5) then
					actor.goal = nil -- упёрлись в постройку: выбираем другую цель
					actor.waitUntil = now + 1
				else
					local nextX = actor.position.X + unit.X * WALK_SPEED * dt
					local nextZ = actor.position.Z + unit.Z * WALK_SPEED * dt
					actor.position = Vector3.new(nextX, WorldBuilder.terrainY(nextX, nextZ), nextZ)
					if not watching then
						actor.facing = actor.position + unit * 10
					end
					moving = true
				end
			end
		elseif now >= actor.waitUntil then
			local angle = rng:NextNumber(0, math.pi * 2)
			local radius = rng:NextNumber(3, ROAM_RADIUS)
			local goalX = actor.home.X + math.cos(angle) * radius
			local goalZ = actor.home.Z + math.sin(angle) * radius
			actor.goal = Vector3.new(goalX, actor.home.Y, goalZ)
			actor.waitUntil = now + rng:NextNumber(2, 6)
		else
			actor.goal = nil
		end
	end

	actor.phase += dt * (moving and 7 or 1.4)
	local swing = moving and math.sin(actor.phase) * 0.6 or math.sin(actor.phase) * 0.04
	RigBuilder.place(actor.model, actor.position, actor.position.Y, actor.facing, actor.scale, swing)
end

-- вывеска над головой: чем занимается житель (видна с 60 студов)
local ROLE_TAGS: { [string]: { text: string, color: Color3 } } = {
	eta = { text = "Гейм-мастер входа", color = Color3.fromRGB(255, 160, 200) },
	elena = { text = "Выход из игры", color = Color3.fromRGB(150, 200, 255) },
	portmaster = { text = "Билеты", color = Color3.fromRGB(150, 200, 255) },
	razor = { text = "Советы охотника", color = Color3.fromRGB(255, 190, 120) },
	casino = { text = "Казино", color = Color3.fromRGB(255, 100, 120) },
	finalquiz = { text = "Финальная викторина", color = Color3.fromRGB(255, 230, 140) },
	ging = { text = "Загадочный охотник", color = Color3.fromRGB(150, 230, 170) },
	catdiner = { text = "Закусочная", color = Color3.fromRGB(255, 220, 130) },
	host = { text = "Конкурс", color = Color3.fromRGB(255, 200, 110) },
	goldgirl = { text = "Задание", color = Color3.fromRGB(255, 225, 110) },
	goldguard = { text = "Страж", color = Color3.fromRGB(200, 200, 215) },
	beach = { text = "Задание", color = Color3.fromRGB(255, 225, 110) },
	villager = { text = "Нужно лекарство", color = Color3.fromRGB(255, 140, 140) },
}

local function addRoleTag(model: Model, npc: Npcs.Npc, scale: number)
	local info = ROLE_TAGS[npc.role]
	if npc.role == "shop" then
		info = { text = npc.shop == "spells" and "Заклинания" or "Лавка", color = Color3.fromRGB(160, 230, 180) }
	end
	local head = model:FindFirstChild("Head")
	if not info or not head then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "RoleTag"
	gui.Size = UDim2.fromOffset(150, 20)
	gui.StudsOffset = Vector3.new(0, 4.2 * scale, 0) -- выше стандартной подписи имени
	gui.MaxDistance = 60
	gui.Adornee = head
	gui.Parent = head
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 13
	label.TextColor3 = info.color
	label.TextStrokeTransparency = 0.4
	label.Text = info.text
	label.Parent = gui
end

function NpcService.start()
	local folder = Instance.new("Folder")
	folder.Name = "Npcs"
	folder.Parent = workspace:WaitForChild("World")

	for npcId, npc in Npcs do
		local scale = npc.scale or 1
		local position = WorldBuilder.zonePoint(npc.zone, npc.dx, npc.dz)
		local zone = Zones[npc.zone]
		local model = RigBuilder.build(npc.name, npc.shirt, npc.skin, scale)
		local lookAt = Vector3.new(zone.x, position.Y, zone.z + 60)
		RigBuilder.place(model, position, position.Y, lookAt, scale)
		model.Parent = folder
		addRoleTag(model, npc, scale)
		npcHome[npcId] = position
		table.insert(actors, {
			model = model,
			scale = scale,
			home = position,
			position = position,
			roam = ROAMING[npcId] == true,
			goal = nil,
			waitUntil = 0,
			phase = rng:NextNumber(0, 6.28),
			facing = Vector3.new(zone.x, position.Y, zone.z + 60),
		})

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Поговорить"
		prompt.ObjectText = npc.name
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = model.PrimaryPart
		prompt.Triggered:Connect(function(player)
			open(player, npcId)
		end)
	end

	-- оживление: ходьба по кругу у поста, дыхание, взгляд на игрока рядом
	local RunService = game:GetService("RunService")
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 1 / 15 then
			return
		end
		local step = accumulator
		accumulator = 0
		local now = os.clock()
		for _, actor in actors do
			NpcService.animate(actor, step, now)
		end
	end)

	Remotes.DialogChoice.OnServerEvent:Connect(onChoice)
	Players.PlayerRemoving:Connect(function(player)
		allowed[player] = nil
		lastDuel[player] = nil
	end)
end

return NpcService
