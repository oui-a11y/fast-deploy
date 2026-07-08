# DeployBar

DeployBar is a native macOS menu bar app for local deployment workflows.

You configure a project once with shell steps, variables, and environments.
After that, deploy from the macOS menu bar.

## Build

```bash
swift build
```

## Package As A Menu Bar App

```bash
scripts/build-app.sh
```

The generated app is:

```text
.build/DeployBar.app
```

The app bundle uses `LSUIElement = true`, so packaged runs appear in the macOS
menu bar instead of the Dock.

## GitHub Release

Version tags run `.github/workflows/release.yml`.

Create and push a tag like:

```bash
git tag v0.1.0
git push origin v0.1.0
```

The workflow builds the release app on a macOS runner, publishes a GitHub
Release for that tag, and uploads:

```text
DeployBar-v0.1.0.app.zip
DeployBar-v0.1.0.app.zip.sha256
```

## MVP Features

- Menu bar panel built with SwiftUI `MenuBarExtra`.
- Menu bar opens a compact quick-deploy list.
- Active deployments show progress directly on the clicked shortcut row.
- `Edit` opens the configuration window in the center of the screen.
- Project and environment configuration.
- New project creation starts with a folder picker.
- Built-in project templates.
- Ordered shell deployment steps.
- `{{variable}}` replacement.
- Built-in variables:
  - `{{projectName}}`
  - `{{projectPath}}`
  - `{{env}}`
  - `{{timestamp}}`
  - `{{date}}`
- Live stdout/stderr logs.
- Basic log and command-preview redaction for common secret patterns.
- Stop running deployment.
- Local deployment history.
- JSON persistence under Application Support.

## Built-In Templates

- Blank Shell
- Frontend + rsync
- Docker build + push
- K8s rollout
- K8s rollout + password SSH
- Java jar upload

## Example Step Commands

Frontend static deploy:

```bash
pnpm install
pnpm build
rsync -avz ./dist/ {{server}}:{{remotePath}}/
ssh {{server}} "sudo systemctl reload nginx"
```

Kubernetes restart:

```bash
docker build -t {{image}}:{{timestamp}} .
docker push {{image}}:{{timestamp}}
ssh {{server}} "kubectl rollout restart deployment {{deployment}} -n {{namespace}}"
ssh {{server}} "kubectl rollout status deployment {{deployment}} -n {{namespace}}"
```

Kubernetes restart with password SSH:

```bash
pnpm install && pnpm build
SSHPASS='{{sshPassword}}' sshpass -e ssh -o PreferredAuthentications=keyboard-interactive,password -o PubkeyAuthentication=no -o BatchMode=no -o NumberOfPasswordPrompts=1 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null {{sshUser}}@{{sshHost}} "whoami"
SSHPASS='{{sshPassword}}' sshpass -e ssh -o PreferredAuthentications=keyboard-interactive,password -o PubkeyAuthentication=no -o BatchMode=no -o NumberOfPasswordPrompts=1 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null {{sshUser}}@{{sshHost}} "kubectl rollout restart deployment {{deployment}} -n {{namespace}}"
SSHPASS='{{sshPassword}}' sshpass -e ssh -o PreferredAuthentications=keyboard-interactive,password -o PubkeyAuthentication=no -o BatchMode=no -o NumberOfPasswordPrompts=1 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null {{sshUser}}@{{sshHost}} "kubectl rollout status deployment {{deployment}} -n {{namespace}}"
SSHPASS='{{sshPassword}}' sshpass -e ssh -o PreferredAuthentications=keyboard-interactive,password -o PubkeyAuthentication=no -o BatchMode=no -o NumberOfPasswordPrompts=1 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null {{sshUser}}@{{sshHost}} "kubectl get pods -n {{namespace}} -o wide"
```

Password SSH requires `sshpass` on the Mac:

```bash
brew install hudochenkov/sshpass/sshpass
```

## Config Location

DeployBar stores release app data in:

```text
~/Library/Application Support/local.deploybar.app/
```

Debug builds store data separately in:

```text
~/Library/Application Support/DeployBar-Debug/
```
# fast-deploy
