# WebSocket protocol v1

All client messages are JSON text frames sent to `/ws`. Server responses use the same shape with a `type` field.

## Authentication

- `register`: `{ "type":"register", "username":"...", "password":"..." }`
- `login`: `{ "type":"login", "username":"...", "password":"..." }`
- `auth_result`: `{ "type":"auth_result", "ok":true, "username":"...", "playerId":"..." }` or `{ "type":"auth_result", "ok":false, "code":"username_taken|invalid_input|invalid_credentials|rate_limited|server_error" }`
- `logout`: clears the socket's authenticated identity and leaves its current room.

Usernames are 3–16 characters and match `[A-Za-z0-9_]+`. Passwords are 8–72 characters. Account names are unique case-insensitively.

## Rooms

- `create_room`: creates a room with a random six-character code, a seed and a maximum of five players.
- `join_room`: `{ "type":"join_room", "code":"ABC123" }` is accepted only while status is `lobby`.
- `start_game`: only the host can change status from `lobby` to `playing`.
- `room_error` codes: `invalid_code`, `full`, `expired`, `not_host`.
- `room_update`: contains the current player list and host id.
- `game_started`: contains the room seed and player snapshot.
- `leave_room` / `close_room`: removes a player or closes the room.

A room can start with one player. Five is a maximum, not a minimum. A room code is unique during the lifetime of the running server process; after `start_game`, that code cannot be used by new joiners.

## Gameplay relay

- `move`: `{ "type":"move", "x":123, "y":456 }`
- `player_moved`: server relays another member's id, username and coordinates.
- `chat`: `{ "type":"chat", "message":"hello" }`; maximum 160 characters.
- `chat_message`: contains sender, message and server timestamp.
- `emote`: `hi`, `sad` or `happy` only.
- `block_change`: `break` or `place`, integer tile coordinates and a block type.

The server validates basic message shapes and bounds but does not yet simulate physics or verify mining time. Add authoritative simulation before a public competitive release.
