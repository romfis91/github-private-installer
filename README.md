# Private Repo Installer

A minimal bootstrap script that fetches and executes an installation entrypoint from a **private** GitHub repository.

The public `bootstrap.sh` contains no app-specific logic — it only handles authentication and delegation. All installation logic lives in your private repo.

## How it works

```
curl bootstrap.sh → prompts for token + repo + entrypoint → downloads entrypoint via GitHub API → executes it
```

## Usage

### Interactive

```bash
curl -fsSL https://raw.githubusercontent.com/romfis91/github-private-installer/main/bootstrap.sh | sudo bash
```

You will be prompted for:
- **GitHub token** — a personal access token with `repo` scope
- **Repository** — e.g. `owner/my-app`
- **Entrypoint** — path to the install script inside the repo, e.g. `scripts/install.sh`

### Non-interactive (CI / automated)

Pass all arguments via `bash -s --`:

```bash
curl -fsSL https://raw.githubusercontent.com/romfis91/github-private-installer/main/bootstrap.sh | \
  sudo bash -s -- \
    --token  ghp_xxxxxxxxxxxx \
    --repo   owner/my-app \
    --entrypoint scripts/install.sh
```

Arguments can also be provided as environment variables before piping:

```bash
TOKEN=ghp_xxx REPO=owner/my-app ENTRYPOINT=scripts/install.sh \
  curl -fsSL .../bootstrap.sh | sudo bash
```

## Arguments

| Flag           | Env var      | Description                                      |
|----------------|--------------|--------------------------------------------------|
| `--token`      | `TOKEN`      | GitHub personal access token (`repo` scope)      |
| `--repo`       | `REPO`       | Repository in `owner/repo` format                |
| `--entrypoint` | `ENTRYPOINT` | Path to the script inside the repo               |

CLI flags take precedence over environment variables.

## What the entrypoint receives

The entrypoint script is executed with `GITHUB_TOKEN` exported, so it can make further authenticated GitHub API calls (e.g. to download release assets):

```bash
# inside your scripts/install.sh
curl -fsSL \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/octet-stream" \
  "https://api.github.com/repos/owner/my-app/releases/assets/12345" \
  -o /usr/local/bin/my-app
```

## Development

### Requirements

- [bats-core](https://github.com/bats-core/bats-core) for tests
- [shellcheck](https://github.com/koalaman/shellcheck) for linting

```bash
brew install bats-core shellcheck
```

### Run tests

```bash
bats tests/
```

### Lint

```bash
shellcheck bootstrap.sh tests/init.bats
```

## CI

Every push and pull request to `main` runs:
1. **shellcheck** — static analysis
2. **bats** — unit tests

## Release

Releases are created automatically on every push/merge to `main` after CI passes.
The version is bumped based on the commit message prefix:

| Prefix       | Bump    | Example                          |
|--------------|---------|----------------------------------|
| `breaking:`  | major   | `breaking: drop --token flag`    |
| `feat:`      | minor   | `feat: add --timeout flag`       |
| anything else | patch  | `fix: handle 429 response`       |

Each release publishes `bootstrap.sh` as a release asset with an auto-generated changelog.
