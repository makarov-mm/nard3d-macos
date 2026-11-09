/// The four looks of the board and the room.
enum Themes {
    static let all = [classic(), oriental(), tournament(), night()]

    /// A walnut box with a light field, dark and red points, ivory and ebony checkers.
    private static func classic() -> Theme {
        var t = Theme(englishName: "Classic", russianName: "Классика",
                      field: SIMD3(0.42, 0.25, 0.11), fieldRoughness: 0.4, fieldSeed: 0.37,
                      pointA: SIMD3(0.05, 0.025, 0.013), pointB: SIMD3(0.3, 0.055, 0.025),
                      line: SIMD3(0.95, 0.7, 0.35),
                      wood: SIMD3(0.11, 0.05, 0.022), woodSeed: 0.61,
                      felt: SIMD3(0.02, 0.075, 0.035),
                      table: SIMD3(0.07, 0.04, 0.022), tableRoughness: 0.4,
                      checkers: [CheckerLook(color: SIMD3(0.72, 0.6, 0.42), roughness: 0.3, pattern: 1, ornament: 0.5),
                                 CheckerLook(color: SIMD3(0.035, 0.022, 0.016), roughness: 0.25, pattern: 1, ornament: 0.5)],
                      die: SIMD3(0.82, 0.76, 0.63), dieRoughness: 0.3,
                      pip: SIMD3(0.02, 0.018, 0.016),
                      keyDirection: SIMD3(0.15, 1.0, 0.3), keyRadiance: SIMD3(4.6, 4.35, 3.9),
                      ceiling: SIMD3(0.012, 0.011, 0.01), horizon: SIMD3(0.035, 0.028, 0.02), ground: SIMD3(0.012, 0.01, 0.008),
                      diffuseLight: 0.85, background: 0.4,
                      fog: SIMD3(0.012, 0.01, 0.008), exposure: 0.95,
                      accent: SIMD3(0.3, 0.8, 1.0), hint: SIMD3(0.5, 1.0, 0.35))
        t.light(lamp: SIMD3(8.6, 8.0, 7.0), fill: SIMD3(0.13, 0.11, 0.09))
        return t
    }

    /// Red leather with cream and green points and a gold line, a lacquered box, bone and onyx, a carpet under it.
    private static func oriental() -> Theme {
        var t = Theme(englishName: "Oriental", russianName: "Восток",
                      field: SIMD3(0.16, 0.025, 0.02), fieldRoughness: 0.55, fieldPattern: 2, fieldSeed: 0.2, fieldClearcoat: 0.2,
                      pointA: SIMD3(0.6, 0.48, 0.3), pointB: SIMD3(0.015, 0.07, 0.045), pointRoughness: 0.5, lineWidth: 0.0008,
                      line: SIMD3(1.0, 0.75, 0.32),
                      wood: SIMD3(0.075, 0.022, 0.012), woodRoughness: 0.25, woodClearcoat: 1.0, woodSeed: 0.18,
                      felt: SIMD3(0.12, 0.015, 0.015),
                      table: SIMD3(0.09, 0.018, 0.016), tableRoughness: 0.9, tablePattern: 1,
                      checkers: [CheckerLook(color: SIMD3(0.78, 0.71, 0.57), roughness: 0.35, clearcoat: 0.5, pattern: 3, ornament: 0.8),
                                 CheckerLook(color: SIMD3(0.03, 0.035, 0.04), roughness: 0.12, clearcoat: 0.9, pattern: 2, ornament: 0.8)],
                      die: SIMD3(0.85, 0.79, 0.66), dieRoughness: 0.35,
                      pip: SIMD3(0.25, 0.03, 0.02),
                      keyDirection: SIMD3(0.2, 1.0, 0.25), keyRadiance: SIMD3(4.7, 4.2, 3.5),
                      ceiling: SIMD3(0.012, 0.009, 0.006), horizon: SIMD3(0.04, 0.026, 0.014), ground: SIMD3(0.014, 0.008, 0.006),
                      diffuseLight: 0.85, background: 0.4,
                      fog: SIMD3(0.014, 0.009, 0.006), exposure: 1.0,
                      accent: SIMD3(1.0, 0.75, 0.3), hint: SIMD3(0.25, 0.95, 0.85))
        t.light(lamp: SIMD3(8.6, 7.6, 6.2), fill: SIMD3(0.15, 0.1, 0.06))
        return t
    }

