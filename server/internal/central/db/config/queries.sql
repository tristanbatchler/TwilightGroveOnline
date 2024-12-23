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
    user_id, name, x, y
) VALUES (
    ?, ?, ?, ?
)
RETURNING *;

-- name: GetActorByUserId :one
SELECT * FROM actors
WHERE user_id = ? LIMIT 1;

-- name: UpdateActorPosition :exec
UPDATE actors
SET x = ?, y = ?
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

-- name: GetAdminByUserId :one
SELECT * FROM admins
WHERE user_id = ? LIMIT 1;

-- name: CreateLevel :one
INSERT INTO levels (
    name, added_by_user_id
) VALUES (
    ?, ?
)
RETURNING *;

-- name: CreateLevelTscnData :one
INSERT INTO levels_tscn_data (
    level_id, tscn_data
) VALUES (
    ?, ?
)
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
