CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS admins (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL UNIQUE,
    FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE TABLE IF NOT EXISTS actors (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL UNIQUE,
    name TEXT NOT NULL,
    level_id INTEGER NOT NULL,
    x INTEGER NOT NULL,
    y INTEGER NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(id),
    FOREIGN KEY (level_id) REFERENCES levels(id)
);

CREATE TABLE IF NOT EXISTS levels (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    gd_res_path TEXT NOT NULL UNIQUE,
    added_by_user_id INTEGER NOT NULL,
    added TEXT DEFAULT CURRENT_TIMESTAMP,
    last_updated_by_user_id INTEGER NOT NULL,
    last_updated TEXT DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (added_by_user_id) REFERENCES users(id)
    FOREIGN KEY (last_updated_by_user_id) REFERENCES users(id)
);

CREATE TABLE IF NOT EXISTS levels_tscn_data (
    level_id INTEGER NOT NULL UNIQUE,
    tscn_data BLOB NOT NULL,
    PRIMARY KEY (level_id),
    FOREIGN KEY (level_id) REFERENCES levels(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS levels_collision_points (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    level_id INTEGER NOT NULL,
    x INTEGER NOT NULL,
    y INTEGER NOT NULL,
    FOREIGN KEY (level_id) REFERENCES levels(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS levels_shrubs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    level_id INTEGER NOT NULL,
    strength INTEGER NOT NULL,
    x INTEGER NOT NULL,
    y INTEGER NOT NULL,
    FOREIGN KEY (level_id) REFERENCES levels(id) ON DELETE CASCADE 
);

CREATE TABLE IF NOT EXISTS levels_doors (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    level_id INTEGER NOT NULL,
    destination_level_id INTEGER NOT NULL,
    destination_x INTEGER NOT NULL,
    destination_y INTEGER NOT NULL,
    x INTEGER NOT NULL,
    y INTEGER NOT NULL,
    FOREIGN KEY (level_id) REFERENCES levels(id) ON DELETE CASCADE, -- delete from levels_doors when level with id level_id is deleted
    FOREIGN KEY (destination_level_id) REFERENCES levels(id) ON DELETE RESTRICT -- do not allow deletion of levels that are destinations
);

CREATE TABLE IF NOT EXISTS levels_ground_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    level_id INTEGER NOT NULL,
    name TEXT NOT NULL,
    x INTEGER NOT NULL,
    y INTEGER NOT NULL,
    FOREIGN KEY (level_id) REFERENCES levels(id) ON DELETE CASCADE 
);