# Contributor Guide

## Commit Messages

Because we use the [release-please](https://github.com/googleapis/release-please) bot, commit messages to main must follow the [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) specification. This is enforced by the [commitlint](https://commitlint.js.org/#/) tool. This requirement is only enforced on the `main` branch. Commit messages in PRs can be whatever you want them to be. "Squash" mode must be used when merging a PR, with a commit message that follows the Conventional Commits specification.

## Release Process

This repo uses the [release-please](https://github.com/googleapis/release-please) bot. Release-please will automatically open a PR to update the version of the repo when a commit is merged to `main` that follows the [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) specification. The bot will automatically keep the PR up to date until a human merges it. When that happens the bot will automatically create a new release.
