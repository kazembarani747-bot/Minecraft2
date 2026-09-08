# Minecraft2 AI Subsystem

The AI subsystem is an optional in-game assistant and development tool. It is intentionally separated from the game simulation.

## Responsibilities

- Answer questions about the current world and available APIs.
- Generate mod/add-on source files from structured requests.
- Explain command syntax and create command templates.
- Inspect capability reports before proposing an extension.
- Produce a manifest and file plan for generated content.

## Safety and stability boundaries

AI-generated code is treated as untrusted content. Generated extensions must pass validation before loading into the live game. The AI must never silently change core binaries or replace the renderer/network stack.

## API key handling

The key must be supplied at runtime through secure app configuration/environment facilities. It is not stored in Git, project files, logs, or exported assets.

## Planned flow

User request -> AI planner -> Capability Registry -> file generator -> validator -> isolated extension -> optional enable -> game reload.
