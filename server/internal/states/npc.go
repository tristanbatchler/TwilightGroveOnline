package states

import (
	"fmt"
	"log"
	"math/rand/v2"
	"strings"
	"time"

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

func (n *Npc) Name() string {
	return "Npc"
}

func (n *Npc) SetClient(client central.ClientInterfacer) {
	n.client = client
	loggingPrefix := fmt.Sprintf("Client %d [%s]: ", client.Id(), n.Name())
	n.logger = log.New(log.Writer(), loggingPrefix, log.LstdFlags)
}

func (n *Npc) OnEnter() {
	n.levelId = 1
	n.actor = objs.NewActor(n.levelId, -rand.Int32N(7), rand.Int32N(5), "NPC", 0)

	n.client.SharedGameObjects().Actors.Add(n.actor, n.client.Id())

	// Collect info about all the other actors in the level
	ourActorInfo := packets.NewActor(n.actor)
	n.client.SharedGameObjects().Actors.ForEach(func(owner_client_id uint32, actor *objs.Actor) {
		if actor.LevelId == n.levelId {
			n.othersInLevel = append(n.othersInLevel, owner_client_id)
		}
	})

	// Send our info back to all the other clients in the level
	n.client.Broadcast(ourActorInfo, n.othersInLevel)
}

func (n *Npc) HandleMessage(senderId uint32, message packets.Msg) {
	switch message := message.(type) {
	case *packets.Packet_Chat:
		n.handleChat(senderId, message)
	case *packets.Packet_Actor:
		n.handleActorInfo(senderId, message)
	}
}

func (n *Npc) handleChat(senderId uint32, message *packets.Packet_Chat) {
	if strings.TrimSpace(message.Chat.Msg) == "" {
		n.logger.Println("Received a chat message with no content, ignoring")
		return
	}

	n.logger.Printf("Received a chat message from client %d", senderId)
	fromActor, exists := n.client.SharedGameObjects().Actors.Get(senderId)
	if exists {
		go func() {
			time.Sleep(500 * time.Millisecond)
			n.client.Broadcast(packets.NewChat(fmt.Sprintf("Hello, %s", fromActor.Name)), n.othersInLevel)
		}()
	}
}

func (n *Npc) OnExit() {
	n.logger.Println("NPC is exiting")
	n.client.Broadcast(packets.NewLogout(), n.othersInLevel)
	n.client.SharedGameObjects().Actors.Remove(n.client.Id())
}

func (n *Npc) handleActorInfo(senderId uint32, _ *packets.Packet_Actor) {
	if senderId == n.client.Id() {
		n.logger.Printf("Received a actor info message from ourselves, ignoring")
		return
	}

	if !n.isOtherKnown(senderId) {
		n.othersInLevel = append(n.othersInLevel, senderId)
		n.client.PassToPeer(packets.NewActor(n.actor), senderId)
	}
}

func (n *Npc) removeFromOtherInLevel(clientId uint32) {
	for i, id := range n.othersInLevel {
		if id == clientId {
			n.othersInLevel = append(n.othersInLevel[:i], n.othersInLevel[i+1:]...)
			return
		}
	}
}

func (n *Npc) isOtherKnown(otherId uint32) bool {
	for _, id := range n.othersInLevel {
		if id == otherId {
			return true
		}
	}
	return false
}
