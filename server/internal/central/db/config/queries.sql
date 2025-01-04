-- name: GetUserByUsername :one
SELECT * FROM users
WHERE username = $1
ORDER BY id DESC
LIMIT 1;

-- name: CreateUser :one
INSERT INTO users (
    username, password_hash
) VALUES (
    $1, $2
)
RETURNING *;

-- name: CreateActor :one
INSERT INTO actors (
    user_id, name, level_id, x, y
) VALUES (
    $1, $2, $3, $4, $5
)
RETURNING *;

-- name: GetActorByUserId :one
SELECT * FROM actors
WHERE user_id = $1
ORDER BY id DESC
LIMIT 1;

-- name: UpdateActorLocation :exec
UPDATE actors
SET level_id = $2, x = $3, y = $4
WHERE id = $1;

-- name: UpdateActorLevel :exec
UPDATE actors
SET level_id = $2
WHERE id = $1;

-- name: CreateUserIfNotExists :one
INSERT INTO users (
    username, password_hash
) VALUES (
    $1, $2
)
ON CONFLICT (username) DO NOTHING
RETURNING *;

-- name: CreateAdminIfNotExists :one
INSERT INTO admins (
    user_id
) VALUES (
    $1
)
ON CONFLICT (user_id) DO NOTHING
RETURNING *;

-- name: CreateActorIfNotExists :one
INSERT INTO actors (
    user_id, name, x, y
) VALUES (
    $1, $2, $3, $4
)
ON CONFLICT (user_id) DO NOTHING
RETURNING *;

-- name: GetAdminByUserId :one
SELECT * FROM admins
WHERE user_id = $1 LIMIT 1;

-- name: CreateLevel :one
INSERT INTO levels (
    gd_res_path, added_by_user_id, last_updated_by_user_id
) VALUES (
    $1, $2, $3
)
RETURNING *;

-- name: UpsertLevelTscnData :one
INSERT INTO levels_tscn_data (
    level_id, tscn_data
) VALUES (
    $1, $2
)
ON CONFLICT (level_id) DO UPDATE SET tscn_data = EXCLUDED.tscn_data
RETURNING *;

-- name: CreateLevelCollisionPoint :one
INSERT INTO levels_collision_points (
    level_id, x, y
) VALUES (
    $1, $2, $3
)
RETURNING *;

-- name: GetLevelById :one
SELECT * FROM levels
WHERE id = $1 LIMIT 1;

-- name: GetLevelTscnDataByLevelId :one
SELECT * FROM levels_tscn_data
WHERE level_id = $1 LIMIT 1;

-- name: GetLevelCollisionPointsByLevelId :many
SELECT * FROM levels_collision_points
WHERE level_id = $1;

-- name: GetLevelByGdResPath :one
SELECT * FROM levels
WHERE gd_res_path = $1 LIMIT 1;

-- name: DeleteLevelTscnDataByLevelId :exec
DELETE FROM levels_tscn_data
WHERE level_id = $1;

-- name: DeleteLevelCollisionPointsByLevelId :exec
DELETE FROM levels_collision_points
WHERE level_id = $1;

-- name: UpdateLevelLastUpdated :exec
UPDATE levels
SET last_updated = CURRENT_TIMESTAMP
AND last_updated_by_user_id = $2
WHERE id = $1;

-- name: GetLevelIds :many
SELECT id FROM levels;

-- name: CreateLevelShrub :one
INSERT INTO levels_shrubs (
    level_id, strength, x, y
) VALUES (
    $1, $2, $3, $4
)
RETURNING *;

-- name: CreateLevelOre :one
INSERT INTO levels_ores (
    level_id, strength, x, y
) VALUES (
    $1, $2, $3, $4
)
RETURNING *;

-- name: DeleteLevelShrubsByLevelId :exec
DELETE FROM levels_shrubs
WHERE level_id = $1;

-- name: DeleteLevelOresByLevelId :exec
DELETE FROM levels_ores
WHERE level_id = $1;

-- name: GetLevelShrubsByLevelId :many
SELECT * FROM levels_shrubs
WHERE level_id = $1;

-- name: GetLevelOresByLevelId :many
SELECT * FROM levels_ores
WHERE level_id = $1;

-- name: GetLevelShrub :one
SELECT * FROM levels_shrubs
WHERE level_id = $1;

-- name: GetLevelOre :one
SELECT * FROM levels_ores
WHERE level_id = $1;

-- name: CreateLevelDoor :one
INSERT INTO levels_doors (
    level_id, destination_level_id, destination_x, destination_y, x, y
) VALUES (
    $1, $2, $3, $4, $5, $6
)
RETURNING *;

