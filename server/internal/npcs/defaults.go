package npcs

import (
	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/items"
	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/objs"
	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/quests"
	"github.com/tristanbatchler/TwilightGroveOnline/server/pkg/ds"
)

const (
	rickertKey = iota
	oscarKey
	gusKey
	mudKey
	dezzickKey
	oldManKey
)

var rickertQuest = quests.NewQuest(
	"A Flickering Flame",
	[]string{
		"Wuh? Oh, hello there. I'm Rickert, I'm... Well, I'm waiting for something.",
		"Actually, do you have a moment? I could use your help. The soldier upstairs is in pretty bad shape and I already used the last of my medicine to help an old friend.",
		"If you happen to come across something that could help, I'd be very grateful. I don't have much to offer except for this key I found. It's a bit rusty, but you look like an adventurer who could use it.",
		"Oh, and if you see my friends... tell them I've been looking for them.",
	},
	items.FaerieDust,
	[]string{
		"Wait, is that...? Oh, thank you! This is a very rare item, you know. I can't believe you found it.",
		"Here, take this key. I found it in the outer Grove, but I don't know what it opens. Maybe you'll have better luck.",
	},
	items.RustyKey,
	0,
)

var gusQuest = quests.NewFakeQuest([]string{"Woof!"})
var oscarQuest = quests.NewFakeQuest([]string{"It's looking grim for me, friend. I was ambushed by bandits and left for dead."})

var mudShop = ds.NewInventoryWithItems([]*ds.InventoryRow{
	ds.NewInventoryRow(*items.Logs, 100),
	ds.NewInventoryRow(*items.BronzeHatchet, 10),
	ds.NewInventoryRow(*items.IronHatchet, 10),
	ds.NewInventoryRow(*items.GoldHatchet, 10),
	ds.NewInventoryRow(*items.TwiliumHatchet, 10),
})
var dezzickShop = ds.NewInventoryWithItems([]*ds.InventoryRow{
	ds.NewInventoryRow(*items.Rocks, 100),
	ds.NewInventoryRow(*items.BronzePickaxe, 10),
	ds.NewInventoryRow(*items.IronPickaxe, 10),
	ds.NewInventoryRow(*items.GoldPickaxe, 10),
	ds.NewInventoryRow(*items.TwiliumPickaxe, 10),
})
var oldManShop = ds.NewInventoryWithItems([]*ds.InventoryRow{
	ds.NewInventoryRow(*items.FaerieDust, 100),
})

var Defaults = map[int]Npc{
	rickertKey: NewNpcQuestGiver(rickertKey, 1, objs.NewActor(1, 21, 6, "Rickert", 48, 0, 0), rickertQuest),
	gusKey:     NewNpcQuestGiver(gusKey, 1, objs.NewActor(1, 21, 11, "Gus", 40, 8, 0), gusQuest),
	oscarKey:   NewNpcQuestGiver(oscarKey, 3, objs.NewActor(3, -6, 1, "Oscar", 40, 0, 0), oscarQuest),
	mudKey:     NewNpcShopkeeper(mudKey, 1, objs.NewActor(1, 3, 13, "Mud", 96, 0, 0), mudShop),
	dezzickKey: NewNpcShopkeeper(dezzickKey, 2, objs.NewActor(2, 2, 4, "Dezzick", 32, 0, 0), dezzickShop),
	oldManKey:  NewNpcShopkeeper(oldManKey, 1, objs.NewActor(1, 34, 10, "Old man", 72, 0, 0), oldManShop),
}

var Rickert = Defaults[rickertKey]
var Gus = Defaults[gusKey]
var Oscar = Defaults[oscarKey]
var Mud = Defaults[mudKey]
var Dezzick = Defaults[dezzickKey]
var OldMan = Defaults[oldManKey]
