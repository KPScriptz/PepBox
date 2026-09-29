//
//  SystemStats.swift
//  PepBox
//
//  CPU, GPU, memory, network and disk at a glance. Everything is read from
//  public Mach / IOKit / sysctl APIs; no permissions needed.
//

import SwiftUI
import Darwin
import IOKit

struct SystemSnapshot: Equatable {
    var cpu: Double = 0            // 0...1, all cores
    var gpu: Double? = nil         // 0...1, nil if unavailable
    var memoryUsed: Double = 0     // bytes
    var memoryTotal: Double = 0
    var networkDown: Double = 0    // bytes/s
    var networkUp: Double = 0
    var diskFree: Double = 0       // bytes
    var diskTotal: Double = 0
}

@Observable
final class SystemStatsManager {
    static let shared = SystemStatsManager()

    private(set) var snapshot = SystemSnapshot()
    private var timer: Timer?
    private var watchers = 0

    private var previousCPUTicks: (busy: UInt64, total: UInt64)?
    private var previousNetwork: (down: UInt64, up: UInt64, at: Date)?

    /// Sample every second while at least one view is showing stats.
    func startWatching() {
        watchers += 1
        guard timer == nil else { return }
        sample()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.sample() }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stopWatching() {
        watchers = max(0, watchers - 1)
        guard watchers == 0 else { return }
        timer?.invalidate()
        timer = nil
        previousCPUTicks = nil
        previousNetwork = nil
    }

    private func sample() {
        var next = snapshot
        next.cpu = cpuUsage() ?? next.cpu
        next.gpu = Self.gpuUtilization()
        (next.memoryUsed, next.memoryTotal) = Self.memory()
        (next.networkDown, next.networkUp) = networkRates()
        (next.diskFree, next.diskTotal) = Self.disk()
        snapshot = next
    }

    // MARK: CPU (delta of host ticks between samples)

    private func cpuUsage() -> Double? {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        let user = UInt64(info.cpu_ticks.0), system = UInt64(info.cpu_ticks.1)
        let idle = UInt64(info.cpu_ticks.2), nice = UInt64(info.cpu_ticks.3)
        let busy = user + system + nice, total = busy + idle
        defer { previousCPUTicks = (busy, total) }
        guard let previous = previousCPUTicks, total > previous.total else { return nil }
        return Double(busy - previous.busy) / Double(total - previous.total)
    }

    // MARK: GPU (IOAccelerator "Device Utilization %")

    static func gpuUtilization() -> Double? {
        var iterator = io_iterator_t()
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOAccelerator"), &iterator) == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }
        var best: Double?
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            var properties: Unmanaged<CFMutableDictionary>?
            guard IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS,
                  let dict = properties?.takeRetainedValue() as? [String: Any],
                  let stats = dict["PerformanceStatistics"] as? [String: Any],
                  let percent = stats["Device Utilization %"] as? NSNumber else { continue }
            best = max(best ?? 0, percent.doubleValue / 100)
        }
        return best
    }

    // MARK: Memory (active + wired + compressed, like Activity Monitor's "Memory Used")

    static func memory() -> (used: Double, total: Double) {
        let total = Double(ProcessInfo.processInfo.physicalMemory)
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return (0, total) }
        let page = Double(vm_kernel_page_size)
        let used = (Double(stats.active_count) + Double(stats.wire_count) + Double(stats.compressor_page_count)) * page
        return (min(used, total), total)
    }

    // MARK: Network (bytes on physical interfaces, per second)

    private func networkRates() -> (down: Double, up: Double) {
        var down: UInt64 = 0, up: UInt64 = 0
        var addresses: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addresses) == 0, let first = addresses else { return (0, 0) }
        defer { freeifaddrs(addresses) }
        var pointer: UnsafeMutablePointer<ifaddrs>? = first
        while let current = pointer {
            let name = String(cString: current.pointee.ifa_name)
            if let data = current.pointee.ifa_data, current.pointee.ifa_addr?.pointee.sa_family == UInt8(AF_LINK),
               name.hasPrefix("en") || name.hasPrefix("pdp_ip") {
                let stats = data.assumingMemoryBound(to: if_data.self).pointee
                down += UInt64(stats.ifi_ibytes)
                up += UInt64(stats.ifi_obytes)
            }
            pointer = current.pointee.ifa_next
        }
        let now = Date()
        defer { previousNetwork = (down, up, now) }
        guard let previous = previousNetwork, down >= previous.down, up >= previous.up else { return (0, 0) }
        let seconds = max(0.001, now.timeIntervalSince(previous.at))
        return (Double(down - previous.down) / seconds, Double(up - previous.up) / seconds)
    }

    // MARK: Disk (startup volume, "important usage" free space like Finder)

    static func disk() -> (free: Double, total: Double) {
        let url = URL(fileURLWithPath: "/")
        let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey])
        return (Double(values?.volumeAvailableCapacityForImportantUsage ?? 0), Double(values?.volumeTotalCapacity ?? 0))
    }

    static func formatBytes(_ bytes: Double, perSecond: Bool = false) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = perSecond ? .decimal : .memory
        formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        return formatter.string(fromByteCount: Int64(bytes)) + (perSecond ? "/s" : "")
    }
}

struct SystemStatsNotchView: View {
    var manager: SystemStatsManager

    var body: some View {
        let s = manager.snapshot
        HStack(spacing: 14) {
            gauge("CPU", value: s.cpu, tint: .blue)
            if let gpu = s.gpu { gauge("GPU", value: gpu, tint: .purple) }
            gauge("RAM", value: s.memoryTotal > 0 ? s.memoryUsed / s.memoryTotal : 0, tint: .green,
                  caption: SystemStatsManager.formatBytes(s.memoryUsed))
            VStack(alignment: .leading, spacing: 8) {
                statLine("arrow.down", SystemStatsManager.formatBytes(s.networkDown, perSecond: true), tint: .cyan)
                statLine("arrow.up", SystemStatsManager.formatBytes(s.networkUp, perSecond: true), tint: .orange)
                statLine("internaldrive", "\(SystemStatsManager.formatBytes(s.diskFree)) free", tint: .white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear { manager.startWatching() }
        .onDisappear { manager.stopWatching() }
    }

    private func gauge(_ title: String, value: Double, tint: Color, caption: String? = nil) -> some View {
        VStack(spacing: 4) {
            ZStack {
                Circle().stroke(.white.opacity(0.12), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: min(1, max(0, value)))
                    .stroke(tint, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.4), value: value)
                Text("\(Int((value * 100).rounded()))%")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
            }
            .frame(width: 52, height: 52)
            Text(caption ?? title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
                .lineLimit(1)
        }
    }

    private func statLine(_ icon: String, _ text: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 14)
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1)
        }
    }
}
