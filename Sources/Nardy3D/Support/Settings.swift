import Foundation

/// The choices, the score and the game in progress, kept between sessions in the user defaults. The window keeps its
/// own frame.
struct Settings {
    var theme = 0
    var level = 3
    var mode = 0
    /// Long or short nardy.
    var game = 0
    /// Overview or from above.
    var camera = 0
    var autoRoll = true
    var sound = true
    var panel = true
    var language = Language.system
    /// White's points and Black's.
    var score = [0, 0]
    /// The position and the turn, as text; see `GameController.savedGame`.
    var match = ""
    /// The lines of the game's history, each after its kind, separated by '|'.
    var history = ""

    private enum Key {
        static let theme = "Theme"
        static let level = "Level"
        static let mode = "Mode"
        static let game = "Game"
        static let camera = "Camera"
        static let autoRoll = "AutoRoll"
        static let scoreWhite = "ScoreWhite"
        static let scoreBlack = "ScoreBlack"
        static let sound = "Sound"
        static let panel = "Panel"
        static let language = "Language"
        static let match = "Match"
        static let history = "History"
    }

    static func load(themeCount: Int) -> Settings {
        let defaults = UserDefaults.standard
        func integer(_ key: String, _ fallback: Int) -> Int { defaults.object(forKey: key) as? Int ?? fallback }
        func clamped(_ key: String, _ fallback: Int, _ low: Int, _ high: Int) -> Int { min(max(integer(key, fallback), low), high) }
        var settings = Settings()
        settings.theme = clamped(Key.theme, 0, 0, themeCount - 1)
        settings.level = clamped(Key.level, 3, 1, 5)
        settings.mode = clamped(Key.mode, 0, 0, 2)
        settings.game = clamped(Key.game, 0, 0, 1)
        settings.camera = clamped(Key.camera, 0, 0, 1)
        settings.autoRoll = integer(Key.autoRoll, 1) != 0
        settings.score = [max(0, integer(Key.scoreWhite, 0)), max(0, integer(Key.scoreBlack, 0))]
        settings.sound = integer(Key.sound, 1) != 0
        settings.panel = integer(Key.panel, 1) != 0
        settings.language = Language(rawValue: integer(Key.language, -1)) ?? Language.system
        settings.match = defaults.string(forKey: Key.match) ?? ""
        settings.history = defaults.string(forKey: Key.history) ?? ""
        return settings
    }

    func save() {
        let defaults = UserDefaults.standard
        defaults.set(theme, forKey: Key.theme)
        defaults.set(level, forKey: Key.level)
        defaults.set(mode, forKey: Key.mode)
        defaults.set(game, forKey: Key.game)
        defaults.set(camera, forKey: Key.camera)
        defaults.set(autoRoll ? 1 : 0, forKey: Key.autoRoll)
        defaults.set(score[0], forKey: Key.scoreWhite)
        defaults.set(score[1], forKey: Key.scoreBlack)
        defaults.set(sound ? 1 : 0, forKey: Key.sound)
        defaults.set(panel ? 1 : 0, forKey: Key.panel)
        defaults.set(language.rawValue, forKey: Key.language)
        defaults.set(match, forKey: Key.match)
        defaults.set(history, forKey: Key.history)
    }
}
