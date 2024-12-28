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
1. Create a `.env` file in the `/server/` directory with the following contents:
    ```
    PORT=43200
    CERT_PATH=/absolute/path/to/public/cert.pem
    KEY_PATH=/absolute/path/to/private/key.pem
    DATA_PATH=./data
    CLIENT_EXPORT_PATH=../client/export/web
    ADMIN_PASSWORD=yourpassword
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
- [ ] Disable camera zoom while scrolling inside inventory/chat
- [x] Disable cursor keys changing between chat and inventory
- [x] Fix nameplate positioning
- [x] Make ground items respawn after a while
- [ ] Add grab/drop controls for mobile
- [ ] Audit use of int64 in game_objects.go and messages.proto
- [ ] Let players cut down trees with an axe
- [ ] Add an XP system and leveling up woodcutting
- [ ] Add an NPC that buys wood
- [ ] Add an NPC that sells faerie dust
- [ ] Add a quest to heal a wounded soldier with faerie dust to get a key
- [ ] Add a locked door that requires a key to open, with a reward inside
- [ ] Add a special status symbol for players who have completed the quest
- [ ] Add spawn point in levels
- [ ] Speed up level uploading?
- [ ] Translate to Japanese
- [ ] Use StringNames for inventory script?