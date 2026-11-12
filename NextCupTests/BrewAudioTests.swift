import AVFoundation
import Testing

@testable import NextCup

@MainActor
@Suite("Brew audio")
struct BrewAudioTests {
  @Test func everyBundledTrackOpens() throws {
    #expect(BrewAudio.tracks.count == 18)
    for url in BrewAudio.tracks {
      let name = url.deletingPathExtension().lastPathComponent
      #expect(BrewAudio.titles[name] != nil, "\(name) has a title")
      let player = try AVAudioPlayer(contentsOf: url)
      #expect(player.duration > 120, "\(url.lastPathComponent) is a full track")
    }
  }

  /// Without the audio background mode, iOS silences the music as soon as the app is closed.
  @Test func musicKeepsPlayingWithTheAppClosed() {
    let modes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String]
    #expect(modes?.contains("audio") == true)
  }

  @Test func musicResumesOnlyWhenTheSystemSaysSo() {
    let ended = AVAudioSession.InterruptionType.ended.rawValue
    let began = AVAudioSession.InterruptionType.began.rawValue
    let resume = AVAudioSession.InterruptionOptions.shouldResume.rawValue
    #expect(
      BrewAudio.resumesAfter([
        AVAudioSessionInterruptionTypeKey: ended, AVAudioSessionInterruptionOptionKey: resume,
      ]))
    // Evaluated outside #expect: the macro reported a negated call on a dictionary literal as failed.
    let withoutGoAhead = BrewAudio.resumesAfter([
      AVAudioSessionInterruptionTypeKey: ended, AVAudioSessionInterruptionOptionKey: UInt(0),
    ])
    #expect(!withoutGoAhead)
    #expect(!BrewAudio.resumesAfter([AVAudioSessionInterruptionTypeKey: began]))
    #expect(!BrewAudio.resumesAfter(nil))
  }
}
