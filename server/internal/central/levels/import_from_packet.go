package levels

import (
	"context"
	"log"
	"time"

	"github.com/tristanbatchler/TwilightGroveOnline/server/pkg/ds"
)

type PacketDataImporter[O any, M any] struct {
	nameOfObject     string
	levelPointMap    *ds.LevelPointMap[*O]
	sharedCollection *ds.SharedCollection[*O]
	getPoint         func(message *M) ds.Point
	addToDb          func(ctx context.Context, levelId int64, message *M) error
	removeFromDb     func(ctx context.Context, levelId int64) error
	setObjectId      func(object *O, id uint64)
	MakeGameObject   func(*M) (*O, error)
	getObjectLevelId func(object *O) int64
	logger           *log.Logger
}

func NewPacketDataImporter[O any, M any](
	nameOfObject string,
	levelPointMap *ds.LevelPointMap[*O],
	sharedCollection *ds.SharedCollection[*O],
	getPoint func(message *M) ds.Point,
	addToDb func(ctx context.Context, levelId int64, message *M) error,
	removeFromDb func(ctx context.Context, levelId int64) error,
	setObjectId func(object *O, id uint64),
	makeGameObject func(*M) (*O, error),
	getObjectLevelId func(object *O) int64,
) *PacketDataImporter[O, M] {
	return &PacketDataImporter[O, M]{
		nameOfObject:     nameOfObject,
		levelPointMap:    levelPointMap,
		sharedCollection: sharedCollection,
		getPoint:         getPoint,
		addToDb:          addToDb,
		removeFromDb:     removeFromDb,
		setObjectId:      setObjectId,
		MakeGameObject:   makeGameObject,
		getObjectLevelId: getObjectLevelId,
		logger:           log.New(log.Writer(), "PacketLevelDataImporter: ", log.LstdFlags),
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
		gameObject, err := p.MakeGameObject(objectMsg)
		if err != nil {
			p.logger.Printf("Failed to create a %s object from the message: %v", p.nameOfObject, err)
			continue
		}

		// TODO: Make an AddBatch method for SharedCollection
		if p.sharedCollection != nil {
			objId := p.sharedCollection.Add(gameObject)
			p.setObjectId(gameObject, objId)
			p.logger.Printf("Added a %s object to the server's SharedCollection DS", p.nameOfObject)
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
	if p.sharedCollection != nil {
		p.sharedCollection.ForEach(func(id uint64, obj *O) {
			if p.getObjectLevelId(obj) == levelId {
				p.sharedCollection.Remove(id)
			}
		})
	}
	p.removeFromDb(ctx, levelId)

	p.logger.Printf("Cleared all %s from the server's LevelPointMaps DS", p.nameOfObject)
}
