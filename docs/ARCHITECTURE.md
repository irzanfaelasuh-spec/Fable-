# Architecture notes

## Client

Godot 4.7.2 runs a single `Node2D` main scene. The world is a `Node2D` rendered through `_draw()` using geometric pixel-style primitives. The HUD is created in a `CanvasLayer`, so camera movement does not drag the interface. Android uses a code-drawn virtual joystick and separate action buttons. The Android display orientation is locked to landscape in `project.godot` and enforced at startup on Android.

The world generator is deterministic from an integer seed. A local world record stores its name, seed and sparse block overrides in `user://worlds.json`. This keeps the save local to that installation.

## Realtime networking

`NetworkClient` owns a `WebSocketPeer`, polls it every frame, parses JSON messages and sends an application heartbeat every 25 seconds. The Node.js service uses the same JSON protocol over `/ws`.

The server owns room codes and room lifecycle. A generated code is accepted only while room status is `lobby`. `start_game` switches status to `playing`; a subsequent `join_room` for that code receives `expired`. The room remains alive for the already-connected players until they leave or the server stops.

Movement is a lightweight relay in this prototype: clients send position snapshots and the server broadcasts them to other members. Block changes, emotes and chat use the same relay pattern. This is appropriate for an early five-player test, not a cheat-resistant production simulation. A production version should make the server authoritative for collision, movement and block validation.

## Accounts and persistence

Registration validates the username, normalizes it for uniqueness, derives a `scrypt` hash with a cryptographically random salt, and stores the salt/hash pair. PostgreSQL is selected when `DATABASE_URL` is present. Otherwise, local JSON storage is used for local development. The production hosting instructions use PostgreSQL because many free web hosts discard local filesystem changes after restarts.

## Hosting boundary

GitHub Actions builds the Android client. It does not host the WebSocket server. The server is a separate long-running Node.js process and must be deployed to a service reachable by all players. A TLS URL (`wss://`) is required for an internet deployment.
