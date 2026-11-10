import Darwin

struct ProcSample {
    let ppid: pid_t
    let energy: UInt64 // ri_billed_energy, cumulative
    let cpu: UInt64 // user + system time, cumulative
}

typealias Snapshot = [pid_t: ProcSample]

enum ProcessEnergy {
    /// Cumulative counters for every process we are allowed to read (our own user's).
    static func snapshot() -> Snapshot {
        var pids = [pid_t](repeating: 0, count: Int(proc_listallpids(nil, 0)) + 64)
        let count = Int(proc_listallpids(&pids, Int32(pids.count * MemoryLayout<pid_t>.size)))
        var out = Snapshot()
        for pid in pids.prefix(max(count, 0)) where pid > 0 {
            var usage = rusage_info_v4()
            let ok = withUnsafeMutablePointer(to: &usage) {
                $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                    proc_pid_rusage(pid, RUSAGE_INFO_V4, $0)
                }
            } == 0
            var bsd = proc_bsdinfo()
            let size = Int32(MemoryLayout<proc_bsdinfo>.size)
            guard ok, proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &bsd, size) == size else { continue }
            out[pid] = ProcSample(ppid: pid_t(bsd.pbi_ppid), energy: usage.ri_billed_energy,
                                  cpu: usage.ri_user_time + usage.ri_system_time)
        }
        return out
    }

    /// Usage between two snapshots, child processes folded into their app (ppid chain).
    /// Uses billed energy; falls back to CPU time when the kernel reports no energy.
    // shortcut: XPC helpers launched by launchd (e.g. Safari web content) are not attributed
    // to their app; upgrade to responsibility_get_pid_responsible_for_pid if Safari reads too low.
    static func usage(from old: Snapshot, to new: Snapshot, apps: Set<pid_t>) -> (perApp: [pid_t: Double], total: Double) {
        func owner(of pid: pid_t) -> pid_t? {
            var p = pid
            for _ in 0 ..< 32 {
                if apps.contains(p) { return p }
                guard let parent = new[p]?.ppid, parent > 1 else { return nil }
                p = parent
            }
            return nil
        }
        func tally(_ value: (ProcSample) -> UInt64) -> (perApp: [pid_t: Double], total: Double) {
            var perApp = [pid_t: Double](), total = 0.0
            for (pid, sample) in new {
                let now = value(sample), before = old[pid].map(value) ?? 0
                guard now > before else { continue }
                let delta = Double(now - before)
                total += delta
                if let app = owner(of: pid) { perApp[app, default: 0] += delta }
            }
            return (perApp, total)
        }
        let energy = tally(\.energy)
        return energy.total > 0 ? energy : tally(\.cpu)
    }
}
