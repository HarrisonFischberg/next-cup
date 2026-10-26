import Foundation

// Starting grind ranges for 21 popular grinders, per brew method, in each grinder's own notation.
// Source: Honest Coffee Guide's per-grinder tables (linked per entry), read 2026-10-26; spot-checked
// against Fellow's Ode Gen 2 guide (pour over around 5) and Comandante's 24-click factory filter setting.
// These are starting points: units, burrs and beans differ, so the user dials in from here by taste.
// espresso is nil where the maker positions the grinder for brewed coffee only.

struct GrinderGuide: Identifiable, Hashable {
    let name: String
    let kind: String // Hand or Electric
    /// How the dial reads: clicks, dial, rotations, rotation.number.tick, number.click.
    let notation: String
    let pourOver: String?
    let aeroPress: String?
    let frenchPress: String?
    let moka: String?
    let espresso: String?
    let coldBrew: String?
    let source: String
    var id: String { name }

    /// The range for a brew method name used in the concepts (Cone, Immersion, Press, Espresso, Moka, Cold brew).
    func range(for method: String) -> String? {
        switch method {
        case "Cone", "Immersion": pourOver
        case "Press": frenchPress
        case "Espresso": espresso
        case "Moka": moka
        case "Cold brew": coldBrew
        default: aeroPress
        }
    }

    var unitLabel: String {
        switch notation {
        case "clicks": "clicks"
        case "rotations": "rotations"
        case "rotation.number.tick": "rotation · number · tick"
        case "number.click": "number · click"
        default: "on the dial"
        }
    }

