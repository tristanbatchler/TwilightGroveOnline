// Code generated by sqlc. DO NOT EDIT.
// versions:
//   sqlc v1.27.0
// source: queries.sql

package db

import (
	"context"

	"github.com/jackc/pgx/v5/pgtype"
)

const addActorInventoryItem = `-- name: AddActorInventoryItem :exec
INSERT INTO actors_inventory (
    actor_id, item_id, quantity
) VALUES (
    $1, $2, $3
)
ON CONFLICT(actor_id, item_id) DO UPDATE
SET quantity = actors_inventory.quantity + excluded.quantity
`

type AddActorInventoryItemParams struct {
	ActorID  int32
	ItemID   int32
	Quantity int32
}

func (q *Queries) AddActorInventoryItem(ctx context.Context, arg AddActorInventoryItemParams) error {
	_, err := q.db.Exec(ctx, addActorInventoryItem, arg.ActorID, arg.ItemID, arg.Quantity)
	return err
}

const addActorQuest = `-- name: AddActorQuest :exec
INSERT INTO actors_quests (
    actor_id, quest_id, completed
) VALUES (
    $1, $2, $3
)
ON CONFLICT(actor_id, quest_id) DO UPDATE SET completed = excluded.completed
`

type AddActorQuestParams struct {
	ActorID   int32
	QuestID   int32
	Completed bool
}

func (q *Queries) AddActorQuest(ctx context.Context, arg AddActorQuestParams) error {
	_, err := q.db.Exec(ctx, addActorQuest, arg.ActorID, arg.QuestID, arg.Completed)
	return err
}

const addActorXp = `-- name: AddActorXp :exec
INSERT INTO actors_skills (
    actor_id, skill, xp
) VALUES (
    $1, $2, $3
)
ON CONFLICT (actor_id, skill) DO UPDATE SET xp = actors_skills.xp + excluded.xp
`

type AddActorXpParams struct {
	ActorID int32
	Skill   int32
	Xp      int32
}

func (q *Queries) AddActorXp(ctx context.Context, arg AddActorXpParams) error {
	_, err := q.db.Exec(ctx, addActorXp, arg.ActorID, arg.Skill, arg.Xp)
	return err
}

const createActor = `-- name: CreateActor :one
INSERT INTO actors (
    user_id, name, level_id, x, y, sprite_region_x, sprite_region_y
) VALUES (
    $1, $2, $3, $4, $5, $6, $7
)
RETURNING id, user_id, name, level_id, x, y, sprite_region_x, sprite_region_y
`

type CreateActorParams struct {
	UserID        int32
	Name          string
	LevelID       pgtype.Int4
	X             int32
	Y             int32
	SpriteRegionX int32
	SpriteRegionY int32
}

func (q *Queries) CreateActor(ctx context.Context, arg CreateActorParams) (Actor, error) {
	row := q.db.QueryRow(ctx, createActor,
		arg.UserID,
		arg.Name,
		arg.LevelID,
		arg.X,
		arg.Y,
		arg.SpriteRegionX,
		arg.SpriteRegionY,
	)
	var i Actor
	err := row.Scan(
		&i.ID,
		&i.UserID,
		&i.Name,
		&i.LevelID,
		&i.X,
		&i.Y,
		&i.SpriteRegionX,
		&i.SpriteRegionY,
	)
	return i, err
}

const createActorIfNotExists = `-- name: CreateActorIfNotExists :one
INSERT INTO actors (
    user_id, name, x, y, sprite_region_x, sprite_region_y
) VALUES (
    $1, $2, $3, $4, $5, $6
)
ON CONFLICT (user_id) DO NOTHING
RETURNING id, user_id, name, level_id, x, y, sprite_region_x, sprite_region_y
`

type CreateActorIfNotExistsParams struct {
	UserID        int32
	Name          string
	X             int32
	Y             int32
	SpriteRegionX int32
	SpriteRegionY int32
}

func (q *Queries) CreateActorIfNotExists(ctx context.Context, arg CreateActorIfNotExistsParams) (Actor, error) {
	row := q.db.QueryRow(ctx, createActorIfNotExists,
		arg.UserID,
		arg.Name,
		arg.X,
		arg.Y,
		arg.SpriteRegionX,
		arg.SpriteRegionY,
	)
	var i Actor
	err := row.Scan(
		&i.ID,
		&i.UserID,
		&i.Name,
		&i.LevelID,
		&i.X,
		&i.Y,
		&i.SpriteRegionX,
		&i.SpriteRegionY,
	)
	return i, err
}

const createAdminIfNotExists = `-- name: CreateAdminIfNotExists :one
INSERT INTO admins (
    user_id
) VALUES (
    $1
)
ON CONFLICT (user_id) DO NOTHING
RETURNING id, user_id
`

func (q *Queries) CreateAdminIfNotExists(ctx context.Context, userID int32) (Admin, error) {
	row := q.db.QueryRow(ctx, createAdminIfNotExists, userID)
	var i Admin
	err := row.Scan(&i.ID, &i.UserID)
	return i, err
}

const createItemIfNotExists = `-- name: CreateItemIfNotExists :one
INSERT INTO items (
    name, description, value, sprite_region_x, sprite_region_y, tool_properties_id, grants_vip
) VALUES (
    $1, $2, $3, $4, $5, $6, $7
)
ON CONFLICT (name, description, value, sprite_region_x, sprite_region_y, grants_vip) DO NOTHING
RETURNING id, name, description, value, sprite_region_x, sprite_region_y, tool_properties_id, grants_vip
`

