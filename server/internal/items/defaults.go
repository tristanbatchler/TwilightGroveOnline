package items

import (
	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/objs"
	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/props"
)

const logsKey = "Logs"
const rocksKey = "Rocks"
const goldBarsKey = "GoldBars"
const faerieDustKey = "FaerieDust"
const rustyKeyKey = "RustyKey"
const ringOfFortitudeKey = "RingOfFortitude"

const bronzeHatchetKey = "BronzeHatchet"
const bronzePickaxeKey = "BronzePickaxe"
const ironHatchetKey = "IronHatchet"
const ironPickaxeKey = "IronPickaxe"
const goldHatchetKey = "GoldHatchet"
const goldPickaxeKey = "GoldPickaxe"
const twiliumHatchetKey = "twiliumHatchet"
const twiliumPickaxeKey = "TwiliumPickaxe"

const impossibleItemKey = "ImpossibleItem"

var bronzeHatchetToolProps = props.NewToolProps(1, 1, props.ShrubHarvestable, -1, 0)
var bronzePickaxeToolProps = props.NewToolProps(1, 1, props.OreHarvestable, -1, 0)
var ironHatchetToolProps = props.NewToolProps(2, 5, props.ShrubHarvestable, -1, 0)
var ironPickaxeToolProps = props.NewToolProps(2, 5, props.OreHarvestable, -1, 0)
var goldHatchetToolProps = props.NewToolProps(3, 10, props.ShrubHarvestable, -1, 0)
var goldPickaxeToolProps = props.NewToolProps(3, 10, props.OreHarvestable, -1, 0)
var twiliumHatchetToolProps = props.NewToolProps(4, 20, props.ShrubHarvestable, -1, 0)
var twiliumPickaxeToolProps = props.NewToolProps(4, 20, props.OreHarvestable, -1, 0)

var rustyKeyToolProps = props.NewToolProps(1, 1, props.NoneHarvestable, 0, 0)

var Defaults = map[string]*objs.Item{
	// DbId of 0 will be checked for to signal the actual ID needs to be looked up
	logsKey:       objs.NewItem("Logs", "Logs from a sturdy natural wood.", 5, 128, 24, nil, 0),
	rocksKey:      objs.NewItem("Rocks", "Rocks from a sturdy natural ore.", 5, 128, 80, nil, 0),
	goldBarsKey:   objs.NewItem("Golden bars", "Pure gold formed into perfect ingots and stamped with the royal seal. Offical currency of the realm.", 1, 64, 80, nil, 0),
	faerieDustKey: objs.NewItem("Faerie dust", "A pinch of faerie dust. It sparkles and glows with a magical light. Some say it has healing properties.", 10_000, 72, 80, nil, 0),
	rustyKeyKey:   objs.NewItem("Rusty key", "A rusty old key. Who knows what this is for.", 0, 80, 40, rustyKeyToolProps, 0),

	bronzeHatchetKey:  objs.NewItem("Bronze hatchet", "A rusty bronze hatchet. Looks like it's seen much better days.", 10, 128, 32, bronzeHatchetToolProps, 0),
	bronzePickaxeKey:  objs.NewItem("Bronze pickaxe", "A dirty old pick.", 10, 128, 56, bronzePickaxeToolProps, 0),
	ironHatchetKey:    objs.NewItem("Iron hatchet", "A respectable hatchet made of iron.", 50, 128, 40, ironHatchetToolProps, 0),
	ironPickaxeKey:    objs.NewItem("Iron pickaxe", "A respectable pickaxe made of iron.", 50, 128, 64, ironPickaxeToolProps, 0),
	goldHatchetKey:    objs.NewItem("Gold hatchet", "An excellent tool, proficient in splitting logs.", 200, 128, 48, goldHatchetToolProps, 0),
	goldPickaxeKey:    objs.NewItem("Gold pickaxe", "A most fine pick, perfect for mining most ores.", 200, 128, 72, goldPickaxeToolProps, 0),
	twiliumHatchetKey: objs.NewItem("Twilium hatchet", "A masterwork hatchet, crafted from the Grove's namesake. Its edge is sharp, eager to split anything in its path.", 1000, 128, 88, twiliumHatchetToolProps, 0),
	twiliumPickaxeKey: objs.NewItem("Twilium pickaxe", "A masterwork pick, crafted from the Grove's namesake. Its point is bleeding with power, eager to crush anything in its path.", 1000, 120, 88, twiliumPickaxeToolProps, 0),

	impossibleItemKey: objs.NewItem("Impossible item", "This item should never be in the game. If you see it, please report to the developer.", 0, 0, 0, nil, 0),
}

var Logs = Defaults[logsKey]
var Rocks = Defaults[rocksKey]
var GoldBars = Defaults[goldBarsKey]
var FaerieDust = Defaults[faerieDustKey]
var RustyKey = Defaults[rustyKeyKey]

var BronzeHatchet = Defaults[bronzeHatchetKey]
var BronzePickaxe = Defaults[bronzePickaxeKey]
var IronHatchet = Defaults[ironHatchetKey]
var IronPickaxe = Defaults[ironPickaxeKey]
var GoldHatchet = Defaults[goldHatchetKey]
var GoldPickaxe = Defaults[goldPickaxeKey]
var TwiliumHatchet = Defaults[twiliumHatchetKey]
var TwiliumPickaxe = Defaults[twiliumPickaxeKey]

var ImpossibleItem = Defaults[impossibleItemKey]
