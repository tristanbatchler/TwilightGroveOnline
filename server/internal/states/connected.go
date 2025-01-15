package states

import (
	"context"
	"errors"
	"fmt"
	"log"
	"os"
	"strings"
	"time"

	goaway "github.com/TwiN/go-away"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/central"
	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/central/db"
	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/objs"
	"github.com/tristanbatchler/TwilightGroveOnline/server/pkg/packets"
	"golang.org/x/crypto/bcrypt"
)

type Connected struct {
	client            central.ClientInterfacer
	queries           *db.Queries
	logger            *log.Logger
	profanityDetector *goaway.ProfanityDetector
}

func (c *Connected) Name() string {
	return "Connected"
}

func (c *Connected) SetClient(client central.ClientInterfacer) {
	c.client = client
	loggingPrefix := fmt.Sprintf("Client %d [%s]: ", client.Id(), c.Name())
	c.queries = client.DbTx().Queries
	c.logger = log.New(log.Writer(), loggingPrefix, log.LstdFlags)
	c.profanityDetector = goaway.NewProfanityDetector().WithCustomDictionary(client.GameData().Profanity, []string{}, []string{})
}

func (c *Connected) OnEnter() {
	// A newly connected client will want to know its own ID first
	c.client.SocketSend(packets.NewClientId(c.client.Id()))

	// Send the levels metadata from the database, i.e. GD res paths to DB Ids
	levels_metadata, err := c.queries.GetLevels(context.Background())
	if err != nil {
		c.logger.Printf("Failed to get levels metadata: %v", err)
		c.client.SocketSend(packets.NewServerMessage("Failed to get levels metadata, please report this to a developer"))
		return
	}
	for _, level := range levels_metadata {
		c.client.SocketSend(packets.NewLevelMetadata(level.GdResPath, level.ID))
	}
	c.logger.Printf("Sent %d levels metadata", len(levels_metadata))

	// Load the MOTD
	motdPath := c.client.GameData().MotdPath
	motd, err := os.ReadFile(motdPath)
	if err != nil {
		c.logger.Printf("Failed to load MOTD: %v", err)
	} else {
		c.client.SocketSend(packets.NewMotd(string(motd)))
	}

}

func (c *Connected) HandleMessage(senderId uint32, message packets.Msg) {
	switch message := message.(type) {
	case *packets.Packet_LoginRequest:
		c.handleLoginRequest(senderId, message)
	case *packets.Packet_RegisterRequest:
		c.handleRegisterRequest(senderId, message)
	}
}

func (c *Connected) handleLoginRequest(_ uint32, message *packets.Packet_LoginRequest) {
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
	c.client.SharedGameObjects().Actors.ForEach(func(_ uint32, actor *objs.Actor) {
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
	if err != pgx.ErrNoRows {
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

	if !actor.LevelID.Valid {
		c.logger.Printf("Actor %s has no level ID", actor.Name)
		c.client.SocketSend(packets.NewLoginResponse(false, errors.New("internal server error, please try again later")))
		return
	}

	c.client.SetState(&InGame{
		levelId: actor.LevelID.Int32,
		player:  objs.NewActor(actor.LevelID.Int32, actor.X, actor.Y, actor.Name, actor.SpriteRegionX, actor.SpriteRegionY, actor.ID),
	})
}

func (c *Connected) handleRegisterRequest(_ uint32, message *packets.Packet_RegisterRequest) {
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()

	username := strings.ToLower(message.RegisterRequest.Username)
	err := c.validateUsername(username)
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

	level, err := c.queries.GetLevelById(ctx, 1)
	if err != nil {
		c.logger.Printf("Failed to get level %d: %v", level.ID, err)
		c.client.SocketSend(genericFailMessage)
		return
	}
	_, err = c.queries.CreateActor(ctx, db.CreateActorParams{
		LevelID:       pgtype.Int4{Int32: level.ID, Valid: true},
		X:             -1,
		Y:             -1,
		Name:          message.RegisterRequest.Username,
		SpriteRegionX: message.RegisterRequest.SpriteRegionX,
		SpriteRegionY: message.RegisterRequest.SpriteRegionY,
		UserID:        user.ID,
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

func (c *Connected) validateUsername(username string) error {
	if len(username) <= 0 {
		return errors.New("empty")
	}
	if len(username) > 20 {
		return errors.New("too long")
	}
	if username != strings.TrimSpace(username) {
		return errors.New("leading or trailing whitespace")
	}
	if c.profanityDetector.IsProfane(username) {
		return errors.New("watch your profanity")
	}

	return nil
}
