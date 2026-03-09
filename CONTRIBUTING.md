# Contributing to Digital Ether

Welcome! This guide explains how to contribute to the project and how our deployment workflow works.

## Branching Strategy

- **`master`**: Production environment. Only stable, tested code goes here.
- **`develop`**: Nightly/Staging environment. All new features and bug fixes should be merged here first.

## Workflow

1. **Feature/Bugfix**: Create a new branch from `develop`.
2. **Pull Request**: Open a PR to merge your changes into `develop`.
3. **Testing**: Once merged into `develop`, the "Nightly" build will be triggered. Test your changes in the nightly app.
4. **Release**: Periodically, `develop` is merged into `master` for a production release.

## Development Environment

To build the app and connect to a specific server (e.g., your local machine or a staging server), use the `--dart-define` flag:

```bash
flutter run --dart-define=SERVER_URL=https://your-server-url.com
```

## CI/CD Automation

We use GitHub Actions to automate the build and release process:

- **Nightly**: Every push to `develop` automatically builds a new APK and creates/updates a GitHub Release tagged with `-nightly`.
- **Production**: Every push to `master` builds the production APK and creates an official release.

You no longer need to run the `build_and_deploy.ps1` script manually for remote releases, although it remains available for local builds.

Thank you for contributing!
