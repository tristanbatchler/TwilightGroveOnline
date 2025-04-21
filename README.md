# Twilight Grove Online

<p align="center">
  <img src="./client/icon.png" />
</p>

*A tiny MUD*

The official game is live and can be played at [https://twilightgrove.tbat.me](https://twilightgrove.tbat.me).


Twilight Grove is a persistent world in a multi-user dungeon made in under a month using Godot 4.4 and Golang for the server. It is completely server-authoritative (i.e. no peer connections) and cross-platform. Here is a demo of the game:

<p align="center">
  <video src="https://github.com/user-attachments/assets/9678e4c6-8909-4150-bd23-ff7dc373a2d5" nocontrols autoplay loop />
</p>

The process used to create Twilight Grove Online is both in a written and video format:
* [YouTube playlist](https://youtube.com/playlist?list=PLA1tuaTAYPbHAU2ISi_aMjSyZr-Ay7UTJ&si=vwm_yXkPAyqgSeOU)
* [Companion blog posts](https://www.tbat.me/projects/godot-golang-mmo-tutorial-series)

I have not stress tested it extensively, but I believe it can support 50 concurrent players with a modest desktop running the server executable. This would scale quite nicely with more compute power.

## Setup if you want to run your own server
1. Install Go and ensure `~/go/bin` is in your PATH.
1. [Download Godot Engine 4.4 dev 3](https://godotengine.org/download/archive/4.4-dev3) and copy the console binary to the `/client/` directory of this project, renaming it to `godot`.
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

1. Create a database named `twilightgrove`, and create a new user for the game to run as:
  ```sql
  CREATE USER game_admin WITH PASSWORD 'your_secure_password';
  GRANT CONNECT ON DATABASE twilightgrove TO game_admin;
  ALTER DATABASE twilightgrove OWNER TO game_admin;
  ```

1. Create a `.env` file in the `/server/` directory with the following contents, where `/path/to/your/data` is wherever you want the server to store its data like message of the day, profanity lists, etc.:
    ```
    PG_HOST=192.168.20.17 # or your local IP (I think host.docker.internal works too)
    PG_PORT=5432
    PG_USER=game_admin
    PG_PASSWORD=your_secure_password
    PG_DATABASE=twilightgrove
    PORT=43200
    CERT_PATH=/path/to/your/cert.pem
    KEY_PATH=/path/to/your/key.pem
    DATA_PATH=/path/to/your/data
    ADMIN_PASSWORD=choose_a_password_for_the_game_admin
    ```
1. Optional: install the [vscode-proto3](https://marketplace.visualstudio.com/items?itemName=zxh404.vscode-proto3) extension for syntax highlighting and automatical go compilation on save.

1. Edit the root `Entered` node in the `res://states/entered/entered.tscn` scene in Godot to have a server URL of `wss://dev.your.domain:43200/ws`.

1. Press F5 in VSCode to run the server. This will generate the Go code from the protobuf files and start the server.

1. Run the client from the Godot editor and login with the username `admin` and the password you set in the `.env` file.

1. Choose **Upload level** from the admin menu and upload each level in the default levels directory (you can edit these however you like in `/client/admin_levels/` within the Godot editor)

## Features / TODO:
- [x] Items on the ground for the level
- [x] Level parsing
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
- [x] Make trees require a bit of time to cut down, proportional to their strength, the type of axe, and the player's woodcutting level
- [x] Add an NPC that sells faerie dust
- [x] Add a quest to heal a wounded soldier with faerie dust to get a key
- [x] Add a locked door that requires a key to open, with a reward inside
- [x] Add a special status symbol for players who have completed the quest
- [x] Add spawn point in levels
- [x] Speed up level uploading?
- [ ] Translate to Japanese (just for fun and an excuse to practice and see what it takes to localize the game)
- [x] Use StringNames for inventory script?
- [x] Allow customizing the player's appearance
- [x] Allow support for multiple items in LevelPointMap stacked on top of each other
- [x] Smooth camera zooming
- [ ] Pinch to zoom on mobile
- [x] Scroll down inventory when selecting items with the keyboard
- [ ] Rearrange DB schema so that the tool_properties table has a foreign key to the items table instead of the other way around
- [x] Fix bug where dropping a tool doesn't work
- [x] Fix bug where dropping an item on the ground causes some kind of null pointer exception in Godot because it seems the item is null before it goes into the InGame._drop_item method. I think it's getting garbage collected or something.
- [x] Sort inventory items by name alphabetically
- [x] Rate limit client actions
- [ ] Figure out how to long tap to hover over an item on mobile to get the tooltips
- [x] Add a placeholder sprite over top of depleted resources to show they can't be walked on
- [x] Make player drops despawn after a while
- [x] Add collision points to areas beyond doorways to stop players from getting stuck inside a room
- [x] Add settings for sound volume and balance default settings
- [x] Persist completed quests in the database
- [x] Fix issue where required quest item won't be removed from the client's inventory after completing the quest (requires re-log to see the change).
- [x] Make some items untreadable and not droppable
- [x] Profanity filter for username registration
- [x] More lenient profanity filter for chat
- [ ] Fix blurry font on resized windows
- [x] Add keyboard control hints
- [x] Add keyboard rebinds in settings
- [x] Make NPCs move again, but only when not in range of a player (and refactor duplicated move logic)
- [x] Figure out weird tools spawning with Harvestable_NONE set, messing up sync between inventory
- [x] Figure out weird keyboard sometimes jumping 2x
- [x] Hold shift while using keyboard controls to buy/sell in multiples of 10
- [x] Fix animations not playing if not perfectly aligned to tile yet
- [x] Stop player-dropped or respawned items from being added to the DB and growing the stack each server reboot
- [x] Fix transparency inconsistencies in UI panels e.g. log is more opaque than shop
- [x] Add credits and attributions
- [ ] Add a guest mode
- [x] Compress the WASM and serve client over netlify
- [x] Locked doors are still a bit bugged. Watching another player come out of a locked door makes it seem like they're stuck in the wall.
- [x] Axe spawns outside the boundary in the mines? Item spawn should be broadcast just to people in level
- [x] Make inventory not scroll when you sell an item
- [x] Passwords don't match or profane username = disable line edits and won't let you register
- [ ] Can't use cursor keys when typing
- [ ] Have XP tooltip update while hovering
- [ ] Spamming harvest like 10 times then move, then try to mine again normally, it mines without the animation 
- [ ] Random variation in harvest time
- [ ] Dismiss nag messages on next move
- [ ] Don't allow movement when talking to NPCs or shopping
- [ ] Add server check to make sure player is close enough to NPC when buying/selling or interacting with them
- [ ] Allow remap of movement keys
- [x] Add instructions
