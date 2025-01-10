CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS admins (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL UNIQUE REFERENCES users(id)
);

CREATE TABLE IF NOT EXISTS levels (
    id SERIAL PRIMARY KEY,
    gd_res_path TEXT NOT NULL UNIQUE,
    added_by_user_id INTEGER NOT NULL REFERENCES users(id),
    added TEXT DEFAULT CURRENT_TIMESTAMP,
    last_updated_by_user_id INTEGER NOT NULL REFERENCES users(id),
    last_updated TEXT DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS actors (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL UNIQUE REFERENCES users(id),
    name TEXT NOT NULL,
    level_id INTEGER REFERENCES levels(id),
    x INTEGER NOT NULL,
    y INTEGER NOT NULL,
    sprite_region_x INTEGER NOT NULL,
    sprite_region_y INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS levels_tscn_data (
    level_id INTEGER NOT NULL UNIQUE PRIMARY KEY REFERENCES levels(id) ON DELETE CASCADE,
    tscn_data BYTEA NOT NULL
);

CREATE TABLE IF NOT EXISTS levels_collision_points (
    id SERIAL PRIMARY KEY,
    level_id INTEGER NOT NULL REFERENCES levels(id) ON DELETE CASCADE,
    x INTEGER NOT NULL,
    y INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS levels_shrubs (
    id SERIAL PRIMARY KEY,
    level_id INTEGER NOT NULL REFERENCES levels(id) ON DELETE CASCADE,
    strength INTEGER NOT NULL,
    x INTEGER NOT NULL,
    y INTEGER NOT NULL 
);

CREATE TABLE IF NOT EXISTS levels_ores (
    id SERIAL PRIMARY KEY,
    level_id INTEGER NOT NULL REFERENCES levels(id) ON DELETE CASCADE,
    strength INTEGER NOT NULL,
    x INTEGER NOT NULL,
    y INTEGER NOT NULL 
);

CREATE TABLE IF NOT EXISTS levels_doors (
    id SERIAL PRIMARY KEY,
    level_id INTEGER NOT NULL REFERENCES levels(id) ON DELETE CASCADE, -- delete from levels_doors when level with id level_id is deleted
    destination_level_id INTEGER NOT NULL REFERENCES levels(id) ON DELETE RESTRICT, -- do not allow deletion of levels that are destinations
    destination_x INTEGER NOT NULL,
    destination_y INTEGER NOT NULL,
    x INTEGER NOT NULL,
    y INTEGER NOT NULL,
    key_id INTEGER -- NULL or < 0 if no key required i.e. unlocked. Does not reference another table, just a basic identifier
);

CREATE TABLE IF NOT EXISTS tool_properties (
    id SERIAL PRIMARY KEY,
    strength INTEGER NOT NULL,
    level_required INTEGER NOT NULL,
    harvests INTEGER NOT NULL, -- 0 = NONE, 1 = SHRUB, 2 = ORE
    key_id INTEGER, -- NULL or < 0 if the tool is not a key. Else, this tool can be used to unlock doors with a matching key_id
    CONSTRAINT unique_tool_properties_combination UNIQUE (strength, level_required, harvests)
);

CREATE TABLE IF NOT EXISTS items (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    value INTEGER NOT NULL,
    sprite_region_x INTEGER NOT NULL,
    sprite_region_y INTEGER NOT NULL,
    tool_properties_id INTEGER REFERENCES tool_properties(id) ON DELETE SET NULL, -- set tool_properties_id to NULL when tool_properties with id tool_properties_id is deleted
    CONSTRAINT unique_item_combination UNIQUE (name, description, value, sprite_region_x, sprite_region_y)
);

CREATE TABLE IF NOT EXISTS levels_ground_items (
    id SERIAL PRIMARY KEY,
    level_id INTEGER NOT NULL REFERENCES levels(id) ON DELETE CASCADE, -- delete from levels_ground_items when level with id level_id is deleted
    item_id INTEGER NOT NULL REFERENCES items(id) ON DELETE CASCADE, -- delete from levels_ground_items when item with id item_id is deleted
    x INTEGER NOT NULL,
    y INTEGER NOT NULL,
    respawn_seconds INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS actors_inventory (
    actor_id INTEGER NOT NULL REFERENCES actors(id) ON DELETE CASCADE,
    item_id INTEGER NOT NULL REFERENCES items(id) ON DELETE CASCADE,
    quantity INTEGER NOT NULL,
    PRIMARY KEY (actor_id, item_id)
);

CREATE TABLE IF NOT EXISTS actors_skills (
    id SERIAL PRIMARY KEY,
    actor_id INTEGER NOT NULL REFERENCES actors(id) ON DELETE CASCADE,
    skill INTEGER NOT NULL, -- 0 = WOODCUTTING, ...
    xp INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT unique_actor_skill UNIQUE (actor_id, skill)
);
