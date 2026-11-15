# Acceptance test plan

## Android presentation
- [ ] Install debug APK on a real Android phone.
- [ ] Verify every screen stays landscape while rotating the phone.
- [ ] Check menu, login form, create-account form, room lobby, inventory panel and chat panel at 1280×720 and a smaller landscape resolution.
- [ ] Drag the virtual joystick in all directions and release it; verify the character stops immediately.
- [ ] Verify touch controls do not cover the chat input or inventory.

## Local worlds
- [ ] Create a world with a 2–24 character name.
- [ ] Verify terrain and seed remain the same after leaving and reopening the world.
- [ ] Mine grass/dirt, wait for the mining duration, then verify inventory count.
- [ ] Mine stone with the starter pickaxe and verify stone count.
- [ ] Place dirt and verify the block and count update.
- [ ] Exit and reopen the same world; verify changes are saved.

## Accounts
- [ ] Register a new username.
- [ ] Attempt to register the same username with different capitalization; expect `username_taken`.
- [ ] Attempt a username shorter than three characters or with spaces; expect validation failure.
- [ ] Log in with the correct password; expect success.
- [ ] Log in with the wrong password; expect `invalid_credentials`.
- [ ] Verify the database contains only the salt and scrypt hash, never the password.

## Multiplayer (two devices on different internet connections)
- [ ] Log in on both devices against the same `wss://` server.
- [ ] Host a room on device A; verify a six-character random code appears.
- [ ] Join from device B; verify both players appear in the lobby.
- [ ] Start from the host; verify both clients enter the same seeded world.
- [ ] Verify movement, usernames, emotes, chat and block changes are visible on both clients.
- [ ] Try to join the old code from a third connection after start; expect `expired`.
- [ ] Fill a room to five players and try a sixth; expect `full`.
- [ ] Try an unknown code; expect `invalid_code`.
- [ ] Stop or disconnect the server; expect a server-unavailable / connection-lost message.

Passing this checklist requires actual device and deployed-server testing. A static code review alone is not a substitute.
