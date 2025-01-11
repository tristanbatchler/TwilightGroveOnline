package quests

import (
	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/items"
	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/objs"
)

type Quest struct {
	Name             string
	StartDialogue    []string
	RequiredItem     *objs.Item
	CompleteDialogue []string
	RewardItem       *objs.Item
	DbId             int32
}

func NewQuest(name string, startDialogue []string, requiredItem *objs.Item, completedDialogue []string, rewardItem *objs.Item, dbId int32) *Quest {
	return &Quest{
		Name:             name,
		StartDialogue:    startDialogue,
		RequiredItem:     requiredItem,
		CompleteDialogue: completedDialogue,
		RewardItem:       rewardItem,
		DbId:             dbId,
	}
}

func NewFakeQuest(dialogue []string) *Quest {
	return NewQuest(
		"Fake quest for dialogue",
		dialogue,
		items.ImpossibleItem,
		[]string{},
		items.ImpossibleItem,
		0,
	)
}
