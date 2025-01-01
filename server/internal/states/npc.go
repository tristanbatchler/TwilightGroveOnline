package states

import (
	"fmt"
	"log"
	"math/rand/v2"
	"strings"

	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/central"
	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/objs"
	"github.com/tristanbatchler/TwilightGroveOnline/server/pkg/packets"
)

type Npc struct {
	client        central.ClientInterfacer
	actor         *objs.Actor
	levelId       int32
	othersInLevel []uint32
	logger        *log.Logger
}

func (g *Npc) Name() string {
	return "Npc"
}

func (g *Npc) SetClient(client central.ClientInterfacer) {
	g.client = client
	loggingPrefix := fmt.Sprintf("Client %d [%s]: ", client.Id(), g.Name())
	g.logger = log.New(log.Writer(), loggingPrefix, log.LstdFlags)
}

func (g *Npc) OnEnter() {
	g.levelId = 1
	g.actor = objs.NewActor(g.levelId, -rand.Int32N(7), rand.Int32N(5), "NPC", 0)

	g.client.SharedGameObjects().Actors.Add(g.actor, g.client.Id())

	// Collect info about all the other actors in the level
	ourPlayerInfo := packets.NewActor(g.actor)
	g.client.SharedGameObjects().Actors.ForEach(func(owner_client_id uint32, actor *objs.Actor) {
		if actor.LevelId == g.levelId {
			g.othersInLevel = append(g.othersInLevel, owner_client_id)
		}
	})

	// Send our info back to all the other clients in the level
	g.client.Broadcast(ourPlayerInfo, g.othersInLevel)
}

func (g *Npc) HandleMessage(senderId uint32, message packets.Msg) {
	switch message := message.(type) {
	case *packets.Packet_Chat:
		g.handleChat(senderId, message)
	}
}

func (g *Npc) handleChat(senderId uint32, message *packets.Packet_Chat) {
	if strings.TrimSpace(message.Chat.Msg) == "" {
		g.logger.Println("Received a chat message with no content, ignoring")
		return
	}

	g.logger.Printf("Received a chat message from client %d", senderId)
}

func (g *Npc) OnExit() {
	g.logger.Println("NPC is exiting")
	g.client.Broadcast(packets.NewLogout(), g.othersInLevel)
	g.client.SharedGameObjects().Actors.Remove(g.client.Id())
}

func (g *Npc) removeFromOtherInLevel(clientId uint32) {
	for i, id := range g.othersInLevel {
		if id == clientId {
			g.othersInLevel = append(g.othersInLevel[:i], g.othersInLevel[i+1:]...)
			return
		}
	}
}

func (g *Npc) isOtherKnown(otherId uint32) bool {
	for _, id := range g.othersInLevel {
		if id == otherId {
			return true
		}
	}
	return false
}
