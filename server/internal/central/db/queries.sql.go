// Code generated by sqlc. DO NOT EDIT.
// versions:
//   sqlc v1.27.0
// source: queries.sql

package db

import (
	"context"
	"database/sql"
)

const addActorInventoryItem = `-- name: AddActorInventoryItem :exec
INSERT INTO actors_inventory (
    actor_id, item_id, quantity
) VALUES (
    ?, ?, ?
)
ON CONFLICT(actor_id, item_id) DO UPDATE
SET quantity = actors_inventory.quantity + excluded.quantity
`

type AddActorInventoryItemParams struct {
	ActorID  int64
	ItemID   int64
	Quantity int64
}

func (q *Queries) AddActorInventoryItem(ctx context.Context, arg AddActorInventoryItemParams) error {
	_, err := q.db.ExecContext(ctx, addActorInventoryItem, arg.ActorID, arg.ItemID, arg.Quantity)
	return err
}

const createActor = `-- name: CreateActor :one
INSERT INTO actors (
    user_id, name, level_id, x, y
) VALUES (
    ?, ?, ?, ?, ?
)
RETURNING id, user_id, name, level_id, x, y
`

type CreateActorParams struct {
	UserID  int64
	Name    string
	LevelID int64
	X       int64
	Y       int64
}

func (q *Queries) CreateActor(ctx context.Context, arg CreateActorParams) (Actor, error) {
	row := q.db.QueryRowContext(ctx, createActor,
		arg.UserID,
		arg.Name,
		arg.LevelID,
		arg.X,
		arg.Y,
	)
	var i Actor
	err := row.Scan(
		&i.ID,
		&i.UserID,
		&i.Name,
		&i.LevelID,
		&i.X,
		&i.Y,
	)
	return i, err
}

const createActorIfNotExists = `-- name: CreateActorIfNotExists :one
INSERT INTO actors (
    user_id, name, level_id, x, y
) VALUES (
    ?, ?, ?, ?, ?
)
ON CONFLICT (user_id) DO NOTHING
RETURNING id, user_id, name, level_id, x, y
`

type CreateActorIfNotExistsParams struct {
	UserID  int64
	Name    string
	LevelID int64
	X       int64
	Y       int64
}

func (q *Queries) CreateActorIfNotExists(ctx context.Context, arg CreateActorIfNotExistsParams) (Actor, error) {
	row := q.db.QueryRowContext(ctx, createActorIfNotExists,
		arg.UserID,
		arg.Name,
		arg.LevelID,
		arg.X,
		arg.Y,
	)
	var i Actor
	err := row.Scan(
		&i.ID,
		&i.UserID,
		&i.Name,
		&i.LevelID,
		&i.X,
		&i.Y,
	)
	return i, err
}

const createAdminIfNotExists = `-- name: CreateAdminIfNotExists :one
INSERT INTO admins (
    user_id
) VALUES (
    ?
)
ON CONFLICT (user_id) DO NOTHING
RETURNING id, user_id
`

func (q *Queries) CreateAdminIfNotExists(ctx context.Context, userID int64) (Admin, error) {
	row := q.db.QueryRowContext(ctx, createAdminIfNotExists, userID)
	var i Admin
	err := row.Scan(&i.ID, &i.UserID)
	return i, err
}

const createItemIfNotExists = `-- name: CreateItemIfNotExists :one
INSERT INTO items (
    name, description, sprite_region_x, sprite_region_y, tool_properties_id
) VALUES (
    ?, ?, ?, ?, ?
)
ON CONFLICT (name, description, sprite_region_x, sprite_region_y) DO NOTHING
RETURNING id, name, description, sprite_region_x, sprite_region_y, tool_properties_id
`

type CreateItemIfNotExistsParams struct {
	Name             string
	Description      string
	SpriteRegionX    int64
	SpriteRegionY    int64
	ToolPropertiesID sql.NullInt64
}

