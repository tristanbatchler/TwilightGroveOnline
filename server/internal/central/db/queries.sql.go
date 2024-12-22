// Code generated by sqlc. DO NOT EDIT.
// versions:
//   sqlc v1.27.0
// source: queries.sql

package db

import (
	"context"
)

const createActor = `-- name: CreateActor :one
INSERT INTO actors (
    user_id, name, x, y
) VALUES (
    ?, ?, ?, ?
)
RETURNING id, user_id, name, x, y
`

type CreateActorParams struct {
	UserID int64
	Name   string
	X      int64
	Y      int64
}

func (q *Queries) CreateActor(ctx context.Context, arg CreateActorParams) (Actor, error) {
	row := q.db.QueryRowContext(ctx, createActor,
		arg.UserID,
		arg.Name,
		arg.X,
		arg.Y,
	)
	var i Actor
	err := row.Scan(
		&i.ID,
		&i.UserID,
		&i.Name,
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

const getActorByUserId = `-- name: GetActorByUserId :one
SELECT id, user_id, name, x, y FROM actors
WHERE user_id = ? LIMIT 1
`

func (q *Queries) GetActorByUserId(ctx context.Context, userID int64) (Actor, error) {
	row := q.db.QueryRowContext(ctx, getActorByUserId, userID)
	var i Actor
	err := row.Scan(
		&i.ID,
		&i.UserID,
		&i.Name,
		&i.X,
		&i.Y,
	)
	return i, err
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

const updateActorPosition = `-- name: UpdateActorPosition :exec
UPDATE actors
SET x = ?, y = ?
WHERE id = ?
`

type UpdateActorPositionParams struct {
	X  int64
	Y  int64
	ID int64
}

func (q *Queries) UpdateActorPosition(ctx context.Context, arg UpdateActorPositionParams) error {
	_, err := q.db.ExecContext(ctx, updateActorPosition, arg.X, arg.Y, arg.ID)
	return err
}
