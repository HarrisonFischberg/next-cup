#if DEBUG
  import Foundation

  // Design exploration (branch design/explore, never shipped): launch arguments that pick
  // one of three directions and open the two screens being compared.
  //   -design A|B|C        restyle Start brew and the timer
  //   -designScreen setup|timer   open Balanced cone's Start brew, or start its timer
  //   -designTimerAt <s>   hold the timer at this many seconds
  extension DesignExplore {
    static let screen = argument("-designScreen")
    static let timerAt = argument("-designTimerAt").flatMap(Double.init)
  }
#endif
