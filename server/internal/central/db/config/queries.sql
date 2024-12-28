-- name: GetUserByUsername :one
SELECT * FROM users
WHERE username = ? LIMIT 1;

-- name: CreateUser :one
INSERT INTO users (
    username, password_hash
) VALUES (
    ?, ?
)
RETURNING *;

-- name: CreateActor :one
INSERT INTO actors (
    user_id, name, level_id, x, y
) VALUES (
    ?, ?, ?, ?, ?
)
RETURNING *;

-- name: GetActorByUserId :one
SELECT * FROM actors
WHERE user_id = ? LIMIT 1;

-- name: UpdateActorLocation :exec
UPDATE actors
SET level_id = ?, x = ?, y = ?
WHERE id = ?;

-- name: UpdateActorLevel :exec
UPDATE actors
SET level_id = ?
WHERE id = ?;

-- name: CreateUserIfNotExists :one
INSERT INTO users (
    username, password_hash
) VALUES (
    ?, ?
)
ON CONFLICT (username) DO NOTHING
RETURNING *;

-- name: CreateAdminIfNotExists :one
INSERT INTO admins (
    user_id
) VALUES (
    ?
)
ON CONFLICT (user_id) DO NOTHING
RETURNING *;

-- name: CreateActorIfNotExists :one
INSERT INTO actors (
    user_id, name, level_id, x, y
) VALUES (
    ?, ?, ?, ?, ?
)
ON CONFLICT (user_id) DO NOTHING
RETURNING *;

-- name: GetAdminByUserId :one
SELECT * FROM admins
WHERE user_id = ? LIMIT 1;

-- name: CreateLevel :one
INSERT INTO levels (
    gd_res_path, added_by_user_id, last_updated_by_user_id
) VALUES (
    ?, ?, ?
)
RETURNING *;

-- name: UpsertLevelTscnData :one
INSERT INTO levels_tscn_data (
    level_id, tscn_data
) VALUES (
    ?, ?
)
ON CONFLICT (level_id) DO UPDATE SET tscn_data = EXCLUDED.tscn_data
RETURNING *;

-- name: CreateLevelCollisionPoint :one
INSERT INTO levels_collision_points (
    level_id, x, y
) VALUES (
    ?, ?, ?
)
RETURNING *;

-- name: GetLevelById :one
SELECT * FROM levels
WHERE id = ? LIMIT 1;

-- name: GetLevelTscnDataByLevelId :one
SELECT * FROM levels_tscn_data
WHERE level_id = ? LIMIT 1;

-- name: GetLevelCollisionPointsByLevelId :many
SELECT * FROM levels_collision_points
WHERE level_id = ?;

-- name: GetLevelByGdResPath :one
SELECT * FROM levels
WHERE gd_res_path = ? LIMIT 1;

-- name: DeleteLevelTscnDataByLevelId :exec
DELETE FROM levels_tscn_data
WHERE level_id = ?;

-- name: DeleteLevelCollisionPointsByLevelId :exec
DELETE FROM levels_collision_points
WHERE level_id = ?;

-- name: UpdateLevelLastUpdated :exec
UPDATE levels
SET last_updated = CURRENT_TIMESTAMP
AND last_updated_by_user_id = ?
WHERE id = ?;

-- name: GetLevelIds :many
SELECT id FROM levels;

-- name: CreateLevelShrub :one
INSERT INTO levels_shrubs (
    level_id, strength, x, y
) VALUES (
    ?, ?, ?, ?
)
RETURNING *;

-- name: DeleteLevelShrubsByLevelId :exec
DELETE FROM levels_shrubs
WHERE level_id = ?;

-- name: GetLevelShrubsByLevelId :many
SELECT * FROM levels_shrubs
WHERE level_id = ?;

-- name: CreateLevelDoor :one
INSERT INTO levels_doors (
    level_id, destination_level_id, destination_x, destination_y, x, y
) VALUES (
    ?, ?, ?, ?, ?, ?
)
RETURNING *;

-- name: DeleteLevelDoorsByLevelId :exec
DELETE FROM levels_doors
WHERE level_id = ?;

-- name: GetLevelDoorsByLevelId :many
SELECT * FROM levels_doors
WHERE level_id = ?;

-- name: CreateItemIfNotExists :one
INSERT INTO items (
    name, sprite_region_x, sprite_region_y
) VALUES (
    ?, ?, ?
)
ON CONFLICT (name, sprite_region_x, sprite_region_y) DO NOTHING
RETURNING *;

-- name: GetItem :one
SELECT * FROM items
WHERE name = ? AND sprite_region_x = ? AND sprite_region_y = ?
LIMIT 1;

-- name: GetItemById :one
SELECT * FROM items
WHERE id = ? LIMIT 1;

-- name: CreateLevelGroundItem :one
INSERT INTO levels_ground_items (
    level_id, item_id, x, y, respawn_seconds
) VALUES (
    ?, ?, ?, ?, ?
)
RETURNING *;

-- name: DeleteLevelGroundItemsByLevelId :exec
DELETE FROM levels_ground_items
WHERE level_id = ?;

-- name: GetLevelGroundItemsByLevelId :many
SELECT * FROM levels_ground_items
WHERE level_id = ?;

-- name: IsActorAdmin :one
SELECT 1 FROM users u
JOIN admins ad ON u.id = ad.user_id
JOIN actors ac ON u.id = ac.user_id
WHERE ac.id = ? LIMIT 1;

-- name: GetUserIdByActorId :one
SELECT user_id FROM actors
WHERE id = ? LIMIT 1;

-- name: DeleteLevelGroundItem :exec
DELETE FROM levels_ground_items
WHERE id IN (
    SELECT lgi.id FROM levels_ground_items lgi
    WHERE lgi.level_id = ?
    AND lgi.item_id = ?
    AND lgi.x = ?
    AND lgi.y = ?
    LIMIT 1
);

-- name: GetActorInventoryItems :many
SELECT 
    i.id as item_id, 
    i.name, 
    i.sprite_region_x, 
    i.sprite_region_y, 
    ai.quantity 
FROM items i
JOIN actors_inventory ai ON i.id = ai.item_id
WHERE ai.actor_id = ?;

-- name: AddActorInventoryItem :exec
INSERT INTO actors_inventory (
    actor_id, item_id, quantity
) VALUES (
    ?, ?, ?
)
ON CONFLICT(actor_id, item_id) DO UPDATE
SET quantity = actors_inventory.quantity + excluded.quantity;

-- name: RemoveActorInventoryItem :exec
DELETE FROM actors_inventory
WHERE actor_id = ?
AND item_id = ?;

-- name: UpsertActorInventoryItem :exec
INSERT INTO actors_inventory (
    actor_id, item_id, quantity
) VALUES (
    ?, ?, ?
)
ON CONFLICT (actor_id, item_id) DO UPDATE SET quantity = EXCLUDED.quantity;