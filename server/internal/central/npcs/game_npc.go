package npcs

import (
	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/central/quests"
	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/objs"
	"github.com/tristanbatchler/TwilightGroveOnline/server/pkg/ds"
)

type Npc struct {
	Name    string
	levelId int32
	actor   *objs.Actor
	quest   *quests.Quest
	shop    *ds.Inventory
}

func NewNpcQuestGiver(name string, levelId int32, actor *objs.Actor, quest *quests.Quest) Npc {
	return Npc{
		Name:    name,
		levelId: levelId,
		actor:   actor,
		quest:   quest,
	}
}

func NewNpcShopkeeper(name string, levelId int32, actor *objs.Actor, shop *ds.Inventory) Npc {
	return Npc{
		Name:    name,
		levelId: levelId,
		actor:   actor,
		shop:    shop,
	}
}