type CreateItemIfNotExistsParams struct {
	Name             string
	Description      string
	Value            int32
	SpriteRegionX    int32
	SpriteRegionY    int32
	ToolPropertiesID pgtype.Int4
	GrantsVip        bool
}

func (q *Queries) CreateItemIfNotExists(ctx context.Context, arg CreateItemIfNotExistsParams) (Item, error) {
	row := q.db.QueryRow(ctx, createItemIfNotExists,
		arg.Name,
		arg.Description,
		arg.Value,
		arg.SpriteRegionX,
		arg.SpriteRegionY,
		arg.ToolPropertiesID,
		arg.GrantsVip,
	)
	var i Item
	err := row.Scan(
		&i.ID,
		&i.Name,
		&i.Description,
		&i.Value,
		&i.SpriteRegionX,
		&i.SpriteRegionY,
		&i.ToolPropertiesID,
		&i.GrantsVip,
	)
	return i, err
}

const createLevel = `-- name: CreateLevel :one
INSERT INTO levels (
    gd_res_path, added_by_user_id, last_updated_by_user_id
) VALUES (
    $1, $2, $3
)
RETURNING id, gd_res_path, added_by_user_id, added, last_updated_by_user_id, last_updated
`

type CreateLevelParams struct {
	GdResPath           string
	AddedByUserID       int32
	LastUpdatedByUserID int32
}

func (q *Queries) CreateLevel(ctx context.Context, arg CreateLevelParams) (Level, error) {
	row := q.db.QueryRow(ctx, createLevel, arg.GdResPath, arg.AddedByUserID, arg.LastUpdatedByUserID)
	var i Level
	err := row.Scan(
		&i.ID,
		&i.GdResPath,
		&i.AddedByUserID,
		&i.Added,
		&i.LastUpdatedByUserID,
		&i.LastUpdated,
	)
	return i, err
}

const createLevelCollisionPoint = `-- name: CreateLevelCollisionPoint :one
INSERT INTO levels_collision_points (
    level_id, x, y
) VALUES (
    $1, $2, $3
)
RETURNING id, level_id, x, y
`

type CreateLevelCollisionPointParams struct {
	LevelID int32
	X       int32
	Y       int32
}

func (q *Queries) CreateLevelCollisionPoint(ctx context.Context, arg CreateLevelCollisionPointParams) (LevelsCollisionPoint, error) {
	row := q.db.QueryRow(ctx, createLevelCollisionPoint, arg.LevelID, arg.X, arg.Y)
	var i LevelsCollisionPoint
	err := row.Scan(
		&i.ID,
		&i.LevelID,
		&i.X,
		&i.Y,
	)
	return i, err
}

const createLevelDoor = `-- name: CreateLevelDoor :one
INSERT INTO levels_doors (
    level_id, destination_level_id, destination_x, destination_y, x, y, key_id
) VALUES (
    $1, $2, $3, $4, $5, $6, $7
)
RETURNING id, level_id, destination_level_id, destination_x, destination_y, x, y, key_id
`

type CreateLevelDoorParams struct {
	LevelID            int32
	DestinationLevelID int32
	DestinationX       int32
	DestinationY       int32
	X                  int32
	Y                  int32
	KeyID              pgtype.Int4
}

func (q *Queries) CreateLevelDoor(ctx context.Context, arg CreateLevelDoorParams) (LevelsDoor, error) {
	row := q.db.QueryRow(ctx, createLevelDoor,
		arg.LevelID,
		arg.DestinationLevelID,
		arg.DestinationX,
		arg.DestinationY,
		arg.X,
		arg.Y,
		arg.KeyID,
	)
	var i LevelsDoor
	err := row.Scan(
		&i.ID,
		&i.LevelID,
		&i.DestinationLevelID,
		&i.DestinationX,
		&i.DestinationY,
		&i.X,
		&i.Y,
		&i.KeyID,
	)
	return i, err
}

const createLevelGroundItem = `-- name: CreateLevelGroundItem :one
INSERT INTO levels_ground_items (
    level_id, item_id, x, y, respawn_seconds
) VALUES (
    $1, $2, $3, $4, $5
)
RETURNING id, level_id, item_id, x, y, respawn_seconds
`

type CreateLevelGroundItemParams struct {
	LevelID        int32
	ItemID         int32
	X              int32
	Y              int32
	RespawnSeconds int32
}

func (q *Queries) CreateLevelGroundItem(ctx context.Context, arg CreateLevelGroundItemParams) (LevelsGroundItem, error) {
	row := q.db.QueryRow(ctx, createLevelGroundItem,
		arg.LevelID,
		arg.ItemID,
		arg.X,
		arg.Y,
		arg.RespawnSeconds,
	)
	var i LevelsGroundItem
	err := row.Scan(
		&i.ID,
		&i.LevelID,
		&i.ItemID,
		&i.X,
		&i.Y,
		&i.RespawnSeconds,
	)
	return i, err
}

const createLevelOre = `-- name: CreateLevelOre :one
INSERT INTO levels_ores (
    level_id, strength, x, y
) VALUES (
    $1, $2, $3, $4
)
RETURNING id, level_id, strength, x, y
`

type CreateLevelOreParams struct {
	LevelID  int32
	Strength int32
	X        int32
	Y        int32
}

