// Сборка и запуск проверок без Roblox Studio.
//   node tools/check/build.js            — собрать .build/data_check.luau и .build/logic_check.luau и запустить, если найден luau
//   LUAU=путь\к\luau.exe node tools/check/build.js
// Проверки встраивают исходники src/ в один Luau-файл (в интерпретаторе нет io и Roblox API),
// а Roblox-сервисы заменены заглушками (см. logic_head.luau).
const fs = require("fs");
const path = require("path");
const { spawnSync } = require("child_process");

const root = path.resolve(__dirname, "..", "..", "src") + path.sep;
const out = path.join(__dirname, ".build");
fs.mkdirSync(out, { recursive: true });

const embed = (modules) =>
	"local SOURCES = {}\n" +
	Object.entries(modules)
		.map(([name, file]) => `SOURCES.${name} = [==[\n${fs.readFileSync(root + file + ".luau", "utf8")}\n]==]\n`)
		.join("");

// 1) целостность данных: 100 карт, 40 заклинаний, ссылки на зоны/монстров/лавки
const dataModules = {};
for (const name of ["Cards", "Ranks", "Zones", "Monsters", "Npcs", "Spells", "Quiz", "Util", "Config"]) {
	dataModules[name] = "shared/" + name;
}
fs.writeFileSync(
	path.join(out, "data_check.luau"),
	embed(dataModules) + fs.readFileSync(path.join(__dirname, "data_tail.luau"), "utf8")
);

// 2) логика книги на заглушках Roblox: рука, слоты, лимиты рангов, профиль (round-trip), выход во время загрузки
const logicModules = {
	Config: "shared/Config",
	Cards: "shared/Cards",
	Spells: "shared/Spells",
	Ranks: "shared/Ranks",
	CardRegistry: "server/CardRegistry",
	PlayerData: "server/PlayerData",
	Binder: "server/Binder",
	Hand: "server/Hand",
};
fs.writeFileSync(
	path.join(out, "logic_check.luau"),
	embed(logicModules) +
		fs.readFileSync(path.join(__dirname, "logic_head.luau"), "utf8") +
		fs.readFileSync(path.join(__dirname, "logic_tests.luau"), "utf8")
);

console.log("Собрано в", out);

const luau = process.env.LUAU || "luau";
for (const file of ["data_check.luau", "logic_check.luau"]) {
	const result = spawnSync(luau, [path.join(out, file)], { encoding: "utf8" });
	if (result.error) {
		console.log("luau не найден — задайте переменную LUAU. Файлы собраны, запустите вручную:", file);
		break;
	}
	console.log("== " + file + "\n" + (result.stdout || "") + (result.stderr || ""));
	if (result.status !== 0) {
		process.exitCode = 1;
	}
}