func (q *Queries) CreateItemIfNotExists(ctx context.Context, arg CreateItemIfNotExistsParams) (Item, error) {
	row := q.db.QueryRowContext(ctx, createItemIfNotExists,
		arg.Name,
		arg.Description,
		arg.SpriteRegionX,
		arg.SpriteRegionY,
		arg.ToolPropertiesID,
	)
	var i Item
	err := row.Scan(
		&i.ID,
		&i.Name,
		&i.Description,
		&i.SpriteRegionX,
		&i.SpriteRegionY,
		&i.ToolPropertiesID,
	)
	return i, err
}

const createLevel = `-- name: CreateLevel :one
INSERT INTO levels (
    gd_res_path, added_by_user_id, last_updated_by_user_id
) VALUES (
    ?, ?, ?
)
RETURNING id, gd_res_path, added_by_user_id, added, last_updated_by_user_id, last_updated, "foreign"
`

type CreateLevelParams struct {
	GdResPath           string
	AddedByUserID       int64
	LastUpdatedByUserID int64
}

func (q *Queries) CreateLevel(ctx context.Context, arg CreateLevelParams) (Level, error) {
	row := q.db.QueryRowContext(ctx, createLevel, arg.GdResPath, arg.AddedByUserID, arg.LastUpdatedByUserID)
	var i Level
	err := row.Scan(
		&i.ID,
		&i.GdResPath,
		&i.AddedByUserID,
		&i.Added,
		&i.LastUpdatedByUserID,
		&i.LastUpdated,
		&i.Foreign,
	)
	return i, err
}

const createLevelCollisionPoint = `-- name: CreateLevelCollisionPoint :one
INSERT INTO levels_collision_points (
    level_id, x, y
) VALUES (
    ?, ?, ?
)
RETURNING id, level_id, x, y
`

type CreateLevelCollisionPointParams struct {
	LevelID int64
	X       int64
	Y       int64
}

