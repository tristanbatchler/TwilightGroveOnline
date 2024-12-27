package states

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"log"
	"os"
	"strings"
	"time"

	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/central"
	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/central/db"
	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/objs"
	"github.com/tristanbatchler/TwilightGroveOnline/server/pkg/packets"
	"golang.org/x/crypto/bcrypt"
)

type Connected struct {
	client  central.ClientInterfacer
	queries *db.Queries
	logger  *log.Logger
}

func (c *Connected) Name() string {
	return "Connected"
}

func (c *Connected) SetClient(client central.ClientInterfacer) {
	c.client = client
	loggingPrefix := fmt.Sprintf("Client %d [%s]: ", client.Id(), c.Name())
	c.queries = client.DbTx().Queries
	c.logger = log.New(log.Writer(), loggingPrefix, log.LstdFlags)
}

func (c *Connected) OnEnter() {
	// A newly connected client will want to know its own ID first
	c.client.SocketSend(packets.NewClientId(c.client.Id()))

	// Load the MOTD
	motdPath := c.client.GameData().MotdPath
	motd, err := os.ReadFile(motdPath)
	if err != nil {
		c.logger.Printf("Failed to load MOTD: %v", err)
	} else {
		c.client.SocketSend(packets.NewMotd(string(motd)))
	}

}

func (c *Connected) HandleMessage(senderId uint64, message packets.Msg) {
	switch message := message.(type) {
	case *packets.Packet_LoginRequest:
		c.handleLoginRequest(senderId, message)
	case *packets.Packet_RegisterRequest:
		c.handleRegisterRequest(senderId, message)
	}
}

func (c *Connected) handleLoginRequest(_ uint64, message *packets.Packet_LoginRequest) {
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()

	genericError := errors.New("invalid username or password")

	user, err := c.queries.GetUserByUsername(ctx, strings.ToLower(message.LoginRequest.Username))
	if err != nil {
		c.logger.Printf("Login failed: %v", err)
		c.client.SocketSend(packets.NewLoginResponse(false, genericError))
		return
	}

	// Check if the user is already in the game
	player, err := c.queries.GetActorByUserId(ctx, user.ID)
	found := false
	c.client.SharedGameObjects().Actors.ForEach(func(_ uint64, actor *objs.Actor) {
		if found {
			return
		}
		if actor.DbId == player.ID {
			found = true
			return
		}
	})
	if found {
		c.logger.Printf("User %s is already in the game", user.Username)
		c.client.SocketSend(packets.NewLoginResponse(false, errors.New("already logged in")))
		return
	}

	err = bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(message.LoginRequest.Password))
	if err != nil {
		c.logger.Printf("Login failed: %v", err)
		c.client.SocketSend(packets.NewLoginResponse(false, genericError))
		return
	}

	admin, err := c.queries.GetAdminByUserId(ctx, user.ID)
	if err == nil {
		c.logger.Printf("Admin login: %s", user.Username)
		c.client.SocketSend(packets.NewAdminLoginGranted())
		c.client.SetState(&Admin{adminModel: &admin})
		return
	}
	if err != sql.ErrNoRows {
		c.logger.Printf("Failed to get admin for user %s: %v", user.Username, err)
		// It's OK to send the specific error since this is an admin
		c.client.SocketSend(packets.NewLoginResponse(false, err))
		return
	}

	actor, err := c.queries.GetActorByUserId(ctx, user.ID)
	if err != nil {
		c.logger.Printf("Failed to get actor for user %s: %v", user.Username, err)
		c.client.SocketSend(packets.NewLoginResponse(false, errors.New("internal server error, please try again later")))
		return
	}

	c.logger.Println("Login successful")
	c.client.SocketSend(packets.NewLoginResponse(true, nil))

	c.client.SetState(&InGame{
		levelId: actor.LevelID,
		player:  objs.NewActor(actor.LevelID, actor.X, actor.Y, actor.Name, actor.ID),
	})
}

func (c *Connected) handleRegisterRequest(_ uint64, message *packets.Packet_RegisterRequest) {
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()

	username := strings.ToLower(message.RegisterRequest.Username)
	err := validateUsername(username)
	if err != nil {
		reason := fmt.Sprintf("invalid username: %v", err)
		c.logger.Println(reason)
		c.client.SocketSend(packets.NewRegisterResponse(false, errors.New(reason)))
		return
	}

	_, err = c.queries.GetUserByUsername(ctx, username)
	if err == nil {
		c.logger.Printf("User already exists: %s", username)
		c.client.SocketSend(packets.NewRegisterResponse(false, errors.New("user already exists")))
		return
	}

	genericFailMessage := packets.NewRegisterResponse(false, errors.New("internal server error, please try again later"))

	// Add new user
	passwordHash, err := bcrypt.GenerateFromPassword([]byte(message.RegisterRequest.Password), bcrypt.DefaultCost)
	if err != nil {
		c.logger.Printf("Failed to hash password: %s", username)
		c.client.SocketSend(genericFailMessage)
		return
	}

	user, err := c.queries.CreateUser(ctx, db.CreateUserParams{
		Username:     username,
		PasswordHash: string(passwordHash),
	})

	if err != nil {
		c.logger.Printf("Failed to create user %s: %v", username, err)
		c.client.SocketSend(genericFailMessage)
		return
	}

	// TODO: Don't hardcode level ID
	const levelId = 1
	_, err = c.queries.CreateActor(ctx, db.CreateActorParams{
		LevelID: levelId,
		X:       -1,
		Y:       -1,
		Name:    message.RegisterRequest.Username,
		UserID:  user.ID,
	})

	if err != nil {
		c.logger.Printf("Failed to create actor for user %s: %v", username, err)
		c.client.SocketSend(genericFailMessage)
		return
	}

	c.client.SocketSend(packets.NewRegisterResponse(true, nil))

	c.logger.Printf("User %s registered successfully", username)
}

func (c *Connected) OnExit() {
}

func validateUsername(username string) error {
	if len(username) <= 0 {
		return errors.New("empty")
	}
	if len(username) > 20 {
		return errors.New("too long")
	}
	if username != strings.TrimSpace(username) {
		return errors.New("leading or trailing whitespace")
	}
	return nil
}
