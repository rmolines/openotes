# Test Checklist
_Node: captura-audio/captura-sistema-audio/impl-captura-sistema_
_Generated: 2026-03-16_

## How to use
1. Run each test below
2. Mark [x] for pass, [ ] for fail
3. Add notes for any failures
4. Run /fractal:review when done

## T1 — Production Swift CLI capture
validates: Sistema captura áudio do SO e entrega chunks WAV Int16 16kHz mono de 30s
from: D1

steps:
1. Run `src/capture-system-audio` (requires Screen Recording permission)
2. Play some audio on the system for 35+ seconds
3. Observe stdout output
4. Send Ctrl-C (SIGTERM) to stop

expected: READY appears immediately after launch. CHUNK:<path> lines appear after ~30s. Files exist at the paths shown.
result: [ ]
notes:

## T2 — Validation script
validates: Build e validação automatizados para o CLI
from: D2

steps:
1. Ensure audio is playing on the system
2. Run `bash src/validate.sh`
3. Wait ~40 seconds for the script to complete

expected: Script prints PASS with details about the captured WAV chunk (16kHz, mono, 16-bit).
result: [ ]
notes:
