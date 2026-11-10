import Foundation

/// Switches macOS Low Power Mode. Only root may change it, so the first switch asks for the
/// admin password once and installs a sudoers rule limited to exactly these two commands;
/// later switches run through `sudo -n` without a prompt.
/// Remove the rule with: sudo rm /etc/sudoers.d/batterysegments
enum LowPowerMode {
    private static let commands = ["/usr/bin/pmset -a lowpowermode 0", "/usr/bin/pmset -a lowpowermode 1"]

    /// nil for a user name that is not plain: it goes into a root-owned file and a root shell.
    static func sudoersRule(user: String) -> String? {
        let plain = !user.isEmpty && user.unicodeScalars.allSatisfy {
            $0.isASCII && (CharacterSet.alphanumerics.contains($0) || "_-.".unicodeScalars.contains($0))
        }
        return plain ? "\(user) ALL=(root) NOPASSWD: \(commands.joined(separator: ", "))" : nil
    }

    static func set(_ on: Bool) {
        let command = commands[on ? 1 : 0]
        DispatchQueue.global().async {
            if run("/usr/bin/sudo", ["-n"] + command.components(separatedBy: " ")) { return }
            var script = command
            if let rule = sudoersRule(user: NSUserName()) {
                // visudo checks the rule before it is installed: a broken sudoers file locks sudo.
                script = "f=$(/usr/bin/mktemp) && echo '\(rule)' > \"$f\" && /usr/sbin/visudo -cf \"$f\" >/dev/null"
                    + " && /usr/bin/install -m 0440 -o root -g wheel \"$f\" /etc/sudoers.d/batterysegments;"
                    + " /bin/rm -f \"$f\"; \(command)"
            }
            let quoted = script.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
            _ = run("/usr/bin/osascript", ["-e", "do shell script \"\(quoted)\" with administrator privileges"])
        }
    }

    private static func run(_ path: String, _ arguments: [String]) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return false }
        process.waitUntilExit()
        return process.terminationStatus == 0
    }
}
