package items

import "github.com/tristanbatchler/TwilightGroveOnline/server/internal/objs"

const logsKey = "Logs"
const rocksKey = "Rocks"

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
}

var Logs = Defaults[logsKey]
var Rocks = Defaults[rocksKey]
