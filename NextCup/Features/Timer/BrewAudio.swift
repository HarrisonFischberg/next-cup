import AVFoundation
import Observation

/// The brew's sounds: a soft clock tick-tock each second, a chime at a step change or the target,
/// and café jazz or quiet piano at 20% volume, one bundled track after another. The playback category
/// plays them with the ringer switch off, as a music app does, and mixes with other
/// audio. The tick and chime are made here, so there is no sound file to license.
@MainActor @Observable
final class BrewAudio: NSObject, AVAudioPlayerDelegate {
  static let shared = BrewAudio()
  static let tickKey = "nextcup.timer.tick"
  static let musicKey = "nextcup.timer.music"
  static let musicVolume: Float = 0.2
  /// The bundled tracks (`brew-music-*.m4a`), each credited in docs/asset-licenses.md.
  static let tracks: [URL] =
    (Bundle.main.urls(forResourcesWithExtension: "m4a", subdirectory: nil)
    ?? []).filter { $0.lastPathComponent.hasPrefix("brew-music-") }

  /// Each track's name as credited in docs/asset-licenses.md.
  static let titles = [
    "brew-music-jazz-at-the-park": "Jazz at the Park",
    "brew-music-army-blues-kellis-number": "Kelli's Number · U.S. Army Blues",
    "brew-music-army-blues-not-on-the-bus": "Not On The Bus · U.S. Army Blues",
    "brew-music-satie-gymnopedie-1": "Gymnopédie No. 1 · Satie",
    "brew-music-chopin-nocturne-op55-1": "Nocturne Op. 55 No. 1 · Chopin",
  ]

  /// The song playing or paused, for the now-playing bar; nil when there is no music.
  private(set) var nowPlaying: String?
  /// True when the user paused the song; the brew resuming leaves it paused.
  private(set) var musicPaused = false

  @ObservationIgnored private let engine = AVAudioEngine()
  @ObservationIgnored private let node = AVAudioPlayerNode()
  @ObservationIgnored private let tickBuffer = BrewAudio.click(gain: 0.16, smoothing: 2)
  @ObservationIgnored private let tockBuffer = BrewAudio.click(gain: 0.11, smoothing: 6)
  /// Alternates tick and tock, as a clock does.
  @ObservationIgnored private var tocks = false
  @ObservationIgnored private let chimeBuffer = BrewAudio.tone(hz: 880, seconds: 0.45, gain: 0.6)
  @ObservationIgnored private var music: AVAudioPlayer?
  /// This brew's shuffled order, so previous goes back to the song before.
  @ObservationIgnored private var playlist: [URL] = []
  @ObservationIgnored private var position = 0

  private override init() {
    super.init()
    engine.attach(node)
    engine.connect(node, to: engine.mainMixerNode, format: tickBuffer?.format)
  }

  /// Brew sounds, the tick and the music all start on; the timer offers "Tap for sound
  /// and music" to anyone who turned them off. UI tests run silent unless they pass
  /// `-brewMusic` to check the now-playing bar.
  private static func on(_ key: String) -> Bool {
    let defaults = UserDefaults.standard
    return
      (!AppBootstrap.usesInMemoryStore
      || ProcessInfo.processInfo.arguments.contains("-brewMusic"))
      && defaults.object(forKey: SystemTimerHaptics.soundKey) as? Bool ?? true
      && defaults.object(forKey: key) as? Bool ?? true
  }

  /// True when the phone's volume is all the way down, so the screen can ask for it up.
  static var isMuted: Bool { AVAudioSession.sharedInstance().outputVolume < 0.05 }

  func tick() {
    guard Self.on(Self.tickKey) else { return }
    play(tocks ? tockBuffer : tickBuffer)
    tocks.toggle()
  }

  func chime() { if Self.on(SystemTimerHaptics.soundKey) { play(chimeBuffer) } }

  /// Starts or resumes the music, unless the user is already listening to something else
  /// or paused the song themselves.
  func playMusic() {
    guard Self.on(Self.musicKey), !Self.tracks.isEmpty, !musicPaused,
      !AVAudioSession.sharedInstance().isOtherAudioPlaying, activate()
    else { return }
    if music == nil {
      playlist = Self.tracks.shuffled()
      load(at: 0, fadeIn: true)
    }
    music?.play()
    music?.setVolume(Self.musicVolume, fadeDuration: 1.5)
  }

  /// The pause button: holds the song until the user plays it again.
  func toggleMusic() {
    guard let music else { return }
    if music.isPlaying {
      music.pause()
      musicPaused = true
    } else {
      musicPaused = false
      playMusic()
    }
  }

  /// Next and previous wrap around the playlist; a paused song stays paused.
  func skip(by step: Int) {
    guard music != nil, !playlist.isEmpty else { return }
    load(at: (position + step + playlist.count) % playlist.count, fadeIn: false)
    if !musicPaused { music?.play() }
  }

  private func load(at index: Int, fadeIn: Bool) {
    music?.stop()
    position = index
    let url = playlist[index]
    music = try? AVAudioPlayer(contentsOf: url)
    music?.delegate = self
    music?.volume = fadeIn ? 0 : Self.musicVolume
    let name = url.deletingPathExtension().lastPathComponent
    nowPlaying = music == nil ? nil : Self.titles[name] ?? name
  }

  nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
    let ended = player.url
    Task { @MainActor in
      guard self.music?.url == ended else { return }
      self.skip(by: 1)
    }
  }

  /// The brew paused: the music waits with it, without counting as the user's pause.
  func pauseMusic() { music?.pause() }

  /// The brew is over or the screen is gone: silence, and hand the audio back.
  func stop() {
    music?.stop()
    music = nil
    nowPlaying = nil
    musicPaused = false
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

  /// A wall clock's tick: a few milliseconds of soft noise dying away, with no pitch to
  /// nag at you. More smoothing makes it duller, which is the tock.
  private static func click(gain: Float, smoothing: Int) -> AVAudioPCMBuffer? {
    let rate = 44_100.0
    let frames = AVAudioFrameCount(rate * 0.025)
    guard let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1),
      let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
      let samples = buffer.floatChannelData?[0]
    else { return nil }
    buffer.frameLength = frames
    var seed: UInt32 = 0x2545_F491
    var window = [Float](repeating: 0, count: smoothing)
    for frame in 0..<Int(frames) {
      // A fixed-seed generator, so every tick sounds the same.
      seed = seed &* 1_664_525 &+ 1_013_904_223
      window[frame % smoothing] = Float(seed >> 8) / Float(1 << 24) * 2 - 1
      let envelope = Float(exp(-Double(frame) / rate / 0.003))
      samples[frame] = gain * envelope * window.reduce(0, +) / Float(smoothing).squareRoot()
    }
    return buffer
  }

  /// A sine that dies away: the chime at a step change.
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
