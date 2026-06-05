import Foundation
import SwiftData

@Model
public final class VoiceProfile {
    @Attribute(.unique) public var id: UUID
    public var voiceIdentifier: String
    public var speedMultiplier: Double
    public var pitchMultiplier: Float
    public var language: String
    
    public init(id: UUID = UUID(), voiceIdentifier: String = "", speedMultiplier: Double = 1.0, pitchMultiplier: Float = 1.0, language: String = "en-US") {
        self.id = id
        self.voiceIdentifier = voiceIdentifier
        self.speedMultiplier = speedMultiplier
        self.pitchMultiplier = pitchMultiplier
        self.language = language
    }
}
