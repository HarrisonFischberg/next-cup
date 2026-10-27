import AVFoundation
import Testing

@testable import NextCup

@MainActor
@Suite("Brew audio")
struct BrewAudioTests {
  @Test func everyBundledTrackOpens() throws {
    #expect(BrewAudio.tracks.count == 5)
    for url in BrewAudio.tracks {
      let player = try AVAudioPlayer(contentsOf: url)
      #expect(player.duration > 120, "\(url.lastPathComponent) is a full track")
    }
  }
}
