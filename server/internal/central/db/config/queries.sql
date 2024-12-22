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


