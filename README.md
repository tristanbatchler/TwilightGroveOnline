# Twilight Grove Online
*A tiny MUD*

## Setup
1. Install Go and ensure `~/go/bin` is in your PATH.
1. [Download Godot Engine 4.4 dev 3](https://godotengine.org/download/archive/4.4-dev3) and copy the console binary to the `/server/` directory of this project, renaming it to `godot`.
1. [Download protoc](https://github.com/protocolbuffers/protobuf/releases/latest) and copy the binary to `~/go/bin`.
1. Run `go install google.golang.org/protobuf/cmd/protoc-gen-go@latest` to install the Go protobuf plugin.
1. Run `go install github.com/sqlc-dev/sqlc/cmd/sqlc@latest` to install `sqlc`.
1. Run `go mod download` from the `/server/` directory to download the project dependencies.
1. Obtain a TLS certificate and note the paths to the public and private keys.
    > For a development workflow, [download mkcert](https://github.com/FiloSottile/mkcert/releases/latest), install it, and run `mkcert -install` to set up a local CA. Then run `mkcert dev.your.domain` to generate a certificate and key pair. Then node the paths to the `.pem` files. Add the domain to your `/etc/hosts` file to point `dev.your.domain` to `127.0.0.1`.
1. Setup a PostgreSQL database and note the connection details.
    > For development purposes, I just spun up this docker container:
    ```yaml
    ---
    services:
    adminer:
        image: adminer
        restart: always
        ports:
          - 8003:8080
        depends_on:
          - db
    db:
        image: postgres
        restart: always
        environment:
          POSTGRES_USER: XXXXXXXXX
          POSTGRES_PASSWORD: XXXXXXXXX
        volumes:
          - pgdata:/home/t/docker/db/data
        ports:
          - 5432:5432
    volumes:
    pgdata:
    ```
1. Create a `.env` file in the `/server/` directory with the following contents:
    ```
    PG_HOST=localhost
    PG_PORT=5432
    PG_USER=XXXXXXXXX
    PG_PASSWORD=XXXXXXXXX
    PG_DATABASE=twilightgrove
    PORT=43200
    CERT_PATH=/home/t/certs/twilightgrove.tbat.me.fullchain.pem
    KEY_PATH=/home/t/certs/twilightgrove.tbat.me.privkey.pem
    DATA_PATH=./data
    CLIENT_EXPORT_PATH=../client/export/web
    ADMIN_PASSWORD=XXXXXXXXX
    ```
1. Optional: install the [vscode-proto3](https://marketplace.visualstudio.com/items?itemName=zxh404.vscode-proto3) extension for syntax highlighting and automatical go compilation on save.

1. Edit the root `Entered` node in the `res://states/entered/entered.tscn` scene in Godot to have a server URL of `wss://dev.your.domain:43200/ws`.

## TODO
- [x] Items on the ground for the level
- [x] Refactor level parsing code - ~add interface to implement `ToGameObject()`? `ToDB()`?~ 
    - Added some structs in `/internal/central/levels` to help 
        - importing to DB and memory from a packet message, and
        - importing to memory from the DB
- [x] Press G to pick up items when standing on them
- [x] Storing items in the player's inventory, both on the server and in the database
- [x] Displaying the player's inventory on the client
- [x] Dropping items from the player's inventory onto the ground
- [x] Disable camera zoom while scrolling inside inventory/chat
- [x] Disable cursor keys changing between chat and inventory
- [x] Fix nameplate positioning
- [x] Make ground items respawn after a while
- [x] Add UI scale setting
- [x] Add grab controls for mobile
- [x] Add drop controls for mobile
- [x] Audit use of int64 in game_objects.go and messages.proto
- [x] Let players cut down trees with an axe
- [x] Add an XP system and leveling up woodcutting
- [x] Add item values to the database and use them to calculate how much gold the player gets for selling items, or whether the player can afford to buy items
- [x] Add an NPC that buys wood
- [ ] Add an NPC that sells faerie dust
- [ ] Add a quest to heal a wounded soldier with faerie dust to get a key
- [ ] Add a locked door that requires a key to open, with a reward inside
- [ ] Add a special status symbol for players who have completed the quest
- [ ] Add spawn point in levels
- [x] Speed up level uploading?
- [ ] Translate to Japanese
- [x] Use StringNames for inventory script?
- [ ] Allow customizing the player's appearance
- [ ] Allow support for multiple items in LevelPointMap stacked on top of each other
- [x] Smooth camera zooming
- [ ] Pinch to zoom on mobile
- [ ] Rearrange DB schema so that the tool_properties table has a foreign key to the items table instead of the other way around
- [x] Fix bug where dropping a tool doesn't work
    - Is going to require re-thinking how the inventory is stored in server memory
    - Currently storing a map of objs.Item, but these don't hash well due to holding a pointer to a ToolsProps struct, which in turns holds a pointer to a Harvestable struct... Differing memory addresses for the same item in different maps. Need to think of a way to store the inventory in a way that can be hashed and compared, but can also communicate all the necessary information to the client.
- [x] Fix bug where dropping an item on the ground causes some kind of null pointer exception in Godot because it seems the item is null before it goes into the InGame._drop_item method. I think it's getting garbage collected or something.
- [ ] Sort inventory items by name alphabetically
- [ ] Rate limit client actions
- [ ] Figure out how to long tap to hover over an item on mobile to get the tooltips