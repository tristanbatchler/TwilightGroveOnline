package levels

import (
	"context"
	"log"
	"time"

	"github.com/tristanbatchler/TwilightGroveOnline/server/pkg/ds"
)

type DbDataImporter[O any, M any] struct {
	NameOfObject   string
	levelPointMap  *ds.LevelPointMap[*O]
	getPoint       func(message *M) ds.Point
	getFromDb      func(ctx context.Context, levelId int64) ([]M, error)
	makeGameObject func(*M) (*O, error)
	logger         *log.Logger
}

func NewDbDataImporter[O any, M any](
	nameOfObject string,
	levelPointMap *ds.LevelPointMap[*O],
	getPoint func(message *M) ds.Point,
	getFromDb func(ctx context.Context, levelId int64) ([]M, error),
	makeGameObject func(*M) (*O, error),
) *DbDataImporter[O, M] {
	return &DbDataImporter[O, M]{
		NameOfObject:   nameOfObject,
		levelPointMap:  levelPointMap,
		getPoint:       getPoint,
		getFromDb:      getFromDb,
		makeGameObject: makeGameObject,
		logger:         log.New(log.Writer(), "DbLevelDataImporter: ", log.LstdFlags),
	}
}

func (d *DbDataImporter[O, M]) ImportObjects(
	levelId int64,
) error {
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()

	objectModels, err := d.getFromDb(ctx, levelId)
	if err != nil {
		d.logger.Printf("Failed to get %s objects from the database: %v", d.NameOfObject, err)
		return err
	}

	batch := make(map[ds.Point]*O, len(objectModels))
	for _, objectModel := range objectModels {
		object, err := d.makeGameObject(&objectModel)
		if err != nil {
			d.logger.Printf("Failed to create a %s object from the model: %v", d.NameOfObject, err)
			continue
		}

		batch[d.getPoint(&objectModel)] = object
	}

	d.levelPointMap.AddBatch(levelId, batch)
	d.logger.Printf("Added %d %s objects to the server's LevelPointMaps DS", len(batch), d.NameOfObject)
	return nil
}
