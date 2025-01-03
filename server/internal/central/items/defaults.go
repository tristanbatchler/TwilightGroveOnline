package items

import "github.com/tristanbatchler/TwilightGroveOnline/server/internal/objs"

const logsKey = "Logs"
const rocksKey = "Rocks"
const goldBarsKey = "GoldBars"

var Defaults = map[string]*objs.Item{
	logsKey: {
		Name:          "Logs",
		Description:   "Logs from a sturdy natural wood",
		SpriteRegionX: 128,
		SpriteRegionY: 24,
		DbId:          0, // 0 will be checked for to signal the actual ID needs to be looked up
	},
	rocksKey: {
		Name:          "Rocks",
		Description:   "Rocks from a sturdy natural ore",
		SpriteRegionX: 128,
		SpriteRegionY: 80,
		DbId:          0, // 0 will be checked for to signal the actual ID needs to be looked up
	},
	goldBarsKey: {
		Name:          "Golden bars",
		Description:   "Pure gold formed into perfect ingots and stamped with the royal seal. Offical currency of the realm.",
		SpriteRegionX: 64,
		SpriteRegionY: 80,
		DbId:          0, // 0 will be checked for to signal the actual ID needs to be looked up
	},
}

var Logs = Defaults[logsKey]
var Rocks = Defaults[rocksKey]
var GoldBars = Defaults[goldBarsKey]
