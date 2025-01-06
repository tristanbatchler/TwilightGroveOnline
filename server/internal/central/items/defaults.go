package items

import (
	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/objs"
	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/props"
)

const logsKey = "Logs"
const rocksKey = "Rocks"
const goldBarsKey = "GoldBars"
const bronzeHatchetKey = "BronzeHatchet"
const faerieDustKey = "FaerieDust"
const bronzePickaxeKey = "BronzePickaxe"

var bronzeHatchetToolProps = props.NewToolProps(1, 1, props.ShrubHarvestable, 0)

var Defaults = map[string]*objs.Item{
	// DbId of 0 will be checked for to signal the actual ID needs to be looked up
	logsKey:          objs.NewItem("Logs", "Logs from a sturdy natural wood", 5, 128, 24, nil, 0),
	rocksKey:         objs.NewItem("Rocks", "Rocks from a sturdy natural ore", 5, 128, 80, nil, 0),
	goldBarsKey:      objs.NewItem("Golden bars", "Pure gold formed into perfect ingots and stamped with the royal seal. Offical currency of the realm.", 1, 64, 80, nil, 0),
	bronzeHatchetKey: objs.NewItem("Bronze hatchet", "A rusty bronze hatchet. Looks like it's seen much better days.", 10, 128, 32, bronzeHatchetToolProps, 0),
	faerieDustKey:    objs.NewItem("Faerie dust", "A pinch of faerie dust. It sparkles and glows with a magical light. Some say it has healing properties.", 10_000, 72, 80, nil, 0),
	bronzePickaxeKey: objs.NewItem("Bronze pickaxe", "A dirty old pick", 10, 128, 56, nil, 0),
}

var Logs = Defaults[logsKey]
var Rocks = Defaults[rocksKey]
var GoldBars = Defaults[goldBarsKey]
var BronzeHatchet = Defaults[bronzeHatchetKey]
var FaerieDust = Defaults[faerieDustKey]
var BronzePickaxe = Defaults[bronzePickaxeKey]
