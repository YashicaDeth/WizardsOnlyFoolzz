# System Map

## Implemented spine

`WorldHistory` is an autoload service that records compact, serialisable world events in `user://world_history.json`. Every record has a stable sequence ID, monotonic session timestamp, event type and system-specific details. It is deliberately data-only: gameplay systems own their behaviour and subscribe to history rather than coupling directly to each other.

Current proof path: `Rift Derby` -> `derby_session_started` / `derby_collision` / `derby_round_reset` -> `WorldHistory` -> persistent event log.

## Next integrations

1. Define a persistent character record for one rival and one friend.
2. Subscribe that record to derby collision events.
3. Surface the resulting memory through a small World Index screen.

Economy, factions, body damage and the in-game internet are not implemented by this service. They will add their own subscribers only when their bounded prototypes exist.
