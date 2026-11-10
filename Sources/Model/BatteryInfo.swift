import Foundation
import IOKit
import IOKit.ps

struct BatteryInfo: Equatable {
    enum State: Equatable {
        case noBattery
        case pluggedIn(charging: Bool)
        case calculating
        case onBattery(minutes: Double)
    }

    var percent = 0
    var state = State.noBattery
    var watts: Double? // current system draw; nil when unreadable

    static func read() -> BatteryInfo {
        var info = BatteryInfo()
        let blob = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(blob).takeRetainedValue() as [CFTypeRef]
        let battery = sources.lazy
            .compactMap { IOPSGetPowerSourceDescription(blob, $0)?.takeUnretainedValue() as? [String: Any] }
            .first { $0[kIOPSTypeKey] as? String == kIOPSInternalBatteryType }
        guard let battery else { return info }

        let current = battery[kIOPSCurrentCapacityKey] as? Int ?? 0
        let maximum = battery[kIOPSMaxCapacityKey] as? Int ?? 100
        info.percent = maximum > 0 ? current * 100 / maximum : 0
        let smart = smartBattery()
        info.watts = smart?.watts
        if battery[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue {
            info.state = .pluggedIn(charging: battery[kIOPSIsChargingKey] as? Bool ?? false)
        } else {
            // The system estimate can stay unknown for a long time after unplugging
            // (pmset shows "no estimate"), so fall back to the battery gauge's own numbers.
            let seconds = IOPSGetTimeRemainingEstimate() // < 0: unknown
            let minutes = seconds >= 0 ? seconds / 60 : smart?.minutes
            info.state = minutes.map { .onBattery(minutes: $0) } ?? .calculating
        }
        return info
    }

    /// Power draw and a time-to-empty fallback from the AppleSmartBattery registry entry.
    private static func smartBattery() -> (watts: Double, minutes: Double?)? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        func property(_ key: String) -> Any? {
            IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
        }
        let data = property("BatteryData") as? [String: Any] ?? [:]
        func number(_ key: String) -> Double? {
            // amperage is a negative value stored unsigned, hence int64Value
            ((data[key] ?? property(key)) as? NSNumber).map { Double($0.int64Value) }
        }
        guard let milliamps = number("InstantAmperage"), let millivolts = number("Voltage") else { return nil }
        return (abs(milliamps) * millivolts / 1e6,
                fallbackMinutes(average: number("AvgTimeToEmpty"), milliampHours: number("AppleRawCurrentCapacity"),
                                milliamps: milliamps))
    }

    /// The gauge's averaged time to empty when it has one (65535 = unknown),
    /// else remaining charge / current draw while discharging (negative current).
    static func fallbackMinutes(average: Double?, milliampHours: Double?, milliamps: Double) -> Double? {
        if let average, average > 0, average < 65535 { return average }
        if let milliampHours, milliamps < 0 { return milliampHours / -milliamps * 60 }
        return nil
    }
}
