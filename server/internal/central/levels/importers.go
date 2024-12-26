package levels

import (
	"context"
	"log"
	"time"

	"github.com/tristanbatchler/TwilightGroveOnline/server/pkg/ds"
)

type DataImporter[O any, M any] struct {
	nameOfObject   string
	levelPointMap  *ds.LevelPointMap[*O]
	getPoint       func(message *M) ds.Point
	addToDb        func(ctx context.Context, levelId int64, message *M) error
	removeFromDb   func(ctx context.Context, levelId int64) error
	makeGameObject func(*M) (*O, error)
	logger         *log.Logger
}

func NewDataImporter[O any, M any](
	nameOfObject string,
	levelPointMap *ds.LevelPointMap[*O],
	getPoint func(message *M) ds.Point,
	addToDb func(ctx context.Context, levelId int64, message *M) error,
	removeFromDb func(ctx context.Context, levelId int64) error,
	makeGameObject func(*M) (*O, error),
) *DataImporter[O, M] {
	return &DataImporter[O, M]{
		nameOfObject:   nameOfObject,
		levelPointMap:  levelPointMap,
		getPoint:       getPoint,
		addToDb:        addToDb,
		removeFromDb:   removeFromDb,
		makeGameObject: makeGameObject,
		logger:         log.New(log.Writer(), "LevelDataImporter: ", log.LstdFlags),
	}
}

func (l *DataImporter[O, M]) ImportObjects(
	levelId int64,
	objectMessages []*M,
) error {
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()

	batch := make(map[ds.Point]*O)
	for _, objectMsg := range objectMessages {
		gameObject, err := l.makeGameObject(objectMsg)
		if err != nil {
			l.logger.Printf("Failed to create a %s object from the message: %v", l.nameOfObject, err)
			continue
		}

		batch[l.getPoint(objectMsg)] = gameObject

		err = l.addToDb(ctx, levelId, objectMsg)
		if err != nil {
			return err
		}
	}

	l.levelPointMap.AddBatch(levelId, batch)
	l.logger.Printf("Added %d objects to the server's LevelPointMaps DS", len(batch))
	return nil
}

func (l *DataImporter[O, M]) ClearObjects(levelId int64) {
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()
	l.levelPointMap.Clear(levelId)
	l.removeFromDb(ctx, levelId)

	l.logger.Printf("Cleared all %s from the server's LevelPointMaps DS", l.nameOfObject)
}
