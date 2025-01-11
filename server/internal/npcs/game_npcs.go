package npcs

import (
	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/objs"
	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/quests"
	"github.com/tristanbatchler/TwilightGroveOnline/server/pkg/ds"
)

// NPC struct and methods
type Npc struct {
	Id      int
	LevelId int32
	Actor   *objs.Actor
	Quest   *quests.Quest
	Shop    *ds.Inventory
}

func NewNpcQuestGiver(id int, levelId int32, actor *objs.Actor, quest *quests.Quest) Npc {
	if actor == nil {
		panic("Actor cannot be nil")
	}
	return Npc{
		Id:      id,
		LevelId: levelId,
		Actor:   actor,
		Quest:   quest,
	}
}

func NewNpcShopkeeper(id int, levelId int32, actor *objs.Actor, shop *ds.Inventory) Npc {
	if actor == nil {
		panic("Actor cannot be nil")
	}
	return Npc{
		Id:      id,
		LevelId: levelId,
		Actor:   actor,
		Shop:    shop,
	}
}
