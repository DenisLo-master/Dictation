import CoreGraphics
import Foundation

public enum AudioLevelMeter {
    public static func normalizedLevel(averagePower: Float, peakPower: Float) -> CGFloat {
        guard averagePower.isFinite, peakPower.isFinite else { return 0 }

        let average = decibelToUnit(averagePower, noiseFloor: -62, ceiling: -6)
        let peak = decibelToUnit(peakPower, noiseFloor: -52, ceiling: -2)
        let mixed = average * 0.75 + peak * 0.25
        let gated = max(0, (mixed - 0.08) / 0.92)

        return max(0, min(1, pow(gated, 1.28) * 0.96))
    }

    private static func decibelToUnit(_ power: Float, noiseFloor: Float, ceiling: Float) -> CGFloat {
        let clamped = max(noiseFloor, min(ceiling, power))
        return CGFloat((clamped - noiseFloor) / (ceiling - noiseFloor))
    }
}

public struct VoiceLevelHistory {
    public private(set) var levels: [CGFloat]

    private var smoothedLevel: CGFloat
    private let floor: CGFloat

    public init(columnCount: Int, floor: CGFloat = 0) {
        let count = max(1, columnCount)
        self.floor = max(0, min(1, floor))
        self.smoothedLevel = self.floor
        self.levels = Array(repeating: self.floor, count: count)
    }

    public mutating func reset(to level: CGFloat = 0.02) {
        let clamped = max(0, min(1, level))
        smoothedLevel = clamped
        levels = Array(repeating: clamped, count: levels.count)
    }

    public mutating func push(_ rawLevel: CGFloat) -> [CGFloat] {
        let level = max(0, min(1, rawLevel))
        let attack: CGFloat = level > smoothedLevel ? 0.74 : 0.20
        smoothedLevel += (level - smoothedLevel) * attack

        let displayLevel = max(floor, min(1, pow(smoothedLevel, 1.08)))
        levels.removeFirst()
        levels.append(displayLevel)
        return levels
    }
}
