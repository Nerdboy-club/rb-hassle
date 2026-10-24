-- Викторины: «ежемесячный» конкурс Антокибы (приз — рыба Галгайда) и финальная викторина Лимейро
-- (приз — Благословение правителя).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Questions = require(Shared.Quiz)
local Remotes = require(Shared.Remotes)

local Binder = require(script.Parent.Binder)
local PlayerData = require(script.Parent.PlayerData)
local WorldBuilder = require(script.Parent.WorldBuilder)

local QuizService = {}

local GALGAIDA_ID = 43
local STAGE_RADIUS = 70
local COOLDOWN_AFTER_FAIL = 60

type Session = {
	kind: string,
	qid: number,
	answer: number,
	asked: number,
	deadline: number,
	round: number,
	total: number,
	correct: number,
	used: { [number]: boolean },
}

local sessions: { [Player]: Session } = {}
local failedAt: { [Player]: number } = {}
local nextQid = 0
local rng = Random.new()

-- участники конкурса
local contest: { open: boolean, results: { [Player]: { ok: boolean, elapsed: number } }, qid: number? } =
	{ open = false, results = {}, qid = nil }

local function pickQuestion(used: { [number]: boolean }): number
	for _ = 1, 60 do
		local index = rng:NextInteger(1, #Questions)
		if not used[index] then
			used[index] = true
			return index
		end
	end
	return rng:NextInteger(1, #Questions)
end

local function send(player: Player, session: Session, kind: string, seconds: number)
	nextQid += 1
	local index = pickQuestion(session.used)
	local question = Questions[index]

	-- перемешиваем варианты, чтобы верный не стоял всегда на одном месте
	local order = { 1, 2, 3, 4 }
	for i = #order, 2, -1 do
		local j = rng:NextInteger(1, i)
		order[i], order[j] = order[j], order[i]
	end
	local options = {}
	for position, original in order do
		options[position] = question.options[original]
		if original == question.answer then
			session.answer = position
		end
	end

	session.qid = nextQid
	session.deadline = os.clock() + seconds
	Remotes.Quiz:FireClient(player, {
		kind = kind,
		qid = session.qid,
		text = question.q,
		options = options,
		seconds = seconds,
		round = session.round,
		total = session.total,
	})
end

local function closeUi(player: Player)
	Remotes.Quiz:FireClient(player, { close = true })
end

-- ===================== финальная викторина =====================

local function finishFinal(player: Player, session: Session)
	sessions[player] = nil
	closeUi(player)
	if session.correct >= Config.FinalQuizPass then
		local ok, reason = Binder.grant(player, 1)
		if ok then
			PlayerData.notify(player, "Верно! Вы получили Благословение правителя.", "good")
		else
			PlayerData.notify(player, reason or "Не удалось выдать награду", "warn")
		end
	else
		failedAt[player] = os.clock()
		PlayerData.notify(
			player,
			("Верных ответов: %d из %d. Нужно %d. Приходите через минуту."):format(session.correct, session.total, Config.FinalQuizPass),
			"warn"
		)
	end
end

function QuizService.startFinal(player: Player): boolean
	if sessions[player] then
		return false
	end
	local waited = os.clock() - (failedAt[player] or -1e9)
	if waited < COOLDOWN_AFTER_FAIL then
		PlayerData.notify(player, ("Попробуйте ещё раз через %d с."):format(math.ceil(COOLDOWN_AFTER_FAIL - waited)), "warn")
		return false
	end
	local session: Session = {
		kind = "final",
		qid = 0,
		answer = 0,
		asked = 0,
		deadline = 0,
		round = 1,
		total = Config.FinalQuizQuestions,
		correct = 0,
		used = {},
	}
	sessions[player] = session
	send(player, session, "final", Config.ContestAnswerSeconds)
	local qid = session.qid
	task.delay(Config.ContestAnswerSeconds + 1, function()
		QuizService.expire(player, qid)
	end)
	return true
end

--- Время на вопрос вышло: считаем ответ неверным.
function QuizService.expire(player: Player, qid: number)
	local session = sessions[player]
	if not session or session.qid ~= qid or session.kind ~= "final" then
		return
	end
	QuizService.advanceFinal(player, session, false)
end

function QuizService.advanceFinal(player: Player, session: Session, correct: boolean)
	if correct then
		session.correct += 1
	end
	if session.round >= session.total then
		finishFinal(player, session)
		return
	end
	session.round += 1
	send(player, session, "final", Config.ContestAnswerSeconds)
	local qid = session.qid
	task.delay(Config.ContestAnswerSeconds + 1, function()
		QuizService.expire(player, qid)
	end)
end

-- ===================== конкурс Антокибы =====================

local function stagePosition(): Vector3
	return WorldBuilder.zonePoint("Antokiba", 0, -45)
end

local function playersAtStage(): { Player }
	local found = {}
	local stage = stagePosition()
	for _, player in Players:GetPlayers() do
		local profile = PlayerData.get(player)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if profile and profile.inGame and root and ((root :: BasePart).Position - stage).Magnitude <= STAGE_RADIUS then
			table.insert(found, player)
		end
	end
	return found
end

local function runContest()
	local participants = playersAtStage()
	if #participants == 0 then
		return
	end
	contest.open = true
	contest.results = {}
	local started = os.clock()
	local used: { [number]: boolean } = {}
	local shared: Session = {
		kind = "contest",
		qid = 0,
		answer = 0,
		asked = 0,
		deadline = 0,
		round = 1,
		total = 1,
		correct = 0,
		used = used,
	}
	-- один вопрос на всех: в этом состязании важна скорость
	nextQid += 1
	local index = pickQuestion(used)
	local question = Questions[index]
	local qid = nextQid
	contest.qid = qid
	for _, player in participants do
		local personal: Session = table.clone(shared)
		personal.used = {}
		personal.qid = qid
		personal.answer = question.answer
		personal.deadline = started + Config.ContestAnswerSeconds
		sessions[player] = personal
		Remotes.Quiz:FireClient(player, {
			kind = "contest",
			qid = qid,
			text = question.q,
			options = question.options,
			seconds = Config.ContestAnswerSeconds,
			round = 1,
			total = 1,
		})
	end

	task.delay(Config.ContestAnswerSeconds + 1, function()
		contest.open = false
		local winner: Player? = nil
		local best = math.huge
		for player, result in contest.results do
			if result.ok and result.elapsed < best then
				winner, best = player, result.elapsed
			end
		end
		for _, player in participants do
			if sessions[player] and sessions[player].kind == "contest" then
				sessions[player] = nil
			end
			closeUi(player)
		end
		for _, player in participants do
			if player == winner then
				local ok = Binder.grant(player, GALGAIDA_ID)
				if ok then
					PlayerData.notify(player, "Вы победили в конкурсе! Приз — рыба Галгайда.", "good")
				else
					local profile = PlayerData.get(player)
					if profile then
						profile.yen += 2000
						PlayerData.push(player)
					end
					PlayerData.notify(player, "Вы победили в конкурсе! Рыбы больше нет — вот 2000 йен.", "good")
				end
			elseif winner then
				PlayerData.notify(player, "Конкурс выиграл " .. winner.DisplayName .. ".", "info")
			else
				PlayerData.notify(player, "Никто не ответил верно — приз остался у организаторов.", "info")
			end
		end
	end)
end

--- Распорядитель: когда ближайший конкурс.
function QuizService.secondsToContest(): number
	return QuizService.nextContestAt and math.max(0, math.ceil(QuizService.nextContestAt - os.clock())) or 0
end

QuizService.nextContestAt = nil :: number?

-- ===================== ответы =====================

local function onAnswer(player: Player, data: any)
	if type(data) ~= "table" or type(data.qid) ~= "number" or type(data.index) ~= "number" then
		return
	end
	local session = sessions[player]
	if not session or session.qid ~= data.qid then
		return
	end
	local now = os.clock()
	if now > session.deadline + 1 then
		return
	end
	local correct = data.index == session.answer
	if session.kind == "contest" then
		if contest.open and not contest.results[player] then
			contest.results[player] = { ok = correct, elapsed = now - (session.deadline - Config.ContestAnswerSeconds) }
			PlayerData.notify(player, correct and "Ответ принят! Ждите итогов." or "Ответ принят.", "info")
		end
		return
	end
	QuizService.advanceFinal(player, session, correct)
end

function QuizService.start()
	Remotes.QuizAnswer.OnServerEvent:Connect(onAnswer)
	Players.PlayerRemoving:Connect(function(player)
		sessions[player] = nil
		failedAt[player] = nil
	end)

	task.spawn(function()
		while true do
			QuizService.nextContestAt = os.clock() + Config.ContestIntervalSeconds
			task.wait(Config.ContestIntervalSeconds)
			for _, player in Players:GetPlayers() do
				local profile = PlayerData.get(player)
				if profile and profile.inGame then
					PlayerData.notify(player, "В Антокибе начинается конкурс! Соберитесь у сцены — вопрос через 20 секунд.", "info")
				end
			end
			task.wait(20)
			runContest()
		end
	end)
end

return QuizService
