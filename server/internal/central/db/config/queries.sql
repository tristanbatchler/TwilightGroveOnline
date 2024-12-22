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
