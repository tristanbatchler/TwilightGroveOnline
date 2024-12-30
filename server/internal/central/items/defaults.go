package items

import "github.com/tristanbatchler/TwilightGroveOnline/server/internal/objs"

const logsKey = "Logs"

var Defaults = map[string]*objs.Item{
	logsKey: {
		Name:          "Logs",
		Description:   "Logs from a sturdy natural wood",
		SpriteRegionX: 128,
		SpriteRegionY: 24,
		DbId:          0,
	},
	// Add more items here...
}

var Logs = Defaults[logsKey]