func (q *Queries) CreateLevelOre(ctx context.Context, arg CreateLevelOreParams) (LevelsOre, error) {
	row := q.db.QueryRow(ctx, createLevelOre,
		arg.LevelID,
		arg.Strength,
		arg.X,
		arg.Y,
	)
	var i LevelsOre
	err := row.Scan(
		&i.ID,
		&i.LevelID,
		&i.Strength,
		&i.X,
		&i.Y,
	)
	return i, err
}

const createLevelShrub = `-- name: CreateLevelShrub :one
INSERT INTO levels_shrubs (
    level_id, strength, x, y
) VALUES (
    $1, $2, $3, $4
)
RETURNING id, level_id, strength, x, y
`

type CreateLevelShrubParams struct {
	LevelID  int32
	Strength int32
	X        int32
	Y        int32
}

func (q *Queries) CreateLevelShrub(ctx context.Context, arg CreateLevelShrubParams) (LevelsShrub, error) {
	row := q.db.QueryRow(ctx, createLevelShrub,
		arg.LevelID,
		arg.Strength,
		arg.X,
		arg.Y,
	)
	var i LevelsShrub
	err := row.Scan(
		&i.ID,
		&i.LevelID,
		&i.Strength,
		&i.X,
		&i.Y,
	)
	return i, err
}

const createQuestIfNotExists = `-- name: CreateQuestIfNotExists :one
INSERT INTO quests (
    name, start_dialogue, required_item_id, completed_dialogue, reward_item_id
) VALUES (
    $1, $2, $3, $4, $5
)
ON CONFLICT (name, start_dialogue, required_item_id, completed_dialogue, reward_item_id) DO NOTHING
RETURNING id, name, start_dialogue, required_item_id, completed_dialogue, reward_item_id
`

type CreateQuestIfNotExistsParams struct {
	Name              string
	StartDialogue     string
	RequiredItemID    int32
	CompletedDialogue string
	RewardItemID      int32
}

func (q *Queries) CreateQuestIfNotExists(ctx context.Context, arg CreateQuestIfNotExistsParams) (Quest, error) {
	row := q.db.QueryRow(ctx, createQuestIfNotExists,
		arg.Name,
		arg.StartDialogue,
		arg.RequiredItemID,
		arg.CompletedDialogue,
		arg.RewardItemID,
	)
	var i Quest
	err := row.Scan(
		&i.ID,
		&i.Name,
		&i.StartDialogue,
		&i.RequiredItemID,
		&i.CompletedDialogue,
		&i.RewardItemID,
	)
	return i, err
}

const createToolPropertiesIfNotExists = `-- name: CreateToolPropertiesIfNotExists :one
INSERT INTO tool_properties (
    strength, level_required, harvests, key_id
) VALUES (
    $1, $2, $3, $4
)
ON CONFLICT (strength, level_required, harvests) DO NOTHING
RETURNING id, strength, level_required, harvests, key_id
`

type CreateToolPropertiesIfNotExistsParams struct {
	Strength      int32
	LevelRequired int32
	Harvests      int32
	KeyID         pgtype.Int4
}

func (q *Queries) CreateToolPropertiesIfNotExists(ctx context.Context, arg CreateToolPropertiesIfNotExistsParams) (ToolProperty, error) {
	row := q.db.QueryRow(ctx, createToolPropertiesIfNotExists,
		arg.Strength,
		arg.LevelRequired,
		arg.Harvests,
		arg.KeyID,
	)
	var i ToolProperty
	err := row.Scan(
		&i.ID,
		&i.Strength,
		&i.LevelRequired,
		&i.Harvests,
		&i.KeyID,
	)
	return i, err
}

const createUser = `-- name: CreateUser :one
INSERT INTO users (
    username, password_hash
) VALUES (
    $1, $2
)
RETURNING id, username, password_hash
`

type CreateUserParams struct {
	Username     string
	PasswordHash string
}

func (q *Queries) CreateUser(ctx context.Context, arg CreateUserParams) (User, error) {
	row := q.db.QueryRow(ctx, createUser, arg.Username, arg.PasswordHash)
	var i User
	err := row.Scan(&i.ID, &i.Username, &i.PasswordHash)
	return i, err
}

const createUserIfNotExists = `-- name: CreateUserIfNotExists :one
INSERT INTO users (
    username, password_hash
) VALUES (
    $1, $2
)
ON CONFLICT (username) DO NOTHING
RETURNING id, username, password_hash
`

type CreateUserIfNotExistsParams struct {
	Username     string
	PasswordHash string
}

func (q *Queries) CreateUserIfNotExists(ctx context.Context, arg CreateUserIfNotExistsParams) (User, error) {
	row := q.db.QueryRow(ctx, createUserIfNotExists, arg.Username, arg.PasswordHash)
	var i User
	err := row.Scan(&i.ID, &i.Username, &i.PasswordHash)
	return i, err
}

const deleteLevelCollisionPointsByLevelId = `-- name: DeleteLevelCollisionPointsByLevelId :exec
DELETE FROM levels_collision_points
WHERE level_id = $1
`

func (q *Queries) DeleteLevelCollisionPointsByLevelId(ctx context.Context, levelID int32) error {
	_, err := q.db.Exec(ctx, deleteLevelCollisionPointsByLevelId, levelID)
	return err
}

const deleteLevelDoorsByLevelId = `-- name: DeleteLevelDoorsByLevelId :exec
DELETE FROM levels_doors
WHERE level_id = $1
`

func (q *Queries) DeleteLevelDoorsByLevelId(ctx context.Context, levelID int32) error {
	_, err := q.db.Exec(ctx, deleteLevelDoorsByLevelId, levelID)
	return err
}