func (q *Queries) CreateLevelCollisionPoint(ctx context.Context, arg CreateLevelCollisionPointParams) (LevelsCollisionPoint, error) {
	row := q.db.QueryRowContext(ctx, createLevelCollisionPoint, arg.LevelID, arg.X, arg.Y)
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
    level_id, destination_level_id, destination_x, destination_y, x, y
) VALUES (
    ?, ?, ?, ?, ?, ?
)
RETURNING id, level_id, destination_level_id, destination_x, destination_y, x, y
`

type CreateLevelDoorParams struct {
	LevelID            int64
	DestinationLevelID int64
	DestinationX       int64
	DestinationY       int64
	X                  int64
	Y                  int64
}

func (q *Queries) CreateLevelDoor(ctx context.Context, arg CreateLevelDoorParams) (LevelsDoor, error) {
	row := q.db.QueryRowContext(ctx, createLevelDoor,
		arg.LevelID,
		arg.DestinationLevelID,
		arg.DestinationX,
		arg.DestinationY,
		arg.X,
		arg.Y,
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
	)
	return i, err
}

const createLevelGroundItem = `-- name: CreateLevelGroundItem :one
INSERT INTO levels_ground_items (
    level_id, item_id, x, y, respawn_seconds
) VALUES (
    ?, ?, ?, ?, ?
)
RETURNING id, level_id, item_id, x, y, respawn_seconds, "foreign"
`

type CreateLevelGroundItemParams struct {
	LevelID        int64
	ItemID         int64
	X              int64
	Y              int64
	RespawnSeconds int64
}

func (q *Queries) CreateLevelGroundItem(ctx context.Context, arg CreateLevelGroundItemParams) (LevelsGroundItem, error) {
	row := q.db.QueryRowContext(ctx, createLevelGroundItem,
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
		&i.Foreign,
	)
	return i, err
}

const createLevelShrub = `-- name: CreateLevelShrub :one
INSERT INTO levels_shrubs (
    level_id, strength, x, y
) VALUES (
    ?, ?, ?, ?
)
RETURNING id, level_id, strength, x, y
`

type CreateLevelShrubParams struct {
	LevelID  int64
	Strength int64
	X        int64
	Y        int64
}

func (q *Queries) CreateLevelShrub(ctx context.Context, arg CreateLevelShrubParams) (LevelsShrub, error) {
	row := q.db.QueryRowContext(ctx, createLevelShrub,
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

const createToolPropertiesIfNotExists = `-- name: CreateToolPropertiesIfNotExists :one
INSERT INTO tool_properties (
    strength, level_required, harvests
) VALUES (
    ?, ?, ?
)
ON CONFLICT (strength, level_required, harvests) DO NOTHING
RETURNING id, strength, level_required, harvests
`

type CreateToolPropertiesIfNotExistsParams struct {
	Strength      int64
	LevelRequired int64
	Harvests      int64
}

func (q *Queries) CreateToolPropertiesIfNotExists(ctx context.Context, arg CreateToolPropertiesIfNotExistsParams) (ToolProperty, error) {
	row := q.db.QueryRowContext(ctx, createToolPropertiesIfNotExists, arg.Strength, arg.LevelRequired, arg.Harvests)
	var i ToolProperty
	err := row.Scan(
		&i.ID,
		&i.Strength,
		&i.LevelRequired,
		&i.Harvests,
	)
	return i, err
}

const createUser = `-- name: CreateUser :one
INSERT INTO users (
    username, password_hash
) VALUES (
    ?, ?
)
RETURNING id, username, password_hash
`

type CreateUserParams struct {
	Username     string
	PasswordHash string
}

func (q *Queries) CreateUser(ctx context.Context, arg CreateUserParams) (User, error) {
	row := q.db.QueryRowContext(ctx, createUser, arg.Username, arg.PasswordHash)
	var i User
	err := row.Scan(&i.ID, &i.Username, &i.PasswordHash)
	return i, err
}

const createUserIfNotExists = `-- name: CreateUserIfNotExists :one
INSERT INTO users (
    username, password_hash
) VALUES (
    ?, ?
)
ON CONFLICT (username) DO NOTHING
RETURNING id, username, password_hash
`

type CreateUserIfNotExistsParams struct {
	Username     string
	PasswordHash string
}

func (q *Queries) CreateUserIfNotExists(ctx context.Context, arg CreateUserIfNotExistsParams) (User, error) {
	row := q.db.QueryRowContext(ctx, createUserIfNotExists, arg.Username, arg.PasswordHash)
	var i User
	err := row.Scan(&i.ID, &i.Username, &i.PasswordHash)
	return i, err
}

const deleteLevelCollisionPointsByLevelId = `-- name: DeleteLevelCollisionPointsByLevelId :exec
DELETE FROM levels_collision_points
WHERE level_id = ?
`

func (q *Queries) DeleteLevelCollisionPointsByLevelId(ctx context.Context, levelID int64) error {
	_, err := q.db.ExecContext(ctx, deleteLevelCollisionPointsByLevelId, levelID)
	return err
}

const deleteLevelDoorsByLevelId = `-- name: DeleteLevelDoorsByLevelId :exec
DELETE FROM levels_doors
WHERE level_id = ?
`

func (q *Queries) DeleteLevelDoorsByLevelId(ctx context.Context, levelID int64) error {
	_, err := q.db.ExecContext(ctx, deleteLevelDoorsByLevelId, levelID)
	return err
}

const deleteLevelGroundItem = `-- name: DeleteLevelGroundItem :exec
DELETE FROM levels_ground_items
WHERE id IN (
    SELECT lgi.id FROM levels_ground_items lgi
    WHERE lgi.level_id = ?
    AND lgi.item_id = ?
    AND lgi.x = ?
    AND lgi.y = ?
    LIMIT 1
)
`

type DeleteLevelGroundItemParams struct {
	LevelID int64
	ItemID  int64
	X       int64
	Y       int64
}

func (q *Queries) DeleteLevelGroundItem(ctx context.Context, arg DeleteLevelGroundItemParams) error {
	_, err := q.db.ExecContext(ctx, deleteLevelGroundItem,
		arg.LevelID,
		arg.ItemID,
		arg.X,
		arg.Y,
	)
	return err
}

const deleteLevelGroundItemsByLevelId = `-- name: DeleteLevelGroundItemsByLevelId :exec
DELETE FROM levels_ground_items
WHERE level_id = ?
`

func (q *Queries) DeleteLevelGroundItemsByLevelId(ctx context.Context, levelID int64) error {
	_, err := q.db.ExecContext(ctx, deleteLevelGroundItemsByLevelId, levelID)
	return err
}

const deleteLevelShrub = `-- name: DeleteLevelShrub :exec
DELETE FROM levels_shrubs
WHERE id IN (
    SELECT ls.id FROM levels_shrubs ls
    WHERE ls.level_id = ?
    AND ls.x = ?
    AND ls.y = ?
    LIMIT 1
)
`

type DeleteLevelShrubParams struct {
	LevelID int64
	X       int64
	Y       int64
}

func (q *Queries) DeleteLevelShrub(ctx context.Context, arg DeleteLevelShrubParams) error {
	_, err := q.db.ExecContext(ctx, deleteLevelShrub, arg.LevelID, arg.X, arg.Y)
	return err
}

const deleteLevelShrubsByLevelId = `-- name: DeleteLevelShrubsByLevelId :exec
DELETE FROM levels_shrubs
WHERE level_id = ?
`

func (q *Queries) DeleteLevelShrubsByLevelId(ctx context.Context, levelID int64) error {
	_, err := q.db.ExecContext(ctx, deleteLevelShrubsByLevelId, levelID)
	return err
}

const deleteLevelTscnDataByLevelId = `-- name: DeleteLevelTscnDataByLevelId :exec
DELETE FROM levels_tscn_data
WHERE level_id = ?
`

func (q *Queries) DeleteLevelTscnDataByLevelId(ctx context.Context, levelID int64) error {
	_, err := q.db.ExecContext(ctx, deleteLevelTscnDataByLevelId, levelID)
	return err
}

const getActorByUserId = `-- name: GetActorByUserId :one
SELECT id, user_id, name, level_id, x, y FROM actors
WHERE user_id = ? LIMIT 1
`

func (q *Queries) GetActorByUserId(ctx context.Context, userID int64) (Actor, error) {
	row := q.db.QueryRowContext(ctx, getActorByUserId, userID)
	var i Actor
	err := row.Scan(
		&i.ID,
		&i.UserID,
		&i.Name,
		&i.LevelID,
		&i.X,
		&i.Y,
	)
	return i, err
}

const getActorInventoryItems = `-- name: GetActorInventoryItems :many
SELECT 
    i.id as item_id, 
    i.name, 
    i.description,
    i.sprite_region_x, 
    i.sprite_region_y, 
    i.tool_properties_id,
    ai.quantity 
