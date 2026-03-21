<div align="center">

<img width="456" alt="Hackatime" src="https://github.com/user-attachments/assets/b3036ced-a7ea-4d03-8feb-816a83572e3a#gh-light-mode-only" />
<img width="456" alt="Hackatime" src="https://github.com/user-attachments/assets/1d237c55-d349-44d3-93e6-d9dbb627e4dc#gh-dark-mode-only" />

[![Ping](https://uptime.hackclub.com/api/badge/4/ping)](https://uptime.hackclub.com/status/hackatime)
[![Status](https://uptime.hackclub.com/api/badge/4/status)](https://uptime.hackclub.com/status/hackatime)
[![Work time](https://hackatime-badge.hackclub.com/U0C7B14Q3/harbor)](https://hackatime-badge.hackclub.com)

[**Documentation**](https://hackatime.hackclub.com/docs)

</div>

## Local development

Please read [DEVELOPMENT.md](DEVELOPMENT.md) for instructions on setting up and running the project locally.

## Verified Coding Time

This fork includes server-side heartbeat verification to make time tracking harder to game.

- Each incoming heartbeat gets a `trust_score`, `verified` flag, and `trust_reasons`.
- Time shown in the status bar and Hackatime compatibility stats is based on verified heartbeats.
- API responses now expose `raw_total_seconds`, `verified_total_seconds`, and `suspicious_seconds` so clients can compare accepted time against raw activity.

The current verifier is metadata-based: it rewards real typing signals like `is_write`, line additions, deletions, and code-like files, while downranking passive or suspicious events such as non-code files, missing typing signals, and future timestamps.

## Installer repo

Looking for the installer code? It's over at [hackclub/hackatime-setup](https://github.com/hackclub/hackatime-setup).