-- name: DeleteLevelDoorsByLevelId :exec
DELETE FROM levels_doors
WHERE level_id = $1;

-- name: GetLevelDoorsByLevelId :many
SELECT * FROM levels_doors
WHERE level_id = $1;

-- name: CreateToolPropertiesIfNotExists :one
INSERT INTO tool_properties (
    strength, level_required, harvests
) VALUES (
    $1, $2, $3
)
ON CONFLICT (strength, level_required, harvests) DO NOTHING
RETURNING *;

-- name: GetToolProperties :one
SELECT * FROM tool_properties
WHERE strength = $1 AND level_required = $2 AND harvests = $3
LIMIT 1;

-- name: GetToolPropertiesById :one
SELECT * FROM tool_properties
WHERE id = $1 LIMIT 1;

-- name: CreateItemIfNotExists :one
INSERT INTO items (
    name, description, value, sprite_region_x, sprite_region_y, tool_properties_id
) VALUES (
    $1, $2, $3, $4, $5, $6
)
ON CONFLICT (name, description, value, sprite_region_x, sprite_region_y) DO NOTHING
RETURNING *;

-- name: GetItem :one
SELECT * FROM items
WHERE name = $1 AND description = $2 AND value = $3 AND sprite_region_x = $4 AND sprite_region_y = $5
LIMIT 1;

-- name: GetItemById :one
SELECT * FROM items
WHERE id = $1 LIMIT 1;

-- name: CreateLevelGroundItem :one
INSERT INTO levels_ground_items (
    level_id, item_id, x, y, respawn_seconds
) VALUES (
    $1, $2, $3, $4, $5
)
RETURNING *;

-- name: DeleteLevelGroundItemsByLevelId :exec
DELETE FROM levels_ground_items
WHERE level_id = $1;

-- name: GetLevelGroundItemsByLevelId :many
SELECT * FROM levels_ground_items
WHERE level_id = $1;

-- name: IsActorAdmin :one
SELECT 1 FROM users u
JOIN admins ad ON u.id = ad.user_id
JOIN actors ac ON u.id = ac.user_id
WHERE ac.id = $1 LIMIT 1;

-- name: GetUserIdByActorId :one
SELECT user_id FROM actors
WHERE id = $1 LIMIT 1;

-- name: DeleteLevelGroundItem :exec
DELETE FROM levels_ground_items
WHERE id IN (
    SELECT lgi.id FROM levels_ground_items lgi
    WHERE lgi.level_id = $1
    AND lgi.item_id = $2
    AND lgi.x = $3
    AND lgi.y = $4
    LIMIT 1
);

-- name: GetActorInventoryItems :many
SELECT 
    i.id as item_id, 
    i.name, 
    i.description,
    i.value,
    i.sprite_region_x, 
    i.sprite_region_y, 
    i.tool_properties_id,
    ai.quantity 
FROM items i
JOIN actors_inventory ai ON i.id = ai.item_id
WHERE ai.actor_id = $1;

-- name: AddActorInventoryItem :exec
INSERT INTO actors_inventory (
    actor_id, item_id, quantity
) VALUES (
    $1, $2, $3
)
ON CONFLICT(actor_id, item_id) DO UPDATE
SET quantity = actors_inventory.quantity + excluded.quantity;

-- name: RemoveActorInventoryItem :exec
DELETE FROM actors_inventory
WHERE actor_id = $1
AND item_id = $2;

-- name: UpsertActorInventoryItem :exec
INSERT INTO actors_inventory (
    actor_id, item_id, quantity
) VALUES (
    $1, $2, $3
)
ON CONFLICT (actor_id, item_id) DO UPDATE SET quantity = EXCLUDED.quantity;

-- name: DeleteLevelShrub :exec
DELETE FROM levels_shrubs
WHERE id IN (
    SELECT ls.id FROM levels_shrubs ls
    WHERE ls.level_id = $1
    AND ls.x = $2
    AND ls.y = $3
    LIMIT 1
);

-- name: DeleteLevelOre :exec
DELETE FROM levels_ores
WHERE id IN (
    SELECT lo.id FROM levels_ores lo
    WHERE lo.level_id = $1
    AND lo.x = $2
    AND lo.y = $3
    LIMIT 1
);

-- name: AddActorXp :exec
INSERT INTO actors_skills (
    actor_id, skill, xp
) VALUES (
    $1, $2, $3
)
ON CONFLICT (actor_id, skill) DO UPDATE SET xp = actors_skills.xp + excluded.xp;

-- name: GetActorSkillsXp :many
SELECT * FROM actors_skills
WHERE actor_id = $1;

-- name: GetActorSkillXp :one
SELECT ISNULL(xp, 0) FROM actors_skills
WHERE actor_id = $1
AND skill = $2;