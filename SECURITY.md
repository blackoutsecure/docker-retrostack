# Security Policy

## Supported Versions

| Version | Supported          |
|---------|--------------------|
| latest  | :white_check_mark: |
| < latest | :x:               |

Only the latest images on `main` receive security updates.

## Reporting a Vulnerability

If you discover a security vulnerability, please report it responsibly:

1. **Do not** open a public GitHub issue.
2. Email **[security@blackoutsecure.com](mailto:security@blackoutsecure.com)** with:
   - A description of the vulnerability
   - Steps to reproduce
   - Affected image tags or components
3. You will receive acknowledgment within 48 hours and a resolution timeline within 7 days.

## Scope

This policy covers the Docker packaging, CI/CD pipelines, and the `esde-provision` script in this repository. Vulnerabilities in upstream emulators (RetroArch, PPSSPP, Dolphin) should be reported to their respective projects.

## Image Updates

Upstream emulator versions are monitored every 6 hours. When a new release is detected, images are automatically rebuilt and published with the latest security patches from the `ubuntu:noble` base.
