local CarService = require(script.Parent.CarService)
local ShashkiService = require(script.Parent.ShashkiService)
local TrafficService = require(script.Parent.TrafficService)

CarService.start()
TrafficService.start()
ShashkiService.start(TrafficService)
