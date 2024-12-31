package levels

import (
	"context"
	"log"
	"time"

	"github.com/tristanbatchler/TwilightGroveOnline/server/pkg/ds"
)

type DbDataImporter[O any, M any] struct {
	NameOfObject     string
	levelPointMap    *ds.LevelPointMap[*O]
	sharedCollection *ds.SharedCollection[*O]
	getPoint         func(message *M) ds.Point
	getFromDb        func(ctx context.Context, levelId int32) ([]M, error)
	setObjectId      func(object *O, id uint32)
	makeGameObject   func(*M) (*O, error)
	logger           *log.Logger
}

func NewDbDataImporter[O any, M any](
	nameOfObject string,
	levelPointMap *ds.LevelPointMap[*O],
	sharedCollection *ds.SharedCollection[*O],
	getPoint func(message *M) ds.Point,
	getFromDb func(ctx context.Context, levelId int32) ([]M, error),
	setObjectId func(object *O, id uint32),
	makeGameObject func(*M) (*O, error),
) *DbDataImporter[O, M] {
	return &DbDataImporter[O, M]{
		NameOfObject:     nameOfObject,
		levelPointMap:    levelPointMap,
		sharedCollection: sharedCollection,
		getPoint:         getPoint,
		getFromDb:        getFromDb,
		setObjectId:      setObjectId,
		makeGameObject:   makeGameObject,
		logger:           log.New(log.Writer(), "DbLevelDataImporter: ", log.LstdFlags),
	}
}

func (d *DbDataImporter[O, M]) ImportObjects(
	levelId int32,
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

		// TODO: Make an AddBatch method for SharedCollection
		if d.sharedCollection != nil {
			objId := d.sharedCollection.Add(object)
			d.setObjectId(object, objId)
			d.logger.Printf("Added a %s object to the server's SharedCollection DS", d.NameOfObject)
		}

		batch[d.getPoint(&objectModel)] = object
	}

	d.levelPointMap.AddBatch(levelId, batch)
	d.logger.Printf("Added %d %s objects to the server's LevelPointMaps DS", len(batch), d.NameOfObject)
	return nil
}
