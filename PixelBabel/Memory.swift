import SwiftUI

struct Memory {

    static func system() -> String {
        let systemMB: Double = Memory._systemMB()
        if systemMB >= 1024.0 {
            let systemGB: Double = systemMB / 1024.0
            return "\(Int(round(systemGB))) GB"
        } else {
            return "\(Int(round(systemMB))) MB"
        }
    }

    static func _systemMB() -> Double {
        return Double(ProcessInfo.processInfo.physicalMemory) / (1024 * 1024)
    }

    static func app(percent: Bool = false) -> String {
        let appMB: Double = Memory._appMB()
        if (!percent) {
            if appMB >= 1024.0 {
                let appGB: Double = appMB / 1024.0
                return "\(Int(round(appGB))) GB"
            } else {
                return "\(Int(round(appMB))) MB"
            }
        }
        else {
            let systemMB: Double = Memory._systemMB()
            let appPercent: Double = appMB / systemMB * 100.0
            return "\(Int(round(appPercent)))%"
        }
    }

    static func _appMB() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let result: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        return (result == KERN_SUCCESS) ? Double(info.resident_size) / (1024 * 1024) : Double(0)
    }
}
