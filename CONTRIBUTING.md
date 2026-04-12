# Contributing

Thanks for your interest in contributing!

## Getting Started

1. Fork the repository and clone your fork.
2. Create a feature branch: `git checkout -b my-feature`
3. Make your changes — see the project structure in the [README](README.md).
4. Test locally: `docker compose up --build`
5. Commit with a clear message and open a pull request against `main`.

## Adding a New Emulator

1. Add a `FROM ... AS <name>` stage to the `Dockerfile` (with a builder stage if compiling from source).
2. Set `ENV EMULATOR_NAME=<name>` and `ENV EMULATOR_BINARY=/path/to/binary`.
3. `COPY --chmod=755 esde-provision /usr/local/bin/esde-provision` and set it as `ENTRYPOINT`.
4. Add a service in `docker-compose.yml`.
5. Add matrix entries in the CI workflows (`publish.yml`, `upstream-monitor.yml`).

## Guidelines

- Keep Dockerfile stages minimal — install only what the emulator needs at runtime.
- Use multi-stage builds for source-compiled emulators.
- Run `hadolint Dockerfile` before submitting.
- Follow existing code style and naming conventions.

## Reporting Issues

Open an issue with steps to reproduce, expected behavior, and your environment (OS, Docker version, architecture).

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
