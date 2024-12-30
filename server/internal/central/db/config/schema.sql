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

CREATE TABLE IF NOT EXISTS tool_properties (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    strength INTEGER NOT NULL,
    level_required INTEGER NOT NULL,
    harvests INTEGER NOT NULL, -- 0 = NONE, 1 = SHRUB, ...
    CONSTRAINT unique_tool_properties_combination UNIQUE (strength, level_required, harvests)
);

CREATE TABLE IF NOT EXISTS items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    sprite_region_x INTEGER NOT NULL,
    sprite_region_y INTEGER NOT NULL,
    tool_properties_id INTEGER,
    FOREIGN KEY (tool_properties_id) REFERENCES tool_properties(id) ON DELETE SET NULL, -- set tool_properties_id to NULL when tool_properties with id tool_properties_id is deleted
    CONSTRAINT unique_item_combination UNIQUE (name, description, sprite_region_x, sprite_region_y)
);

CREATE TABLE IF NOT EXISTS levels_ground_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    level_id INTEGER NOT NULL,
    item_id INTEGER NOT NULL,
    x INTEGER NOT NULL,
    y INTEGER NOT NULL,
    respawn_seconds INTEGER NOT NULL,
    FOREIGN KEY (level_id) REFERENCES levels(id) ON DELETE CASCADE -- delete from levels_ground_items when level with id level_id is deleted
    FOREIGN KEY (item_id) REFERENCES items(id) ON DELETE CASCADE -- delete from levels_ground_items when item with id item_id is deleted
);

CREATE TABLE IF NOT EXISTS actors_inventory (
    actor_id INTEGER NOT NULL,
    item_id INTEGER NOT NULL,
    quantity INTEGER NOT NULL,
    PRIMARY KEY (actor_id, item_id),
    FOREIGN KEY (actor_id) REFERENCES actors(id) ON DELETE CASCADE,
    FOREIGN KEY (item_id) REFERENCES items(id) ON DELETE CASCADE
);