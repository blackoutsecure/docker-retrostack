# Contributing

Thanks for your interest in contributing!

## Getting Started

1. Fork the repository and clone your fork.
2. Create a feature branch: `git checkout -b my-feature`
3. Make your changes — see the project structure in the [README](README.md).
4. Test locally: `docker compose --profile all up --build`
5. Commit with a clear message and open a pull request against `main`.

## Adding a New Emulator

1. Add a `FROM ... AS <name>` stage to the `Dockerfile` (with a builder stage if compiling from source).
2. Set `ENV EMULATOR_NAME=<name>` and `ENV EMULATOR_BINARY=/path/to/binary`.
3. `COPY` scripts from `root/usr/local/bin/` and s6 services from `root/etc/s6-overlay/s6-rc.d`.
4. Add a service in `docker-compose.yml` with the `esde-emulator-control` volume and device mounts.
5. Add matrix entries in the CI workflows (`publish.yml`, `upstream-monitor.yml`).
6. On the ES-DE side, symlink `esde-emulator-launch` as the emulator name.

## Guidelines

- Keep Dockerfile stages minimal — install only what the emulator needs at runtime.
- Use multi-stage builds for source-compiled emulators.
- Run `hadolint Dockerfile` before submitting.
- Follow existing code style and naming conventions.
- Scripts live under `root/usr/local/bin/`, s6 services under `root/etc/s6-overlay/s6-rc.d/`.

## Reporting Issues

Open an issue with steps to reproduce, expected behavior, and your environment (OS, Docker version, architecture).

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
