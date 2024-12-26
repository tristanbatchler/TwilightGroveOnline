package levels

import (
	"context"
	"log"
	"time"

	"github.com/tristanbatchler/TwilightGroveOnline/server/pkg/ds"
)

type PacketDataImporter[O any, M any] struct {
	nameOfObject   string
	levelPointMap  *ds.LevelPointMap[*O]
	getPoint       func(message *M) ds.Point
	addToDb        func(ctx context.Context, levelId int64, message *M) error
	removeFromDb   func(ctx context.Context, levelId int64) error
	makeGameObject func(*M) (*O, error)
	logger         *log.Logger
}

func NewPacketDataImporter[O any, M any](
	nameOfObject string,
	levelPointMap *ds.LevelPointMap[*O],
	getPoint func(message *M) ds.Point,
	addToDb func(ctx context.Context, levelId int64, message *M) error,
	removeFromDb func(ctx context.Context, levelId int64) error,
	makeGameObject func(*M) (*O, error),
) *PacketDataImporter[O, M] {
	return &PacketDataImporter[O, M]{
		nameOfObject:   nameOfObject,
		levelPointMap:  levelPointMap,
		getPoint:       getPoint,
		addToDb:        addToDb,
		removeFromDb:   removeFromDb,
		makeGameObject: makeGameObject,
		logger:         log.New(log.Writer(), "PacketLevelDataImporter: ", log.LstdFlags),
	}
}

func (p *PacketDataImporter[O, M]) ImportObjects(
	levelId int64,
	objectMessages []*M,
) error {
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()

	batch := make(map[ds.Point]*O)
	for _, objectMsg := range objectMessages {
		gameObject, err := p.makeGameObject(objectMsg)
		if err != nil {
			p.logger.Printf("Failed to create a %s object from the message: %v", p.nameOfObject, err)
			continue
		}

		batch[p.getPoint(objectMsg)] = gameObject

		err = p.addToDb(ctx, levelId, objectMsg)
		if err != nil {
			return err
		}
	}

	p.levelPointMap.AddBatch(levelId, batch)
	p.logger.Printf("Added %d %s objects to the server's LevelPointMaps DS", len(batch), p.nameOfObject)
	return nil
}

func (p *PacketDataImporter[O, M]) ClearObjects(levelId int64) {
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()
	p.levelPointMap.Clear(levelId)
	p.removeFromDb(ctx, levelId)

	p.logger.Printf("Cleared all %s from the server's LevelPointMaps DS", p.nameOfObject)
}
