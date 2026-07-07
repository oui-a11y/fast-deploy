import Foundation

enum ProjectTemplate: String, CaseIterable, Identifiable {
    case blank
    case frontendRsync
    case dockerPush
    case kubernetesRollout
    case kubernetesPasswordSSH
    case javaJar

    var id: String { rawValue }

    var title: String {
        switch self {
        case .blank: return "Blank Shell"
        case .frontendRsync: return "Frontend + rsync"
        case .dockerPush: return "Docker build + push"
        case .kubernetesRollout: return "K8s rollout"
        case .kubernetesPasswordSSH: return "K8s rollout + password SSH"
        case .javaJar: return "Java jar upload"
        }
    }

    func makeProject(path: String) -> DeployProject {
        let url = URL(fileURLWithPath: path)
        let projectName = url.lastPathComponent.isEmpty ? "New Project" : url.lastPathComponent
        return DeployProject(
            name: projectName,
            localPath: path,
            environments: [makeEnvironment(projectName: projectName)]
        )
    }

    private func makeEnvironment(projectName: String) -> DeployEnvironment {
        switch self {
        case .blank:
            return DeployEnvironment(
                name: "dev",
                variables: [:],
                steps: [
                    DeployStep(name: "Check path", command: "pwd"),
                    DeployStep(name: "Run command", command: "echo \"Configure your deployment steps\"")
                ]
            )

        case .frontendRsync:
            return DeployEnvironment(
                name: "dev",
                variables: [
                    "server": "dev-server",
                    "remotePath": "/var/www/\(projectName)"
                ],
                steps: [
                    DeployStep(name: "Install dependencies", command: "pnpm install"),
                    DeployStep(name: "Build", command: "pnpm build"),
                    DeployStep(name: "Upload dist", command: "rsync -avz ./dist/ {{server}}:{{remotePath}}/"),
                    DeployStep(name: "Reload nginx", command: "ssh {{server}} \"sudo systemctl reload nginx\"")
                ]
            )

        case .dockerPush:
            return DeployEnvironment(
                name: "dev",
                variables: [
                    "image": "registry.example.com/\(projectName)",
                    "tag": "{{timestamp}}"
                ],
                steps: [
                    DeployStep(name: "Build image", command: "docker build -t {{image}}:{{tag}} ."),
                    DeployStep(name: "Push image", command: "docker push {{image}}:{{tag}}")
                ]
            )

        case .kubernetesRollout:
            return DeployEnvironment(
                name: "dev",
                variables: [
                    "server": "dev-server",
                    "namespace": "dev",
                    "deployment": projectName
                ],
                steps: [
                    DeployStep(name: "Restart deployment", command: "ssh {{server}} \"kubectl rollout restart deployment {{deployment}} -n {{namespace}}\""),
                    DeployStep(name: "Wait for rollout", command: "ssh {{server}} \"kubectl rollout status deployment {{deployment}} -n {{namespace}}\""),
                    DeployStep(name: "List pods", command: "ssh {{server}} \"kubectl get pods -n {{namespace}}\"")
                ]
            )

        case .kubernetesPasswordSSH:
            return DeployEnvironment(
                name: "dev",
                variables: [
                    "sshHost": "10.1.61.126",
                    "sshUser": "root",
                    "sshPassword": "1234",
                    "namespace": "default",
                    "deployment": projectName
                ],
                steps: [
                    DeployStep(
                        name: "Build",
                        command: "pnpm install && pnpm build"
                    ),
                    DeployStep(
                        name: "Check sshpass",
                        command: "command -v sshpass >/dev/null || { echo \"sshpass is required for password SSH. Install it with: brew install hudochenkov/sshpass/sshpass\"; exit 127; }"
                    ),
                    DeployStep(
                        name: "Test SSH login",
                        command: "SSHPASS='{{sshPassword}}' sshpass -e ssh -o PreferredAuthentications=keyboard-interactive,password -o PubkeyAuthentication=no -o BatchMode=no -o NumberOfPasswordPrompts=1 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null {{sshUser}}@{{sshHost}} \"whoami\" || { echo \"SSH password login failed. Check sshUser/sshPassword, and confirm the server allows password login for this user.\"; exit 255; }"
                    ),
                    DeployStep(
                        name: "Restart deployment",
                        command: "SSHPASS='{{sshPassword}}' sshpass -e ssh -o PreferredAuthentications=keyboard-interactive,password -o PubkeyAuthentication=no -o BatchMode=no -o NumberOfPasswordPrompts=1 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null {{sshUser}}@{{sshHost}} \"kubectl rollout restart deployment {{deployment}} -n {{namespace}}\""
                    ),
                    DeployStep(
                        name: "Wait for rollout",
                        command: "SSHPASS='{{sshPassword}}' sshpass -e ssh -o PreferredAuthentications=keyboard-interactive,password -o PubkeyAuthentication=no -o BatchMode=no -o NumberOfPasswordPrompts=1 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null {{sshUser}}@{{sshHost}} \"kubectl rollout status deployment {{deployment}} -n {{namespace}}\""
                    ),
                    DeployStep(
                        name: "List pods",
                        command: "SSHPASS='{{sshPassword}}' sshpass -e ssh -o PreferredAuthentications=keyboard-interactive,password -o PubkeyAuthentication=no -o BatchMode=no -o NumberOfPasswordPrompts=1 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null {{sshUser}}@{{sshHost}} \"kubectl get pods -n {{namespace}} -o wide\""
                    )
                ]
            )

        case .javaJar:
            return DeployEnvironment(
                name: "dev",
                variables: [
                    "server": "dev-server",
                    "remotePath": "/opt/apps/\(projectName)",
                    "service": projectName
                ],
                steps: [
                    DeployStep(name: "Build jar", command: "mvn clean package -DskipTests"),
                    DeployStep(name: "Upload jar", command: "scp target/*.jar {{server}}:{{remotePath}}/app.jar"),
                    DeployStep(name: "Restart service", command: "ssh {{server}} \"sudo systemctl restart {{service}}\""),
                    DeployStep(name: "Check service", command: "ssh {{server}} \"sudo systemctl status {{service}} --no-pager\"")
                ]
            )
        }
    }
}
