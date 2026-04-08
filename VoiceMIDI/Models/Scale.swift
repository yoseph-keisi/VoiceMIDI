import Foundation

struct Scale {
    enum Preset: String, CaseIterable, Identifiable {
        case chromatic       = "Chromatic"
        case major           = "Major"
        case naturalMinor    = "Natural Minor"
        case harmonicMinor   = "Harmonic Minor"
        case melodicMinor    = "Melodic Minor"
        case majorPentatonic = "Major Pentatonic"
        case minorPentatonic = "Minor Pentatonic"
        case blues           = "Blues"
        case dorian          = "Dorian"
        case mixolydian      = "Mixolydian"
        case phrygian        = "Phrygian"
        case hijaz           = "Hijaz"
        case bayati          = "Bayati"
        case rast            = "Rast"
        case nahawand        = "Nahawand"
        case custom          = "Custom"

        var id: String { rawValue }

        /// Returns the set of pitch classes (0–11) relative to root = 0
        var intervals: Set<Int> {
            switch self {
            case .chromatic:       return [0,1,2,3,4,5,6,7,8,9,10,11]
            case .major:           return [0,2,4,5,7,9,11]
            case .naturalMinor:    return [0,2,3,5,7,8,10]
            case .harmonicMinor:   return [0,2,3,5,7,8,11]
            case .melodicMinor:    return [0,2,3,5,7,9,11]
            case .majorPentatonic: return [0,2,4,7,9]
            case .minorPentatonic: return [0,3,5,7,10]
            case .blues:           return [0,3,5,6,7,10]
            case .dorian:          return [0,2,3,5,7,9,10]
            case .mixolydian:      return [0,2,4,5,7,9,10]
            case .phrygian:        return [0,1,3,5,7,8,10]
            case .hijaz:           return [0,1,4,5,7,8,11]
            case .bayati:          return [0,2,3,5,7,8,10]   // 12-TET approximation (true bayati has quarter tones)
            case .rast:            return [0,2,4,5,7,9,11]   // 12-TET approximation (true rast has quarter tones)
            case .nahawand:        return [0,2,3,5,7,8,11]   // Same as harmonic minor in 12-TET
            case .custom:          return []                  // User-defined — not used directly
            }
        }
    }
}
