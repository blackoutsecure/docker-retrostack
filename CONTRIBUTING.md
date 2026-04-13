# Contributing

## Getting Started

1. Fork and clone.
2. Feature branch: `git checkout -b my-feature`
3. Test: `docker compose --profile all up --build`
4. Open a pull request against `main`.

## Adding a New Emulator

1. Add `FROM ... AS <name>` stage to `Dockerfile` (with builder stage if source-compiled).
2. Set `ENV EMULATOR_NAME=<name>` and `ENV EMULATOR_BINARY=/path/to/binary`.
3. Add service in `docker-compose.yml` with control volume and device mounts.
4. Add CI matrix entries in `publish.yml` and `upstream-monitor.yml`.
5. On ES-DE side, symlink `retrostack-emulator-launch` as the emulator name.

## Code Standards

- Scripts source `retrostack-lib.sh` for shared functions and constants.
- All scripts include copyright header: `Copyright (c) 2026 Blackout Secure (https://blackoutsecure.app). MIT License.`
- Keep Dockerfile stages minimal — runtime deps only.
- Run `hadolint Dockerfile` and `shellcheck root/usr/local/bin/* root/usr/local/lib/*` before submitting.

## License

Contributions are licensed under the [MIT License](LICENSE).