    /// Green felt with cream and burgundy points, black lacquer, white and black checkers, red precision dice.
    private static func tournament() -> Theme {
        var t = Theme(englishName: "Tournament", russianName: "Турнир",
                      field: SIMD3(0.02, 0.09, 0.045), fieldRoughness: 0.9, fieldPattern: 1, fieldClearcoat: 0,
                      pointA: SIMD3(0.62, 0.56, 0.44), pointB: SIMD3(0.2, 0.02, 0.03), pointRoughness: 0.85, lineWidth: 0,
                      line: SIMD3(0.6, 0.6, 0.6),
                      wood: SIMD3(0.012, 0.012, 0.014), woodRoughness: 0.25, woodClearcoat: 0.7, woodPattern: 1,
                      felt: SIMD3(0.02, 0.08, 0.04),
                      table: SIMD3(0.07, 0.07, 0.075), tableRoughness: 0.45, tablePattern: 2, tableSeed: 0.4,
                      checkers: [CheckerLook(color: SIMD3(0.8, 0.78, 0.72), roughness: 0.2, clearcoat: 0.9, ornament: 0.25),
                                 CheckerLook(color: SIMD3(0.02, 0.02, 0.024), roughness: 0.18, clearcoat: 0.9, ornament: 0.25)],
                      die: SIMD3(0.45, 0.02, 0.025), dieRoughness: 0.12,
                      pip: SIMD3(0.85, 0.85, 0.85),
                      keyDirection: SIMD3(0.1, 1.0, 0.2), keyRadiance: SIMD3(5.0, 5.0, 5.1), keySoftness: 0.2,
                      ceiling: SIMD3(0.012, 0.013, 0.016), horizon: SIMD3(0.03, 0.032, 0.04), ground: SIMD3(0.01, 0.01, 0.012),
                      diffuseLight: 0.9, background: 0.4,
                      fog: SIMD3(0.01, 0.011, 0.014), exposure: 1.0,
                      accent: SIMD3(0.4, 0.8, 1.0), hint: SIMD3(1.0, 0.7, 0.25))
        t.light(lamp: SIMD3(9.2, 9.2, 9.4), fill: SIMD3(0.1, 0.11, 0.14))
        return t
    }

    /// Dark leather and slate points with a silver line, pearl and black stone, a cool dim room.
    private static func night() -> Theme {
        var t = Theme(englishName: "Night", russianName: "Ночь",
                      field: SIMD3(0.018, 0.022, 0.03), fieldRoughness: 0.5, fieldPattern: 2, fieldSeed: 0.8, fieldClearcoat: 0.3,
                      pointA: SIMD3(0.05, 0.1, 0.17), pointB: SIMD3(0.16, 0.17, 0.19), pointRoughness: 0.4,
                      line: SIMD3(0.75, 0.8, 0.85),
                      wood: SIMD3(0.02, 0.02, 0.025), woodRoughness: 0.2, woodClearcoat: 1.0, woodPattern: 1,
                      felt: SIMD3(0.012, 0.03, 0.05),
                      table: SIMD3(0.012, 0.014, 0.02), tableRoughness: 0.9, tablePattern: 1,
                      checkers: [CheckerLook(color: SIMD3(0.7, 0.73, 0.78), roughness: 0.15, clearcoat: 1.0, pattern: 2, ornament: 0.6),
                                 CheckerLook(color: SIMD3(0.012, 0.013, 0.016), roughness: 0.12, clearcoat: 1.0, pattern: 2, ornament: 0.6)],
                      die: SIMD3(0.03, 0.03, 0.035), dieRoughness: 0.15,
                      pip: SIMD3(0.3, 0.85, 1.0),
                      keyDirection: SIMD3(0.08, 1.0, 0.18), keyRadiance: SIMD3(3.6, 3.9, 4.4), keySoftness: 0.12,
                      ceiling: SIMD3(0.004, 0.005, 0.01), horizon: SIMD3(0.01, 0.015, 0.03), ground: SIMD3(0.003, 0.004, 0.006),
                      diffuseLight: 1.0, reflectedLight: 1.1, background: 0.5,
                      fog: SIMD3(0.004, 0.006, 0.012), exposure: 1.15, bloom: 0.07, vignette: 0.55,
                      accent: SIMD3(0.2, 0.85, 1.0), hint: SIMD3(0.85, 0.5, 1.0))
        t.light(lamp: SIMD3(6.8, 7.4, 8.4), fill: SIMD3(0.05, 0.08, 0.16))
        // A cool strip of light behind the player.
        t.panels.append(StudioPanel(direction: SIMD3(-0.3, 0.2, 0.93), halfSize: SIMD2(1.0, 0.03), corner: 0.01, softness: 0.02,
                                    radiance: SIMD3(1.0, 3.0, 4.0)))
        return t
    }
}
