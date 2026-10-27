import Foundation

/// A cup's rating is stored as tenths of a point out of 10 (0 to 100); 0 means not rated.
public enum Rating {
  public static let maxTenths = 100

  /// "8" for a whole number, otherwise "7.4".
  public static func text(_ tenths: Int) -> String {
    tenths % 10 == 0 ? "\(tenths / 10)" : String(format: "%.1f", Double(tenths) / 10)
  }

  /// An average, always with one decimal: "7.6".
  public static func text(average tenths: Double) -> String {
    String(format: "%.1f", tenths / 10)
  }
}
