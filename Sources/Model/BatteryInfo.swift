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
        if battery[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue {
            info.state = .pluggedIn(charging: battery[kIOPSIsChargingKey] as? Bool ?? false)
        } else {
            let seconds = IOPSGetTimeRemainingEstimate() // < 0: unknown / unlimited
            info.state = seconds >= 0 ? .onBattery(minutes: seconds / 60) : .calculating
        }
        info.watts = smartBatteryWatts()
        return info
    }

    /// |InstantAmperage (mA)| x Voltage (mV) from the AppleSmartBattery registry entry.
    private static func smartBatteryWatts() -> Double? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        func number(_ key: String) -> Double? {
            let value = IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue() as? NSNumber
            return value.map { Double($0.int64Value) } // amperage is a negative value stored unsigned
        }
        guard let milliamps = number("InstantAmperage"), let millivolts = number("Voltage") else { return nil }
        return abs(milliamps) * millivolts / 1e6
    }
}
