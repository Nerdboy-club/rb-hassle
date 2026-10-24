-- Лавки: торговые дома, Wig & Pen, закусочная и магазин спелл-карт (только он продаёт заклинания).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Cards = require(Shared.Cards)
local Remotes = require(Shared.Remotes)
local Spells = require(Shared.Spells)
local Util = require(Shared.Util)

local Binder = require(script.Parent.Binder)
local CardRegistry = require(script.Parent.CardRegistry)
local PlayerData = require(script.Parent.PlayerData)

local ShopService = {}

type Shop = { name: string, spells: boolean?, info: boolean? }

local SHOPS: { [string]: Shop } = {
	antokiba = { name = "Торговый дом Антокибы", info = true },
	masadora = { name = "Торговый дом Масадоры", info = true },
	wigpen = { name = "Wig & Pen" },
	catdiner = { name = "Кошачья закусочная" },
	spells = { name = "Магазин спелл-карт", spells = true },
}

-- цена продажи по рангу, если карта в лавках не продаётся
local RANK_VALUE = { SS = 50000, S = 30000, A = 15000, B = 8000, C = 3000, D = 1200, E = 600, F = 250, G = 100, H = 50 }

local openShops: { [Player]: string } = {}
local spellStock: { [number]: number } = {}
local spellStockMax: { [number]: number } = {}

local function initialStock(price: number): number
	if price < 3000 then
		return 6
	elseif price < 6000 then
		return 4
	elseif price < 9000 then
		return 3
	end
	return 2
end

local function sellPrice(card: Cards.Card): number
	local source = Cards.parseSource(card.source)
	local base = (source.type == "s" and source.price) or RANK_VALUE[card.rank] or 50
	return math.max(1, math.floor(base * Config.SellFraction))
end

local function payload(player: Player, shopId: string): { [string]: any }?
	local shop = SHOPS[shopId]
	local profile = PlayerData.get(player)
	if not shop or not profile then
		return nil
	end
	local purchases = profile.purchases[shopId] or 0

	local buy = {}
	if shop.spells then
		for _, spell in Spells.list do
			table.insert(buy, { id = spell.id, price = spell.price, stock = spellStock[spell.id] or 0 })
		end
	else
		for _, card in Cards.withSource("s", shopId) do
			local price = Cards.parseSource(card.source).price or 0
			local locked = card.rank == "B" and purchases < Config.BRankPurchases
			table.insert(buy, {
				id = card.id,
				price = price,
				locked = locked,
				lockText = locked and ("ранг B: нужно %d покупок здесь (сейчас %d)"):format(Config.BRankPurchases, purchases) or nil,
			})
		end
		table.sort(buy, function(a, b)
			return a.price < b.price
		end)
	end

	local sell = {}
	if not shop.spells then
		for _, entry in profile.free do
			local card = Cards.get(entry.id)
			if card and not card.spell and card.kind ~= "wallet" then
				table.insert(sell, { uid = entry.uid, id = entry.id, price = sellPrice(card) })
			end
		end
	end

	return {
		shopId = shopId,
		name = shop.name,
		spells = shop.spells == true,
		yen = profile.yen,
		buy = buy,
		sell = sell,
		info = shop.info == true,
		infoPrice = Config.InfoPrice,
		purchases = purchases,
	}
end

function ShopService.open(player: Player, shopId: string)
	local data = payload(player, shopId)
	if data then
		openShops[player] = shopId
		Remotes.ShopOpen:FireClient(player, data)
	end
end

local function refresh(player: Player, shopId: string)
	local data = payload(player, shopId)
	if data then
		Remotes.ShopOpen:FireClient(player, data)
	end
	PlayerData.push(player)
end

--- Заклинание использовано — магазин получает его обратно в запас.
function ShopService.restockSpell(id: number)
	spellStock[id] = math.min(spellStockMax[id] or 6, (spellStock[id] or 0) + 1)
end