const deleteLevelGroundItem = `-- name: DeleteLevelGroundItem :exec
DELETE FROM levels_ground_items
WHERE id IN (
    SELECT lgi.id FROM levels_ground_items lgi
    WHERE lgi.level_id = $1
    AND lgi.item_id = $2
    AND lgi.x = $3
    AND lgi.y = $4
    LIMIT 1
)
`

type DeleteLevelGroundItemParams struct {
	LevelID int32
	ItemID  int32
	X       int32
	Y       int32
}

func (q *Queries) DeleteLevelGroundItem(ctx context.Context, arg DeleteLevelGroundItemParams) error {
	_, err := q.db.Exec(ctx, deleteLevelGroundItem,
		arg.LevelID,
		arg.ItemID,
		arg.X,
		arg.Y,
	)
	return err
}

const deleteLevelGroundItemsByLevelId = `-- name: DeleteLevelGroundItemsByLevelId :exec
DELETE FROM levels_ground_items
WHERE level_id = $1
`

func (q *Queries) DeleteLevelGroundItemsByLevelId(ctx context.Context, levelID int32) error {
	_, err := q.db.Exec(ctx, deleteLevelGroundItemsByLevelId, levelID)
	return err
}

const deleteLevelOre = `-- name: DeleteLevelOre :exec
DELETE FROM levels_ores
WHERE id IN (
    SELECT lo.id FROM levels_ores lo
    WHERE lo.level_id = $1
    AND lo.x = $2
    AND lo.y = $3
    LIMIT 1
)
`

type DeleteLevelOreParams struct {
	LevelID int32
	X       int32
	Y       int32
}

func (q *Queries) DeleteLevelOre(ctx context.Context, arg DeleteLevelOreParams) error {
	_, err := q.db.Exec(ctx, deleteLevelOre, arg.LevelID, arg.X, arg.Y)
	return err
}

const deleteLevelOresByLevelId = `-- name: DeleteLevelOresByLevelId :exec
DELETE FROM levels_ores
WHERE level_id = $1
`

func (q *Queries) DeleteLevelOresByLevelId(ctx context.Context, levelID int32) error {
	_, err := q.db.Exec(ctx, deleteLevelOresByLevelId, levelID)
	return err
}

const deleteLevelShrub = `-- name: DeleteLevelShrub :exec
DELETE FROM levels_shrubs
WHERE id IN (
    SELECT ls.id FROM levels_shrubs ls
    WHERE ls.level_id = $1
    AND ls.x = $2
    AND ls.y = $3
    LIMIT 1
)
`

type DeleteLevelShrubParams struct {
	LevelID int32
	X       int32
	Y       int32
}

func (q *Queries) DeleteLevelShrub(ctx context.Context, arg DeleteLevelShrubParams) error {
	_, err := q.db.Exec(ctx, deleteLevelShrub, arg.LevelID, arg.X, arg.Y)
	return err
}

const deleteLevelShrubsByLevelId = `-- name: DeleteLevelShrubsByLevelId :exec
DELETE FROM levels_shrubs
WHERE level_id = $1
`

func (q *Queries) DeleteLevelShrubsByLevelId(ctx context.Context, levelID int32) error {
	_, err := q.db.Exec(ctx, deleteLevelShrubsByLevelId, levelID)
	return err
}

const deleteLevelTscnDataByLevelId = `-- name: DeleteLevelTscnDataByLevelId :exec
DELETE FROM levels_tscn_data
WHERE level_id = $1
`

func (q *Queries) DeleteLevelTscnDataByLevelId(ctx context.Context, levelID int32) error {
	_, err := q.db.Exec(ctx, deleteLevelTscnDataByLevelId, levelID)
	return err
}

const getActorByUserId = `-- name: GetActorByUserId :one
SELECT id, user_id, name, level_id, x, y, sprite_region_x, sprite_region_y FROM actors
WHERE user_id = $1
ORDER BY id DESC
LIMIT 1
`

func (q *Queries) GetActorByUserId(ctx context.Context, userID int32) (Actor, error) {
	row := q.db.QueryRow(ctx, getActorByUserId, userID)
	var i Actor
	err := row.Scan(
		&i.ID,
		&i.UserID,
		&i.Name,
		&i.LevelID,
		&i.X,
		&i.Y,
		&i.SpriteRegionX,
		&i.SpriteRegionY,
	)
	return i, err
}

const getActorInventoryItems = `-- name: GetActorInventoryItems :many
SELECT 
    i.id as item_id, 
    i.name, 
    i.description,
    i.value,
    i.sprite_region_x, 
    i.sprite_region_y, 
    i.tool_properties_id,
    i.grants_vip,
    ai.quantity 
FROM items i
JOIN actors_inventory ai ON i.id = ai.item_id
WHERE ai.actor_id = $1
`

type GetActorInventoryItemsRow struct {
	ItemID           int32
	Name             string
	Description      string
	Value            int32
	SpriteRegionX    int32
	SpriteRegionY    int32
	ToolPropertiesID pgtype.Int4
	GrantsVip        bool
	Quantity         int32
}