    static let all: [GrinderGuide] = [
        .init(name: "Baratza Encore", kind: "Electric", notation: "dial", pourOver: "7 – 18", aeroPress: "3 – 29", frenchPress: "19 – 40", moka: "5 – 17", espresso: nil, coldBrew: "24 – 40",
              source: "https://honestcoffeeguide.com/baratza-encore-grind-settings/"),
        .init(name: "Fellow Ode Gen 2", kind: "Electric", notation: "dial", pourOver: "2.2 – 5.2", aeroPress: "1.2 – 8.2", frenchPress: "6 – 11", moka: "2 – 5.1", espresso: nil, coldBrew: "7 – 11",
              source: "https://honestcoffeeguide.com/fellow-ode-brew-grinder-gen-2-grind-settings/"),
        .init(name: "Timemore Sculptor 078", kind: "Electric", notation: "dial", pourOver: "1 – 6.5", aeroPress: "0 – 11.5", frenchPress: "6.5 – 18", moka: "0 – 5.5", espresso: nil, coldBrew: "9 – 18",
              source: "https://honestcoffeeguide.com/timemore-sculptor-078-grind-settings/"),
        .init(name: "Turin DF64 Gen 2", kind: "Electric", notation: "dial", pourOver: "23 – 53", aeroPress: "15 – 80", frenchPress: "53 – 90", moka: "19 – 49", espresso: "0 – 20", coldBrew: "65 – 90",
              source: "https://honestcoffeeguide.com/turin-df64-gen-2-grind-settings/"),
        .init(name: "Option-O Lagom Casa 65CL", kind: "Electric", notation: "rotation.number.tick", pourOver: "0.8.5 – 1.4.7", aeroPress: "0.6.8 – 2.0.2", frenchPress: "1.4.6 – 2.7.3", moka: "0.7.6 – 1.3.9", espresso: "0.3.8 – 0.8.0", coldBrew: "1.6.9 – 2.9.5",
              source: "https://honestcoffeeguide.com/option-o-lagom-casa-grind-settings/"),
        .init(name: "Niche Zero", kind: "Electric", notation: "rotations", pourOver: "0.33 – 0.56", aeroPress: "0.26 – 0.77", frenchPress: "0.56 – 1.14", moka: "0.30 – 0.53", espresso: "0.15 – 0.30", coldBrew: "0.65 – 1.23",
              source: "https://honestcoffeeguide.com/niche-zero-grind-settings/"),
        .init(name: "Baratza Vario W+", kind: "Electric", notation: "dial", pourOver: "2T – 6B", aeroPress: "2A – 8T", frenchPress: "6A – 10V", moka: "2J – 5O", espresso: "1A – 2N", coldBrew: "7E – 10V",
              source: "https://honestcoffeeguide.com/baratza-vario-w-plus-grind-settings/"),
        .init(name: "Turin DF54", kind: "Electric", notation: "dial", pourOver: "34 – 67", aeroPress: "24 – 90", frenchPress: "67 – 90", moka: "29 – 62", espresso: "8 – 30", coldBrew: "79 – 90",
              source: "https://honestcoffeeguide.com/turin-df54-grind-settings/"),
        .init(name: "Baratza Virtuoso+", kind: "Electric", notation: "dial", pourOver: "8 – 20", aeroPress: "5 – 30", frenchPress: "20 – 40", moka: "7 – 18", espresso: nil, coldBrew: "24 – 40",
              source: "https://honestcoffeeguide.com/baratza-virtuoso-plus-grind-settings/"),
        .init(name: "Baratza Encore ESP", kind: "Electric", notation: "dial", pourOver: "15 – 25", aeroPress: "8 – 30", frenchPress: "25 – 38", moka: "12 – 24", espresso: "0 – 13", coldBrew: "27 – 40",
              source: "https://honestcoffeeguide.com/baratza-encore-esp-grind-settings/"),
        .init(name: "Eureka Mignon Specialità", kind: "Electric", notation: "rotations", pourOver: "4.5 – 1+4", aeroPress: "2.5 – 2+3", frenchPress: "1+4 – 3+4", moka: "3.5 – 1+3", espresso: "0 – 3.5", coldBrew: "2+0.5 – 4+0",
              source: "https://honestcoffeeguide.com/eureka-mignon-specialita-grind-settings/"),
        .init(name: "1Zpresso K-Ultra", kind: "Hand", notation: "rotation.number.tick", pourOver: "0.5.3 – 0.9.2", aeroPress: "0.4.3 – 1", frenchPress: "0.9.1 – 1", moka: "0.4.8 – 0.8.6", espresso: "0.2.4 – 0.5", coldBrew: "1",
              source: "https://honestcoffeeguide.com/1zpresso-k-ultra-grind-settings/"),
        .init(name: "1Zpresso ZP6 Special", kind: "Hand", notation: "number.click", pourOver: "1.8 – 5.1", aeroPress: "0.9 – 8.0", frenchPress: "5.0 – 9.0", moka: "1.4 – 4.6", espresso: "0.0 – 1.5", coldBrew: "6.3 – 9.0",
              source: "https://honestcoffeeguide.com/1zpresso-zp6-special-grind-settings/"),
        .init(name: "KINGrinder K6", kind: "Hand", notation: "rotations", pourOver: "0.48 – 1.22", aeroPress: "0.38 – 1.53", frenchPress: "1.22 – 2.34", moka: "0.43 – 1.18", espresso: "0.22 – 0.45", coldBrew: "1.35 – 2.40",
              source: "https://honestcoffeeguide.com/kingrinder-k6-grind-settings/"),
        .init(name: "Comandante C40 MK4", kind: "Hand", notation: "clicks", pourOver: "15 – 25", aeroPress: "12 – 35", frenchPress: "26 – 40", moka: "14 – 24", espresso: "7 – 13", coldBrew: "30 – 40",
              source: "https://honestcoffeeguide.com/comandante-c40-mk4-grind-settings/"),
        .init(name: "Pietro Pro Brewing", kind: "Hand", notation: "dial", pourOver: "3.1 – 7.0", aeroPress: "2.0 – 10.0", frenchPress: "7.0 – 10.0", moka: "2.6 – 6.5", espresso: nil, coldBrew: "8.4 – 10.0",
              source: "https://honestcoffeeguide.com/fiorenzato-pietro-b-modal-burrs-grind-settings/"),
        .init(name: "1Zpresso J-Ultra", kind: "Hand", notation: "rotation.number.tick", pourOver: "1.6.3 – 2.8.4", aeroPress: "1.3.1 – 3.9.0", frenchPress: "2.8.1 – 5.0.0", moka: "1.4.7 – 2.6.8", espresso: "0.7.4 – 1.5.4", coldBrew: "3.2.6 – 5.0.0",
              source: "https://honestcoffeeguide.com/1zpresso-j-ultra-grind-settings/"),
        .init(name: "Kinu M47 Phoenix", kind: "Hand", notation: "rotations", pourOver: "2.5 – 4.2", aeroPress: "2 – 5.8", frenchPress: "4.2 – 7.8", moka: "2.2 – 4", espresso: "1.1 – 2.3", coldBrew: "4.9 – 8.5",
              source: "https://honestcoffeeguide.com/kinu-m47-phoenix-grind-settings/"),
        .init(name: "Timemore Chestnut S3", kind: "Hand", notation: "clicks", pourOver: "0.9 – 4.2", aeroPress: "0 – 7.2", frenchPress: "4.2 – 9.0", moka: "0.4 – 3.8", espresso: nil, coldBrew: "5.5 – 9.0",
              source: "https://honestcoffeeguide.com/timemore-s3-grind-settings/"),
        .init(name: "1Zpresso J", kind: "Hand", notation: "rotation.number.tick", pourOver: "1.5.0 – 2.5.2", aeroPress: "1.2.0 – 3.5.1", frenchPress: "2.5.2 – 4.0.0", moka: "1.3.1 – 2.4.1", espresso: "0.6.2 – 1.4.0", coldBrew: "2.9.2 – 4.0.0",
              source: "https://honestcoffeeguide.com/1zpresso-j-grind-settings/"),
        .init(name: "1Zpresso Q Air", kind: "Hand", notation: "rotation.number.tick", pourOver: "1.2.0 – 2.0.1", aeroPress: "0.9.2 – 2.8.0", frenchPress: "2.0.1 – 3.8.0", moka: "1.0.2 – 1.9.1", espresso: "0.5.1 – 1.1.0", coldBrew: "2.3.2 – 4.0.0",
              source: "https://honestcoffeeguide.com/1zpresso-q-air-grind-settings/"),
    ]
}
