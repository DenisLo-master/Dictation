import CoreGraphics
import Foundation

public enum AudioLevelMeter {
    public static func normalizedLevel(averagePower: Float, peakPower: Float) -> CGFloat {
        guard averagePower.isFinite, peakPower.isFinite else { return 0 }

        let average = decibelToUnit(averagePower, noiseFloor: -62, ceiling: -8)
        let peak = decibelToUnit(peakPower, noiseFloor: -52, ceiling: -4)
        let mixed = average * 0.68 + peak * 0.32
        let gated = max(0, (mixed - 0.055) / 0.945)

        return max(0, min(1, pow(gated, 0.92) * 0.96))
    }

    private static func decibelToUnit(_ power: Float, noiseFloor: Float, ceiling: Float) -> CGFloat {
        let clamped = max(noiseFloor, min(ceiling, power))
        return CGFloat((clamped - noiseFloor) / (ceiling - noiseFloor))
    }
}

public struct VoiceLevelHistory {
    public private(set) var levels: [CGFloat]

    private var envelope: CGFloat
    private var previousLevel: CGFloat
    private let floor: CGFloat
    private let profiles: [CGFloat]
    private let transientProfiles: [CGFloat]

    public init(columnCount: Int, floor: CGFloat = 0) {
        let count = max(1, columnCount)
        self.floor = max(0, min(1, floor))
        self.envelope = self.floor
        self.previousLevel = self.floor
        self.levels = Array(repeating: self.floor, count: count)
        self.profiles = Self.makeProfiles(count: count, phase: 0.0)
        self.transientProfiles = Self.makeProfiles(count: count, phase: 0.41)
    }

    public mutating func reset(to level: CGFloat = 0.02) {
        let clamped = max(0, min(1, level))
        envelope = clamped
        previousLevel = clamped
        levels = Array(repeating: clamped, count: levels.count)
    }

    public mutating func push(_ rawLevel: CGFloat) -> [CGFloat] {
        let clamped = max(0, min(1, rawLevel))
        let level = clamped < 0.025 ? 0 : clamped
        let envelopeRate: CGFloat = level > envelope ? 0.82 : 0.38
        envelope += (level - envelope) * envelopeRate

        let transient = max(0, level - previousLevel)
        previousLevel = level

        let base = pow(envelope, 0.78)
        for index in levels.indices {
            let shaped = base * (0.26 + profiles[index] * 0.76)
            let accent = transient * (0.34 + transientProfiles[index] * 0.58)
            let target = max(floor, min(1, shaped + accent))
            let rate: CGFloat
            if target > levels[index] {
                rate = 0.94
            } else if level <= 0.001 {
                rate = 0.72
            } else {
                rate = 0.52
            }
            levels[index] += (target - levels[index]) * rate
        }

        return levels
    }

    private static func makeProfiles(count: Int, phase: CGFloat) -> [CGFloat] {
        (0..<count).map { index in
            let position = CGFloat(index) / CGFloat(max(1, count - 1))
            let waveA = (sin(position * .pi * 5.4 + phase) + 1) * 0.5
            let waveB = (sin(position * .pi * 13.0 + phase * 2.3) + 1) * 0.5
            return min(1, max(0.34, waveA * 0.48 + waveB * 0.18 + 0.18))
        }
    }
}
