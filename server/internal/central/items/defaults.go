package items

import "github.com/tristanbatchler/TwilightGroveOnline/server/internal/objs"

const logsKey = "Logs"
const rocksKey = "Rocks"
const goldBarsKey = "GoldBars"

var Defaults = map[string]*objs.Item{
	// DbId of 0 will be checked for to signal the actual ID needs to be looked up
	logsKey:     objs.NewItem("Logs", "Logs from a sturdy natural wood", 5, 128, 24, nil, 0),
	rocksKey:    objs.NewItem("Rocks", "Rocks from a sturdy natural ore", 5, 128, 80, nil, 0),
	goldBarsKey: objs.NewItem("Golden bars", "Pure gold formed into perfect ingots and stamped with the royal seal. Offical currency of the realm.", 1, 64, 80, nil, 0),
}

var Logs = Defaults[logsKey]
var Rocks = Defaults[rocksKey]
var GoldBars = Defaults[goldBarsKey]