func (q *Queries) GetActorInventoryItems(ctx context.Context, actorID int32) ([]GetActorInventoryItemsRow, error) {
	rows, err := q.db.Query(ctx, getActorInventoryItems, actorID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var items []GetActorInventoryItemsRow
	for rows.Next() {
		var i GetActorInventoryItemsRow
		if err := rows.Scan(
			&i.ItemID,
			&i.Name,
			&i.Description,
			&i.Value,
			&i.SpriteRegionX,
			&i.SpriteRegionY,
			&i.ToolPropertiesID,
			&i.GrantsVip,
			&i.Quantity,
		); err != nil {
			return nil, err
		}
		items = append(items, i)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return items, nil
}

const getActorQuest = `-- name: GetActorQuest :one
SELECT completed FROM actors_quests
WHERE actor_id = $1
AND quest_id = $2
`

type GetActorQuestParams struct {
	ActorID int32
	QuestID int32
}

func (q *Queries) GetActorQuest(ctx context.Context, arg GetActorQuestParams) (bool, error) {
	row := q.db.QueryRow(ctx, getActorQuest, arg.ActorID, arg.QuestID)
	var completed bool
	err := row.Scan(&completed)
	return completed, err
}

const getActorQuests = `-- name: GetActorQuests :many
SELECT 
    q.id as quest_id,
    q.name,
    q.start_dialogue,
    q.required_item_id,
    q.completed_dialogue,
    q.reward_item_id,
    aq.completed
FROM quests q
JOIN actors_quests aq ON q.id = aq.quest_id
WHERE aq.actor_id = $1
`

type GetActorQuestsRow struct {
	QuestID           int32
	Name              string
	StartDialogue     string
	RequiredItemID    int32
	CompletedDialogue string
	RewardItemID      int32
	Completed         bool
}

func (q *Queries) GetActorQuests(ctx context.Context, actorID int32) ([]GetActorQuestsRow, error) {
	rows, err := q.db.Query(ctx, getActorQuests, actorID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var items []GetActorQuestsRow
	for rows.Next() {
		var i GetActorQuestsRow
		if err := rows.Scan(
			&i.QuestID,
			&i.Name,
			&i.StartDialogue,
			&i.RequiredItemID,
			&i.CompletedDialogue,
			&i.RewardItemID,
			&i.Completed,
		); err != nil {
			return nil, err
		}
		items = append(items, i)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return items, nil
}

const getActorSkillXp = `-- name: GetActorSkillXp :one
SELECT ISNULL(xp, 0) FROM actors_skills
WHERE actor_id = $1
AND skill = $2
`

type GetActorSkillXpParams struct {
	ActorID int32
	Skill   int32
}

func (q *Queries) GetActorSkillXp(ctx context.Context, arg GetActorSkillXpParams) (interface{}, error) {
	row := q.db.QueryRow(ctx, getActorSkillXp, arg.ActorID, arg.Skill)
	var isnull interface{}
	err := row.Scan(&isnull)
	return isnull, err
}

const getActorSkillsXp = `-- name: GetActorSkillsXp :many
SELECT id, actor_id, skill, xp FROM actors_skills
WHERE actor_id = $1
`

func (q *Queries) GetActorSkillsXp(ctx context.Context, actorID int32) ([]ActorsSkill, error) {
	rows, err := q.db.Query(ctx, getActorSkillsXp, actorID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var items []ActorsSkill
	for rows.Next() {
		var i ActorsSkill
		if err := rows.Scan(
			&i.ID,
			&i.ActorID,
			&i.Skill,
			&i.Xp,
		); err != nil {
			return nil, err
		}
		items = append(items, i)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return items, nil
}

const getAdminByUserId = `-- name: GetAdminByUserId :one
SELECT id, user_id FROM admins
WHERE user_id = $1 LIMIT 1
`

func (q *Queries) GetAdminByUserId(ctx context.Context, userID int32) (Admin, error) {
	row := q.db.QueryRow(ctx, getAdminByUserId, userID)
	var i Admin
	err := row.Scan(&i.ID, &i.UserID)
	return i, err
}

const getItem = `-- name: GetItem :one
SELECT id, name, description, value, sprite_region_x, sprite_region_y, tool_properties_id, grants_vip FROM items
WHERE name = $1 AND description = $2 AND value = $3 AND sprite_region_x = $4 AND sprite_region_y = $5 and grants_vip = $6
LIMIT 1
`

type GetItemParams struct {
	Name          string
	Description   string
	Value         int32
	SpriteRegionX int32
	SpriteRegionY int32
	GrantsVip     bool
}

func (q *Queries) GetItem(ctx context.Context, arg GetItemParams) (Item, error) {
	row := q.db.QueryRow(ctx, getItem,
		arg.Name,
		arg.Description,
		arg.Value,
		arg.SpriteRegionX,
		arg.SpriteRegionY,
		arg.GrantsVip,
	)
	var i Item
	err := row.Scan(
		&i.ID,
		&i.Name,
		&i.Description,
		&i.Value,
		&i.SpriteRegionX,
		&i.SpriteRegionY,
		&i.ToolPropertiesID,
		&i.GrantsVip,
	)
	return i, err
}

const getItemById = `-- name: GetItemById :one
SELECT id, name, description, value, sprite_region_x, sprite_region_y, tool_properties_id, grants_vip FROM items
WHERE id = $1 LIMIT 1
`

func (q *Queries) GetItemById(ctx context.Context, id int32) (Item, error) {
	row := q.db.QueryRow(ctx, getItemById, id)
	var i Item
	err := row.Scan(
		&i.ID,
		&i.Name,
		&i.Description,
		&i.Value,
		&i.SpriteRegionX,
		&i.SpriteRegionY,
		&i.ToolPropertiesID,
		&i.GrantsVip,
	)
	return i, err
}

const getLevelByGdResPath = `-- name: GetLevelByGdResPath :one
SELECT id, gd_res_path, added_by_user_id, added, last_updated_by_user_id, last_updated FROM levels
WHERE gd_res_path = $1 LIMIT 1
`

func (q *Queries) GetLevelByGdResPath(ctx context.Context, gdResPath string) (Level, error) {
	row := q.db.QueryRow(ctx, getLevelByGdResPath, gdResPath)
	var i Level
	err := row.Scan(
		&i.ID,
		&i.GdResPath,
		&i.AddedByUserID,
		&i.Added,
		&i.LastUpdatedByUserID,
		&i.LastUpdated,
	)
	return i, err
}

const getLevelById = `-- name: GetLevelById :one
SELECT id, gd_res_path, added_by_user_id, added, last_updated_by_user_id, last_updated FROM levels
WHERE id = $1 LIMIT 1
`

func (q *Queries) GetLevelById(ctx context.Context, id int32) (Level, error) {
	row := q.db.QueryRow(ctx, getLevelById, id)
	var i Level
	err := row.Scan(
		&i.ID,
		&i.GdResPath,
		&i.AddedByUserID,
		&i.Added,
		&i.LastUpdatedByUserID,
		&i.LastUpdated,
	)
	return i, err
}

const getLevelCollisionPointsByLevelId = `-- name: GetLevelCollisionPointsByLevelId :many
SELECT id, level_id, x, y FROM levels_collision_points
WHERE level_id = $1
`

func (q *Queries) GetLevelCollisionPointsByLevelId(ctx context.Context, levelID int32) ([]LevelsCollisionPoint, error) {
	rows, err := q.db.Query(ctx, getLevelCollisionPointsByLevelId, levelID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var items []LevelsCollisionPoint
	for rows.Next() {
		var i LevelsCollisionPoint
		if err := rows.Scan(
			&i.ID,
			&i.LevelID,
			&i.X,
			&i.Y,
		); err != nil {
			return nil, err
		}
		items = append(items, i)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return items, nil
}

const getLevelDoorsByLevelId = `-- name: GetLevelDoorsByLevelId :many
SELECT id, level_id, destination_level_id, destination_x, destination_y, x, y, key_id FROM levels_doors
WHERE level_id = $1
`

func (q *Queries) GetLevelDoorsByLevelId(ctx context.Context, levelID int32) ([]LevelsDoor, error) {
	rows, err := q.db.Query(ctx, getLevelDoorsByLevelId, levelID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var items []LevelsDoor
	for rows.Next() {
		var i LevelsDoor
		if err := rows.Scan(
			&i.ID,
			&i.LevelID,
			&i.DestinationLevelID,
			&i.DestinationX,
			&i.DestinationY,
			&i.X,
			&i.Y,
			&i.KeyID,
		); err != nil {
			return nil, err
		}
		items = append(items, i)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return items, nil
}

const getLevelGroundItemsByLevelId = `-- name: GetLevelGroundItemsByLevelId :many
SELECT id, level_id, item_id, x, y, respawn_seconds FROM levels_ground_items
WHERE level_id = $1
`

func (q *Queries) GetLevelGroundItemsByLevelId(ctx context.Context, levelID int32) ([]LevelsGroundItem, error) {
	rows, err := q.db.Query(ctx, getLevelGroundItemsByLevelId, levelID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var items []LevelsGroundItem
	for rows.Next() {
		var i LevelsGroundItem
		if err := rows.Scan(
			&i.ID,
			&i.LevelID,
			&i.ItemID,
			&i.X,
			&i.Y,
			&i.RespawnSeconds,
		); err != nil {
			return nil, err
		}
		items = append(items, i)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return items, nil
}

const getLevelIds = `-- name: GetLevelIds :many
SELECT id FROM levels
`

func (q *Queries) GetLevelIds(ctx context.Context) ([]int32, error) {
	rows, err := q.db.Query(ctx, getLevelIds)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var items []int32
	for rows.Next() {
		var id int32
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		items = append(items, id)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return items, nil
}

const getLevelOre = `-- name: GetLevelOre :one
SELECT id, level_id, strength, x, y FROM levels_ores
WHERE level_id = $1
`

func (q *Queries) GetLevelOre(ctx context.Context, levelID int32) (LevelsOre, error) {
	row := q.db.QueryRow(ctx, getLevelOre, levelID)
	var i LevelsOre
	err := row.Scan(
		&i.ID,
		&i.LevelID,
		&i.Strength,
		&i.X,
		&i.Y,
	)
	return i, err
}

const getLevelOresByLevelId = `-- name: GetLevelOresByLevelId :many
SELECT id, level_id, strength, x, y FROM levels_ores
WHERE level_id = $1
`

func (q *Queries) GetLevelOresByLevelId(ctx context.Context, levelID int32) ([]LevelsOre, error) {
	rows, err := q.db.Query(ctx, getLevelOresByLevelId, levelID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var items []LevelsOre
	for rows.Next() {
		var i LevelsOre
		if err := rows.Scan(
			&i.ID,
			&i.LevelID,
			&i.Strength,
			&i.X,
			&i.Y,
		); err != nil {
			return nil, err
		}
		items = append(items, i)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return items, nil
}

const getLevelShrub = `-- name: GetLevelShrub :one
SELECT id, level_id, strength, x, y FROM levels_shrubs
WHERE level_id = $1
`

func (q *Queries) GetLevelShrub(ctx context.Context, levelID int32) (LevelsShrub, error) {
	row := q.db.QueryRow(ctx, getLevelShrub, levelID)
	var i LevelsShrub
	err := row.Scan(
		&i.ID,
		&i.LevelID,
		&i.Strength,
		&i.X,
		&i.Y,
	)
	return i, err
}

const getLevelShrubsByLevelId = `-- name: GetLevelShrubsByLevelId :many
SELECT id, level_id, strength, x, y FROM levels_shrubs
WHERE level_id = $1
`

func (q *Queries) GetLevelShrubsByLevelId(ctx context.Context, levelID int32) ([]LevelsShrub, error) {
	rows, err := q.db.Query(ctx, getLevelShrubsByLevelId, levelID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var items []LevelsShrub
	for rows.Next() {
		var i LevelsShrub
		if err := rows.Scan(
			&i.ID,
			&i.LevelID,
			&i.Strength,
			&i.X,
			&i.Y,
		); err != nil {
			return nil, err
		}
		items = append(items, i)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return items, nil
}

const getLevelTscnDataByLevelId = `-- name: GetLevelTscnDataByLevelId :one
SELECT level_id, tscn_data FROM levels_tscn_data
WHERE level_id = $1 LIMIT 1
`

func (q *Queries) GetLevelTscnDataByLevelId(ctx context.Context, levelID int32) (LevelsTscnDatum, error) {
	row := q.db.QueryRow(ctx, getLevelTscnDataByLevelId, levelID)
	var i LevelsTscnDatum
	err := row.Scan(&i.LevelID, &i.TscnData)
	return i, err
}

const getLevels = `-- name: GetLevels :many
SELECT id, gd_res_path, added_by_user_id, added, last_updated_by_user_id, last_updated FROM levels
`

func (q *Queries) GetLevels(ctx context.Context) ([]Level, error) {
	rows, err := q.db.Query(ctx, getLevels)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var items []Level
	for rows.Next() {
		var i Level
		if err := rows.Scan(
			&i.ID,
			&i.GdResPath,
			&i.AddedByUserID,
			&i.Added,
			&i.LastUpdatedByUserID,
			&i.LastUpdated,
		); err != nil {
			return nil, err
		}
		items = append(items, i)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return items, nil
}

const getQuest = `-- name: GetQuest :one
SELECT id, name, start_dialogue, required_item_id, completed_dialogue, reward_item_id FROM quests
WHERE name = $1 AND start_dialogue = $2 AND required_item_id = $3 AND completed_dialogue = $4 AND reward_item_id = $5
LIMIT 1
`

type GetQuestParams struct {
	Name              string
	StartDialogue     string
	RequiredItemID    int32
	CompletedDialogue string
	RewardItemID      int32
}

func (q *Queries) GetQuest(ctx context.Context, arg GetQuestParams) (Quest, error) {
	row := q.db.QueryRow(ctx, getQuest,
		arg.Name,
		arg.StartDialogue,
		arg.RequiredItemID,
		arg.CompletedDialogue,
		arg.RewardItemID,
	)
	var i Quest
	err := row.Scan(
		&i.ID,
		&i.Name,
		&i.StartDialogue,
		&i.RequiredItemID,
		&i.CompletedDialogue,
		&i.RewardItemID,
	)
	return i, err
}

const getQuestById = `-- name: GetQuestById :one
SELECT id, name, start_dialogue, required_item_id, completed_dialogue, reward_item_id FROM quests
WHERE id = $1 LIMIT 1
`

func (q *Queries) GetQuestById(ctx context.Context, id int32) (Quest, error) {
	row := q.db.QueryRow(ctx, getQuestById, id)
	var i Quest
	err := row.Scan(
		&i.ID,
		&i.Name,
		&i.StartDialogue,
		&i.RequiredItemID,
		&i.CompletedDialogue,
		&i.RewardItemID,
	)
	return i, err
}

const getToolProperties = `-- name: GetToolProperties :one
SELECT id, strength, level_required, harvests, key_id FROM tool_properties 
WHERE strength = $1 AND level_required = $2 AND harvests = $3
AND (key_id = $4 OR (key_id IS NULL AND $4 IS NULL)) -- key_id is nullable
LIMIT 1
`

type GetToolPropertiesParams struct {
	Strength      int32
	LevelRequired int32
	Harvests      int32
	KeyID         pgtype.Int4
}

func (q *Queries) GetToolProperties(ctx context.Context, arg GetToolPropertiesParams) (ToolProperty, error) {
	row := q.db.QueryRow(ctx, getToolProperties,
		arg.Strength,
		arg.LevelRequired,
		arg.Harvests,
		arg.KeyID,
	)
	var i ToolProperty
	err := row.Scan(
		&i.ID,
		&i.Strength,
		&i.LevelRequired,
		&i.Harvests,
		&i.KeyID,
	)
	return i, err
}

const getToolPropertiesById = `-- name: GetToolPropertiesById :one
SELECT id, strength, level_required, harvests, key_id FROM tool_properties
WHERE id = $1 LIMIT 1
`

func (q *Queries) GetToolPropertiesById(ctx context.Context, id int32) (ToolProperty, error) {
	row := q.db.QueryRow(ctx, getToolPropertiesById, id)
	var i ToolProperty
	err := row.Scan(
		&i.ID,
		&i.Strength,
		&i.LevelRequired,
		&i.Harvests,
		&i.KeyID,
	)
	return i, err
}

const getUserByUsername = `-- name: GetUserByUsername :one
SELECT id, username, password_hash FROM users
WHERE username = $1
ORDER BY id DESC
LIMIT 1
`

func (q *Queries) GetUserByUsername(ctx context.Context, username string) (User, error) {
	row := q.db.QueryRow(ctx, getUserByUsername, username)
	var i User
	err := row.Scan(&i.ID, &i.Username, &i.PasswordHash)
	return i, err
}

const getUserIdByActorId = `-- name: GetUserIdByActorId :one
SELECT user_id FROM actors
WHERE id = $1 LIMIT 1
`

func (q *Queries) GetUserIdByActorId(ctx context.Context, id int32) (int32, error) {
	row := q.db.QueryRow(ctx, getUserIdByActorId, id)
	var user_id int32
	err := row.Scan(&user_id)
	return user_id, err
}

const isActorAdmin = `-- name: IsActorAdmin :one
SELECT 1 FROM users u
JOIN admins ad ON u.id = ad.user_id
JOIN actors ac ON u.id = ac.user_id
WHERE ac.id = $1 LIMIT 1
`

func (q *Queries) IsActorAdmin(ctx context.Context, id int32) (int32, error) {
	row := q.db.QueryRow(ctx, isActorAdmin, id)
	var column_1 int32
	err := row.Scan(&column_1)
	return column_1, err
}

const removeActorInventoryItem = `-- name: RemoveActorInventoryItem :exec
DELETE FROM actors_inventory
WHERE actor_id = $1
AND item_id = $2
`

type RemoveActorInventoryItemParams struct {
	ActorID int32
	ItemID  int32
}

func (q *Queries) RemoveActorInventoryItem(ctx context.Context, arg RemoveActorInventoryItemParams) error {
	_, err := q.db.Exec(ctx, removeActorInventoryItem, arg.ActorID, arg.ItemID)
	return err
}

const updateActorLevel = `-- name: UpdateActorLevel :exec
UPDATE actors
SET level_id = $2
WHERE id = $1
`

type UpdateActorLevelParams struct {
	ID      int32
	LevelID pgtype.Int4
}

func (q *Queries) UpdateActorLevel(ctx context.Context, arg UpdateActorLevelParams) error {
	_, err := q.db.Exec(ctx, updateActorLevel, arg.ID, arg.LevelID)
	return err
}

const updateActorLocation = `-- name: UpdateActorLocation :exec
UPDATE actors
SET level_id = $2, x = $3, y = $4
WHERE id = $1
`

type UpdateActorLocationParams struct {
	ID      int32
	LevelID pgtype.Int4
	X       int32
	Y       int32
}

func (q *Queries) UpdateActorLocation(ctx context.Context, arg UpdateActorLocationParams) error {
	_, err := q.db.Exec(ctx, updateActorLocation,
		arg.ID,
		arg.LevelID,
		arg.X,
		arg.Y,
	)
	return err
}

const updateLevelLastUpdated = `-- name: UpdateLevelLastUpdated :exec
UPDATE levels
SET last_updated = CURRENT_TIMESTAMP
AND last_updated_by_user_id = $2
WHERE id = $1
`

type UpdateLevelLastUpdatedParams struct {
	ID                  int32
	LastUpdatedByUserID int32
}

func (q *Queries) UpdateLevelLastUpdated(ctx context.Context, arg UpdateLevelLastUpdatedParams) error {
	_, err := q.db.Exec(ctx, updateLevelLastUpdated, arg.ID, arg.LastUpdatedByUserID)
	return err
}

const upsertActorInventoryItem = `-- name: UpsertActorInventoryItem :exec
INSERT INTO actors_inventory (
    actor_id, item_id, quantity
) VALUES (
    $1, $2, $3
)
ON CONFLICT (actor_id, item_id) DO UPDATE SET quantity = EXCLUDED.quantity
`

type UpsertActorInventoryItemParams struct {
	ActorID  int32
	ItemID   int32
	Quantity int32
}

func (q *Queries) UpsertActorInventoryItem(ctx context.Context, arg UpsertActorInventoryItemParams) error {
	_, err := q.db.Exec(ctx, upsertActorInventoryItem, arg.ActorID, arg.ItemID, arg.Quantity)
	return err
}

const upsertActorQuest = `-- name: UpsertActorQuest :exec
INSERT INTO actors_quests (
    actor_id, quest_id, completed
) VALUES (
    $1, $2, $3
)
ON CONFLICT(actor_id, quest_id) DO UPDATE SET completed = excluded.completed
`

type UpsertActorQuestParams struct {
	ActorID   int32
	QuestID   int32
	Completed bool
}

func (q *Queries) UpsertActorQuest(ctx context.Context, arg UpsertActorQuestParams) error {
	_, err := q.db.Exec(ctx, upsertActorQuest, arg.ActorID, arg.QuestID, arg.Completed)
	return err
}

const upsertLevelTscnData = `-- name: UpsertLevelTscnData :one
INSERT INTO levels_tscn_data (
    level_id, tscn_data
) VALUES (
    $1, $2
)
ON CONFLICT (level_id) DO UPDATE SET tscn_data = EXCLUDED.tscn_data
RETURNING level_id, tscn_data
`

type UpsertLevelTscnDataParams struct {
	LevelID  int32
	TscnData []byte
}

func (q *Queries) UpsertLevelTscnData(ctx context.Context, arg UpsertLevelTscnDataParams) (LevelsTscnDatum, error) {
	row := q.db.QueryRow(ctx, upsertLevelTscnData, arg.LevelID, arg.TscnData)
	var i LevelsTscnDatum
	err := row.Scan(&i.LevelID, &i.TscnData)
	return i, err
}
