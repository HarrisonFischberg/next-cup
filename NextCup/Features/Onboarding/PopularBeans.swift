import Foundation

/// Coffees to pick from during set-up: widely sold, long-running retail coffees from popular
/// roasters (names only), then every coffee in the bundled roaster catalog. Line-ups change;
/// a picked bean is an ordinary bean the user can edit.
enum PopularBeans {
  struct Entry: Hashable, Identifiable, Sendable {
    let roaster: String
    let coffee: String
    var id: String { roaster + "|" + coffee }
  }

  static var all: [Entry] {
    let catalog = (RoasterCatalog.shared?.roasters ?? []).flatMap { roaster in
      roaster.coffees.map { Entry(roaster: roaster.name, coffee: $0.name) }
    }
    var seen = Set<String>()
    return (retail + catalog).filter { seen.insert($0.id).inserted }
  }

  /// Matches the roaster or coffee name, ignoring case and accents.
  static func search(_ term: String) -> [Entry] {
    let clean = term.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !clean.isEmpty else { return all }
    return all.filter {
      $0.roaster.localizedStandardContains(clean) || $0.coffee.localizedStandardContains(clean)
    }
  }

  private static func list(_ roaster: String, _ coffees: String...) -> [Entry] {
    coffees.map { Entry(roaster: roaster, coffee: $0) }
  }

  private static let retail: [Entry] = [
    list(
      "Starbucks", "Pike Place Roast", "Veranda Blend", "Espresso Roast", "Sumatra", "French Roast",
      "House Blend", "Caffè Verona"),
    list(
      "Peet's Coffee", "Major Dickason's Blend", "Big Bang", "House Blend", "French Roast",
      "Café Domingo"),
    list("Dunkin'", "Original Blend", "Dunkin' Midnight"),
    list("Folgers", "Classic Roast", "Black Silk"),
    list("Maxwell House", "Original Roast"),
    list("Lavazza", "Super Crema", "Qualità Rossa", "Crema e Gusto"),
    list("illy", "Classico", "Intenso", "Forte"),
    list("Kicking Horse Coffee", "Kick Ass", "Three Sisters", "454 Horse Power", "Smart Ass"),
    list("Death Wish Coffee", "Dark Roast", "Medium Roast", "Espresso Roast"),
    list("Caribou Coffee", "Caribou Blend", "Daybreak Morning Blend", "Mahogany"),
    list("Tim Hortons", "Original Blend", "Dark Roast"),
    list("Eight O'Clock Coffee", "The Original"),
    list("Green Mountain Coffee", "Breakfast Blend", "Nantucket Blend"),
    list("Community Coffee", "Dark Roast"),
    list("Café Bustelo", "Espresso Style"),
    list("Kirkland Signature", "House Blend", "Colombian Supremo"),
    list("Black Rifle Coffee", "Silencer Smooth", "Beyond Black"),
    list("Seattle's Best Coffee", "Portside Blend"),
    list("Bulletproof", "The Original"),
    list("Mayorga", "Café Cubano"),
    list("Philz Coffee", "Philtered Soul", "Tesora"),
    list("Stumptown", "Hair Bender", "Holler Mountain", "Founder's Blend", "Homestead"),
    list(
      "Intelligentsia", "Black Cat Classic Espresso", "House Blend", "El Gallo", "Frequency Blend"),
    list("Counter Culture Coffee", "Big Trouble", "Hologram", "Fast Forward", "Apollo"),
    list("Blue Bottle", "Bella Donovan", "Giant Steps", "Hayes Valley Espresso", "Three Africas"),
    list("Onyx Coffee Lab", "Southern Weather", "Monarch", "Geometry"),
    list("Verve Coffee Roasters", "Streetlevel", "Sermon"),
    list("La Colombe", "Corsica", "Nizza", "Lyon"),
    list("Heart Coffee Roasters", "Stereo"),
    list("Sightglass", "Owl's Howl Espresso", "Blueboon"),
    list("Equator Coffees", "Tigerwalk Espresso"),
    list("Olympia Coffee", "Big Truck Espresso"),
    list("Klatch Coffee", "Belle Espresso"),
    list("49th Parallel", "Epic Espresso"),
    list("Square Mile Coffee", "Red Brick", "Sweetshop"),
    list("Union Hand-Roasted", "Revelation"),
    list("Has Bean", "Jailbreak"),
    list("Taylors of Harrogate", "Rich Italian", "Hot Lava Java"),
    list("Allpress Espresso", "Espresso Blend"),
    list("Kimbo", "Espresso Napoletano"),
    list("Segafredo Zanetti", "Intermezzo"),
    list("Jacobs", "Krönung"),
    list("Tchibo", "Feine Milde"),
    list("Dallmayr", "Prodomo"),
    list("Douwe Egberts", "Aroma Rood"),
    list("Melitta", "Auslese"),
    list("Paulig", "Juhla Mokka"),
    list("Gevalia", "Mellanrost"),
    list("Zoégas", "Skånerost"),
    list("Campos Coffee", "Superior Blend"),
    list("Single O", "Reservoir"),
    list("St. ALi", "Orchestra"),
    list("Juan Valdez", "Cumbre"),
  ].flatMap { $0 }
}