FROM items i
JOIN actors_inventory ai ON i.id = ai.item_id
WHERE ai.actor_id = ?
`

type GetActorInventoryItemsRow struct {
	ItemID           int64
	Name             string
	Description      string
	SpriteRegionX    int64
	SpriteRegionY    int64
	ToolPropertiesID sql.NullInt64
	Quantity         int64
}

func (q *Queries) GetActorInventoryItems(ctx context.Context, actorID int64) ([]GetActorInventoryItemsRow, error) {
	rows, err := q.db.QueryContext(ctx, getActorInventoryItems, actorID)
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
			&i.SpriteRegionX,
			&i.SpriteRegionY,
			&i.ToolPropertiesID,
			&i.Quantity,
		); err != nil {
			return nil, err
		}
		items = append(items, i)
	}
	if err := rows.Close(); err != nil {
		return nil, err
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return items, nil
}

const getAdminByUserId = `-- name: GetAdminByUserId :one
SELECT id, user_id FROM admins
WHERE user_id = ? LIMIT 1
`

func (q *Queries) GetAdminByUserId(ctx context.Context, userID int64) (Admin, error) {
	row := q.db.QueryRowContext(ctx, getAdminByUserId, userID)
	var i Admin
	err := row.Scan(&i.ID, &i.UserID)
	return i, err
}

const getItem = `-- name: GetItem :one
SELECT id, name, description, sprite_region_x, sprite_region_y, tool_properties_id FROM items
WHERE name = ? AND description = ? AND sprite_region_x = ? AND sprite_region_y = ?
LIMIT 1
`

type GetItemParams struct {
	Name          string
	Description   string
	SpriteRegionX int64
	SpriteRegionY int64
}

func (q *Queries) GetItem(ctx context.Context, arg GetItemParams) (Item, error) {
	row := q.db.QueryRowContext(ctx, getItem,
		arg.Name,
		arg.Description,
		arg.SpriteRegionX,
		arg.SpriteRegionY,
	)
	var i Item
	err := row.Scan(
		&i.ID,
		&i.Name,
		&i.Description,
		&i.SpriteRegionX,
		&i.SpriteRegionY,
		&i.ToolPropertiesID,
	)
	return i, err
}

const getItemById = `-- name: GetItemById :one
SELECT id, name, description, sprite_region_x, sprite_region_y, tool_properties_id FROM items
WHERE id = ? LIMIT 1
`

func (q *Queries) GetItemById(ctx context.Context, id int64) (Item, error) {
	row := q.db.QueryRowContext(ctx, getItemById, id)
	var i Item
	err := row.Scan(
		&i.ID,
		&i.Name,
		&i.Description,
		&i.SpriteRegionX,
		&i.SpriteRegionY,
		&i.ToolPropertiesID,
	)
	return i, err
}

const getLevelByGdResPath = `-- name: GetLevelByGdResPath :one
SELECT id, gd_res_path, added_by_user_id, added, last_updated_by_user_id, last_updated, "foreign" FROM levels
WHERE gd_res_path = ? LIMIT 1
`

func (q *Queries) GetLevelByGdResPath(ctx context.Context, gdResPath string) (Level, error) {
	row := q.db.QueryRowContext(ctx, getLevelByGdResPath, gdResPath)
	var i Level
	err := row.Scan(
		&i.ID,
		&i.GdResPath,
		&i.AddedByUserID,
		&i.Added,
		&i.LastUpdatedByUserID,
		&i.LastUpdated,
		&i.Foreign,
	)
	return i, err
}

const getLevelById = `-- name: GetLevelById :one
SELECT id, gd_res_path, added_by_user_id, added, last_updated_by_user_id, last_updated, "foreign" FROM levels
WHERE id = ? LIMIT 1
`

func (q *Queries) GetLevelById(ctx context.Context, id int64) (Level, error) {
	row := q.db.QueryRowContext(ctx, getLevelById, id)
	var i Level
	err := row.Scan(
		&i.ID,
		&i.GdResPath,
		&i.AddedByUserID,
		&i.Added,
		&i.LastUpdatedByUserID,
		&i.LastUpdated,
		&i.Foreign,
	)
	return i, err
}

const getLevelCollisionPointsByLevelId = `-- name: GetLevelCollisionPointsByLevelId :many
SELECT id, level_id, x, y FROM levels_collision_points
WHERE level_id = ?
`

func (q *Queries) GetLevelCollisionPointsByLevelId(ctx context.Context, levelID int64) ([]LevelsCollisionPoint, error) {
	rows, err := q.db.QueryContext(ctx, getLevelCollisionPointsByLevelId, levelID)
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
	if err := rows.Close(); err != nil {
		return nil, err
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return items, nil
}

const getLevelDoorsByLevelId = `-- name: GetLevelDoorsByLevelId :many
SELECT id, level_id, destination_level_id, destination_x, destination_y, x, y FROM levels_doors
WHERE level_id = ?
`

func (q *Queries) GetLevelDoorsByLevelId(ctx context.Context, levelID int64) ([]LevelsDoor, error) {
	rows, err := q.db.QueryContext(ctx, getLevelDoorsByLevelId, levelID)
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
		); err != nil {
			return nil, err
		}
		items = append(items, i)
	}
	if err := rows.Close(); err != nil {
		return nil, err
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return items, nil
}

const getLevelGroundItemsByLevelId = `-- name: GetLevelGroundItemsByLevelId :many
SELECT id, level_id, item_id, x, y, respawn_seconds, "foreign" FROM levels_ground_items
WHERE level_id = ?
`

func (q *Queries) GetLevelGroundItemsByLevelId(ctx context.Context, levelID int64) ([]LevelsGroundItem, error) {
	rows, err := q.db.QueryContext(ctx, getLevelGroundItemsByLevelId, levelID)
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
			&i.Foreign,
		); err != nil {
			return nil, err
		}
		items = append(items, i)
	}
	if err := rows.Close(); err != nil {
		return nil, err
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return items, nil
}

const getLevelIds = `-- name: GetLevelIds :many
SELECT id FROM levels
`

func (q *Queries) GetLevelIds(ctx context.Context) ([]int64, error) {
	rows, err := q.db.QueryContext(ctx, getLevelIds)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var items []int64
	for rows.Next() {
		var id int64
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		items = append(items, id)
	}
	if err := rows.Close(); err != nil {
		return nil, err
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return items, nil
}

const getLevelShrubsByLevelId = `-- name: GetLevelShrubsByLevelId :many
SELECT id, level_id, strength, x, y FROM levels_shrubs
WHERE level_id = ?
`

func (q *Queries) GetLevelShrubsByLevelId(ctx context.Context, levelID int64) ([]LevelsShrub, error) {
	rows, err := q.db.QueryContext(ctx, getLevelShrubsByLevelId, levelID)
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
	if err := rows.Close(); err != nil {
		return nil, err
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return items, nil
}

const getLevelTscnDataByLevelId = `-- name: GetLevelTscnDataByLevelId :one
SELECT level_id, tscn_data FROM levels_tscn_data
WHERE level_id = ? LIMIT 1
`

func (q *Queries) GetLevelTscnDataByLevelId(ctx context.Context, levelID int64) (LevelsTscnDatum, error) {
	row := q.db.QueryRowContext(ctx, getLevelTscnDataByLevelId, levelID)
	var i LevelsTscnDatum
	err := row.Scan(&i.LevelID, &i.TscnData)
	return i, err
}

const getToolProperties = `-- name: GetToolProperties :one
SELECT id, strength, level_required, harvests FROM tool_properties
WHERE strength = ? AND level_required = ? AND harvests = ?
LIMIT 1
`

type GetToolPropertiesParams struct {
	Strength      int64
	LevelRequired int64
	Harvests      int64
}

func (q *Queries) GetToolProperties(ctx context.Context, arg GetToolPropertiesParams) (ToolProperty, error) {
	row := q.db.QueryRowContext(ctx, getToolProperties, arg.Strength, arg.LevelRequired, arg.Harvests)
	var i ToolProperty
	err := row.Scan(
		&i.ID,
		&i.Strength,
		&i.LevelRequired,
		&i.Harvests,
	)
	return i, err
}

const getToolPropertiesById = `-- name: GetToolPropertiesById :one
SELECT id, strength, level_required, harvests FROM tool_properties
WHERE id = ? LIMIT 1
`

func (q *Queries) GetToolPropertiesById(ctx context.Context, id int64) (ToolProperty, error) {
	row := q.db.QueryRowContext(ctx, getToolPropertiesById, id)
	var i ToolProperty
	err := row.Scan(
		&i.ID,
		&i.Strength,
		&i.LevelRequired,
		&i.Harvests,
	)
	return i, err
}

const getUserByUsername = `-- name: GetUserByUsername :one
SELECT id, username, password_hash FROM users
WHERE username = ? LIMIT 1
`

func (q *Queries) GetUserByUsername(ctx context.Context, username string) (User, error) {
	row := q.db.QueryRowContext(ctx, getUserByUsername, username)
	var i User
	err := row.Scan(&i.ID, &i.Username, &i.PasswordHash)
	return i, err
}

const getUserIdByActorId = `-- name: GetUserIdByActorId :one
SELECT user_id FROM actors
WHERE id = ? LIMIT 1
`

func (q *Queries) GetUserIdByActorId(ctx context.Context, id int64) (int64, error) {
	row := q.db.QueryRowContext(ctx, getUserIdByActorId, id)
	var user_id int64
	err := row.Scan(&user_id)
	return user_id, err
}

const isActorAdmin = `-- name: IsActorAdmin :one
SELECT 1 FROM users u
JOIN admins ad ON u.id = ad.user_id
JOIN actors ac ON u.id = ac.user_id
WHERE ac.id = ? LIMIT 1
`

func (q *Queries) IsActorAdmin(ctx context.Context, id int64) (int64, error) {
	row := q.db.QueryRowContext(ctx, isActorAdmin, id)
	var column_1 int64
	err := row.Scan(&column_1)
	return column_1, err
}

const removeActorInventoryItem = `-- name: RemoveActorInventoryItem :exec
DELETE FROM actors_inventory
WHERE actor_id = ?
AND item_id = ?
`

type RemoveActorInventoryItemParams struct {
	ActorID int64
	ItemID  int64
}

func (q *Queries) RemoveActorInventoryItem(ctx context.Context, arg RemoveActorInventoryItemParams) error {
	_, err := q.db.ExecContext(ctx, removeActorInventoryItem, arg.ActorID, arg.ItemID)
	return err
}

const updateActorLevel = `-- name: UpdateActorLevel :exec
UPDATE actors
SET level_id = ?
WHERE id = ?
`

type UpdateActorLevelParams struct {
	LevelID int64
	ID      int64
}

func (q *Queries) UpdateActorLevel(ctx context.Context, arg UpdateActorLevelParams) error {
	_, err := q.db.ExecContext(ctx, updateActorLevel, arg.LevelID, arg.ID)
	return err
}

const updateActorLocation = `-- name: UpdateActorLocation :exec
UPDATE actors
SET level_id = ?, x = ?, y = ?
WHERE id = ?
`

type UpdateActorLocationParams struct {
	LevelID int64
	X       int64
	Y       int64
	ID      int64
}

func (q *Queries) UpdateActorLocation(ctx context.Context, arg UpdateActorLocationParams) error {
	_, err := q.db.ExecContext(ctx, updateActorLocation,
		arg.LevelID,
		arg.X,
		arg.Y,
		arg.ID,
	)
	return err
}

const updateLevelLastUpdated = `-- name: UpdateLevelLastUpdated :exec
UPDATE levels
SET last_updated = CURRENT_TIMESTAMP
AND last_updated_by_user_id = ?
WHERE id = ?
`

type UpdateLevelLastUpdatedParams struct {
	LastUpdatedByUserID int64
	ID                  int64
}

func (q *Queries) UpdateLevelLastUpdated(ctx context.Context, arg UpdateLevelLastUpdatedParams) error {
	_, err := q.db.ExecContext(ctx, updateLevelLastUpdated, arg.LastUpdatedByUserID, arg.ID)
	return err
}

const upsertActorInventoryItem = `-- name: UpsertActorInventoryItem :exec
INSERT INTO actors_inventory (
    actor_id, item_id, quantity
) VALUES (
    ?, ?, ?
)
ON CONFLICT (actor_id, item_id) DO UPDATE SET quantity = EXCLUDED.quantity
`

type UpsertActorInventoryItemParams struct {
	ActorID  int64
	ItemID   int64
	Quantity int64
}

func (q *Queries) UpsertActorInventoryItem(ctx context.Context, arg UpsertActorInventoryItemParams) error {
	_, err := q.db.ExecContext(ctx, upsertActorInventoryItem, arg.ActorID, arg.ItemID, arg.Quantity)
	return err
}

const upsertLevelTscnData = `-- name: UpsertLevelTscnData :one
INSERT INTO levels_tscn_data (
    level_id, tscn_data
) VALUES (
    ?, ?
)
ON CONFLICT (level_id) DO UPDATE SET tscn_data = EXCLUDED.tscn_data
RETURNING level_id, tscn_data
`

type UpsertLevelTscnDataParams struct {
	LevelID  int64
	TscnData []byte
}

func (q *Queries) UpsertLevelTscnData(ctx context.Context, arg UpsertLevelTscnDataParams) (LevelsTscnDatum, error) {
	row := q.db.QueryRowContext(ctx, upsertLevelTscnData, arg.LevelID, arg.TscnData)
	var i LevelsTscnDatum
	err := row.Scan(&i.LevelID, &i.TscnData)
	return i, err
}
