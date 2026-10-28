import AVFoundation

/// The brew's sounds: a soft tick each second, a chime at a step change or the target,
/// and café jazz or quiet piano at 20% volume, one bundled track after another. The playback category
/// plays them with the ringer switch off, as a music app does, and mixes with other
/// audio. The tick and chime are made here, so there is no sound file to license.
@MainActor
final class BrewAudio: NSObject, AVAudioPlayerDelegate {
  static let shared = BrewAudio()
  static let tickKey = "nextcup.timer.tick"
  static let musicKey = "nextcup.timer.music"
  static let musicVolume: Float = 0.2
  /// The bundled tracks (`brew-music-*.m4a`), each credited in docs/asset-licenses.md.
  static let tracks: [URL] =
    (Bundle.main.urls(forResourcesWithExtension: "m4a", subdirectory: nil)
    ?? []).filter { $0.lastPathComponent.hasPrefix("brew-music-") }

  private let engine = AVAudioEngine()
  private let node = AVAudioPlayerNode()
  private let tickBuffer = BrewAudio.tone(hz: 1_600, seconds: 0.03, gain: 0.35)
  private let chimeBuffer = BrewAudio.tone(hz: 880, seconds: 0.45, gain: 0.6)
  private var music: AVAudioPlayer?

  private override init() {
    super.init()
    engine.attach(node)
    engine.connect(node, to: engine.mainMixerNode, format: tickBuffer?.format)
  }

  /// Brew sounds, the tick and the music all start on; the timer offers "Tap for sound
  /// and music" to anyone who turned them off. UI tests run silent.
  private static func on(_ key: String) -> Bool {
    let defaults = UserDefaults.standard
    return !AppBootstrap.usesInMemoryStore
      && defaults.object(forKey: SystemTimerHaptics.soundKey) as? Bool ?? true
      && defaults.object(forKey: key) as? Bool ?? true
  }

  /// True when the phone's volume is all the way down, so the screen can ask for it up.
  static var isMuted: Bool { AVAudioSession.sharedInstance().outputVolume < 0.05 }

  func tick() { if Self.on(Self.tickKey) { play(tickBuffer) } }

  func chime() { if Self.on(SystemTimerHaptics.soundKey) { play(chimeBuffer) } }

  /// Starts or resumes the music, unless the user is already listening to something else.
  func playMusic() {
    guard Self.on(Self.musicKey), !Self.tracks.isEmpty,
      !AVAudioSession.sharedInstance().isOtherAudioPlaying, activate()
    else { return }
    if music == nil { load(after: nil) }
    music?.play()
    music?.setVolume(Self.musicVolume, fadeDuration: 1.5)
  }

  /// A random track, never the one that just ended.
  private func load(after ended: URL?) {
    let next = Self.tracks.filter { $0 != ended || Self.tracks.count == 1 }.randomElement()
    music = next.flatMap { try? AVAudioPlayer(contentsOf: $0) }
    music?.delegate = self
    music?.volume = ended == nil ? 0 : Self.musicVolume
  }

  nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
    let ended = player.url
    Task { @MainActor in
      guard self.music?.url == ended else { return }
      self.load(after: ended)
      self.music?.play()
    }
  }

  func pauseMusic() { music?.pause() }

  /// The brew is over or the screen is gone: silence, and hand the audio back.
  func stop() {
    music?.stop()
    music = nil
    node.stop()
    engine.stop()
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
  }

  private func play(_ buffer: AVAudioPCMBuffer?) {
    guard let buffer, activate() else { return }
    if !engine.isRunning { try? engine.start() }
    guard engine.isRunning else { return }
    node.scheduleBuffer(buffer)
    if !node.isPlaying { node.play() }
  }

  private func activate() -> Bool {
    let session = AVAudioSession.sharedInstance()
    do {
      try session.setCategory(.playback, options: [.mixWithOthers])
      try session.setActive(true)
      return true
    } catch {
      return false
    }
  }

  /// A sine that dies away quickly: short and high is a tick, longer and lower a chime.
  private static func tone(hz: Double, seconds: Double, gain: Float) -> AVAudioPCMBuffer? {
    let rate = 44_100.0
    let frames = AVAudioFrameCount(rate * seconds)
    guard let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1),
      let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
      let samples = buffer.floatChannelData?[0]
    else { return nil }
    buffer.frameLength = frames
    for frame in 0..<Int(frames) {
      let t = Double(frame) / rate
      let envelope = exp(-t / (seconds / 5))
      samples[frame] = gain * Float(envelope * sin(2 * .pi * hz * t))
    }
    return buffer
  }
}