local function buy(player: Player, profile: PlayerData.Profile, shopId: string, cardId: number)
	local shop = SHOPS[shopId]
	local card = Cards.get(cardId)
	if not card then
		return
	end
	local price: number
	if shop.spells then
		local spell = Spells.get(cardId)
		if not spell then
			return
		end
		if (spellStock[cardId] or 0) <= 0 then
			PlayerData.notify(player, "Это заклинание разобрали — запас пополнится, когда такие карты используют.", "warn")
			return
		end
		price = spell.price
	else
		local source = Cards.parseSource(card.source)
		if source.type ~= "s" or source.arg ~= shopId then
			return
		end
		price = source.price or 0
		if card.rank == "B" and (profile.purchases[shopId] or 0) < Config.BRankPurchases then
			PlayerData.notify(player, "Карты ранга B лавка продаёт только постоянным покупателям.", "warn")
			return
		end
	end
	if profile.yen < price then
		PlayerData.notify(player, "Не хватает йен.", "warn")
		return
	end
	local ok, reason = Binder.grant(player, cardId)
	if not ok then
		PlayerData.notify(player, reason or "Не получилось купить", "warn")
		return
	end
	profile.yen -= price
	profile.purchases[shopId] = (profile.purchases[shopId] or 0) + 1
	if shop.spells then
		spellStock[cardId] -= 1
		profile.flags.boughtSpell = true
	end
	PlayerData.notify(player, "Куплено: " .. card.name, "good")
end

local function sell(player: Player, profile: PlayerData.Profile, uid: number)
	for index, entry in profile.free do
		if entry.uid == uid then
			local card = Cards.get(entry.id)
			if not card or card.spell or card.kind == "wallet" then
				return
			end
			table.remove(profile.free, index)
			if card.numbered then
				CardRegistry.release(entry.id)
			end
			local price = sellPrice(card)
			profile.yen += price
			PlayerData.notify(player, ("Продано: %s (+%s)"):format(card.name, Util.formatYen(price)), "good")
			return
		end
	end
end

local function sellInfo(player: Player, profile: PlayerData.Profile)
	if profile.yen < Config.InfoPrice then
		PlayerData.notify(player, "Информация стоит " .. Util.formatYen(Config.InfoPrice), "warn")
		return
	end
	local candidates = {}
	for _, id in Cards.numberedIds do
		local card = Cards.get(id) :: Cards.Card
		local source = Cards.parseSource(card.source)
		if not profile.slots[id] and (source.type == "p" or source.type == "m") then
			table.insert(candidates, card)
		end
	end
	if #candidates == 0 then
		PlayerData.notify(player, "Торговец ничего нового не знает.", "info")
		return
	end
	profile.yen -= Config.InfoPrice
	local card = candidates[math.random(1, #candidates)]
	local source = Cards.parseSource(card.source)
	local where = source.type == "p" and Util.zoneName(source.arg)
		or ("в логове монстра («" .. (source.arg or "?") .. "»)")
	PlayerData.notify(player, ("Слух: «%s» (ранг %s) — %s."):format(card.name, card.rank, where), "good")
end

local function handle(player: Player, data: any)
	if type(data) ~= "table" or type(data.shopId) ~= "string" or openShops[player] ~= data.shopId then
		return
	end
	local profile = PlayerData.get(player)
	if not profile or not profile.inGame then
		return
	end
	if data.action == "buy" and type(data.cardId) == "number" then
		buy(player, profile, data.shopId, data.cardId)
	elseif data.action == "sell" and type(data.uid) == "number" then
		sell(player, profile, data.uid)
	elseif data.action == "info" and SHOPS[data.shopId].info then
		sellInfo(player, profile)
	elseif data.action == "close" then
		openShops[player] = nil
		return
	end
	refresh(player, data.shopId)
end

function ShopService.start()
	for _, spell in Spells.list do
		local stock = initialStock(spell.price)
		spellStock[spell.id] = stock
		spellStockMax[spell.id] = stock * 2
	end
	Remotes.ShopAction.OnServerEvent:Connect(handle)
	Players.PlayerRemoving:Connect(function(player)
		openShops[player] = nil
	end)
end

return ShopService
