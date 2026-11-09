/// The interface's words in English and Russian. Some have places, marked {}, for values put in them in order.
enum Str {
    case title
    case game, gameLong, gameShort
    case mode, modeComputer, modeTwoPlayers, modeDemo
    case level, level1, level2, level3, level4, level5
    case theme, sound, languageName, autoRoll
    case camera, cameraOverview, cameraTop
    case newGame, undo, roll, hint
    case nameYou, nameComputer, nameWhite, nameBlack
    case turnYou, turnComputer, turnWhite, turnBlack
    case winYou, winComputer, winWhite, winBlack
    case startsYou, startsComputer, startsWhite, startsBlack
    case opening, openingDetail, openingTie
    case rollPrompt, rolling, toPlay, turnDone, thinking, computerMoving, noMoves, noMovesToast, pressNew, demoNext
    case pips, score, pointsOne, pointsMars, pointsKoks
    case history, noTurnsYet, nothingToUndo, enterFirst, headRule, cannotMove, hintText, bar, off
    case footer, controls
    case keyClick, keyDrag, keyDoubleClick, keyRightClick, keyRightDrag, keyWheel
    case helpClick, helpDrag, helpDoubleClick, helpTakeBack, helpRotate, helpZoom, helpRoll, helpHint, helpUndo, helpAutoRoll, helpCamera
    case helpNew, helpGame, helpMode, helpLevel, helpTheme, helpSound, helpLanguage, helpPanel, helpFullScreen, helpClose
    case rules, rulesLong, rulesShort
    case menuAbout, menuHide, menuHideOthers, menuShowAll, menuQuit
    case menuView, menuFullScreen, menuExitFullScreen, menuWindow, menuMinimize, menuZoom, menuHelp, menuGameHelp
    case aboutCredits

    /// The name of a computer level, from 1 to 5.
    static func levelName(_ level: Int) -> Str {
        [.level1, .level2, .level3, .level4, .level5][min(max(level, 1), 5) - 1]
    }

    func text(_ language: Language) -> String {
        let (english, russian) = pair
        return language == .russian ? russian : english
    }

    private var pair: (String, String) {
        switch self {
        case .title: ("3D Nardy", "Нарды 3D")
        case .game: ("Game", "Игра")
        case .gameLong: ("Long nardy", "Длинные нарды")
        case .gameShort: ("Short nardy", "Короткие нарды")
        case .mode: ("Mode", "Режим")
        case .modeComputer: ("Vs computer", "С компьютером")
        case .modeTwoPlayers: ("Two players", "Два игрока")
        case .modeDemo: ("Demo game", "Демонстрация")
        case .level: ("Level", "Уровень")
        case .level1: ("Novice", "Новичок")
        case .level2: ("Beginner", "Начинающий")
        case .level3: ("Amateur", "Любитель")
        case .level4: ("Strong", "Сильный")
        case .level5: ("Master", "Мастер")
        case .theme: ("Theme", "Оформление")
        case .sound: ("Sound", "Звук")
        case .languageName: ("English", "Русский")
        case .autoRoll: ("Auto roll", "Автобросок")
        case .camera: ("View", "Вид")
        case .cameraOverview: ("overview", "обзор")
        case .cameraTop: ("from above", "сверху")
        case .newGame: ("New game", "Новая игра")
        case .undo: ("Undo", "Отменить")
        case .roll: ("Roll", "Бросить кости")
        case .hint: ("Hint", "Подсказка")
        case .nameYou: ("You", "Вы")
        case .nameComputer: ("Computer", "Компьютер")
        case .nameWhite: ("White", "Белые")
        case .nameBlack: ("Black", "Чёрные")
        case .turnYou: ("Your turn", "Ваш ход")
        case .turnComputer: ("Computer's turn", "Ход компьютера")
        case .turnWhite: ("White to play", "Ход белых")
        case .turnBlack: ("Black to play", "Ход чёрных")
        case .winYou: ("You win!", "Вы победили!")
        case .winComputer: ("The computer wins", "Победил компьютер")
        case .winWhite: ("White wins", "Победа белых")
        case .winBlack: ("Black wins", "Победа чёрных")
        case .startsYou: ("You go first", "Вы начинаете")
        case .startsComputer: ("The computer goes first", "Компьютер начинает")
        case .startsWhite: ("White goes first", "Начинают белые")
        case .startsBlack: ("Black goes first", "Начинают чёрные")
        case .opening: ("Who goes first", "Кто начинает")
        case .openingDetail: ("Each player throws one die", "Каждый бросает одну кость")
        case .openingTie: ("A tie, {}:{} — throwing again", "Поровну, {}:{} — бросаем снова")
        case .rollPrompt: ("Roll: Space or click the board", "Бросок: пробел или щелчок по доске")
        case .rolling: ("The dice are rolling…", "Кости катятся…")
        case .toPlay: ("To play: {}", "Сыграть: {}")
        case .turnDone: ("Turn played", "Ход сыгран")
        case .thinking: ("Thinking…", "Думает…")
        case .computerMoving: ("Moving…", "Ходит…")
        case .noMoves: ("no moves", "ходов нет")
        case .noMovesToast: ("No moves — the turn passes", "Ходов нет — ход переходит")
        case .pressNew: ("N or New game to play again", "N — новая игра")
        case .demoNext: ("A new game begins shortly", "Скоро новая партия")
        case .pips: ("Pips {}  ·  Off {}", "Пипсы {}  ·  Сброшено {}")
        case .score: ("Score {} : {}", "Счёт {} : {}")
        case .pointsOne: ("A single game, 1 point", "Обычная победа, 1 очко")
        case .pointsMars: ("Mars, 2 points", "Марс, 2 очка")
        case .pointsKoks: ("Koks, 3 points", "Кокс, 3 очка")
        case .history: ("Moves", "Ходы")
        case .noTurnsYet: ("No moves yet", "Ходов пока нет")
        case .nothingToUndo: ("Nothing to undo", "Нечего отменять")
        case .enterFirst: ("First bring in the checker from the bar", "Сначала введите шашку с бара")
        case .headRule: ("Only one checker may leave the head each turn", "С головы за ход можно снять только одну шашку")
        case .cannotMove: ("That checker cannot move now", "Эта шашка сейчас не может ходить")
        case .hintText: ("Hint: {}", "Подсказка: {}")
        case .bar: ("bar", "бар")
        case .off: ("off", "сброс")
        case .footer: ("F1 help · Tab panel · ⌃⌘F full screen", "F1 справка · Tab панель · ⌃⌘F весь экран")
        case .controls: ("Controls", "Управление")
        case .keyClick: ("Click", "Щелчок")
        case .keyDrag: ("Drag", "Перетаскивание")
        case .keyDoubleClick: ("Double-click", "Двойной щелчок")
        case .keyRightClick: ("Right-click  ⌫", "Правый щелчок  ⌫")
        case .keyRightDrag: ("Right-drag", "Правой кнопкой")
        case .keyWheel: ("Scroll or pinch", "Прокрутка или щипок")
        case .helpClick: ("Choose a checker, then where it goes", "Выбрать шашку, затем куда")
        case .helpDrag: ("Move a checker", "Переставить шашку")
        case .helpDoubleClick: ("Play the higher die", "Сыграть большую кость")
        case .helpTakeBack: ("Take back a step", "Вернуть шаг")
        case .helpRotate: ("Turn the view", "Повернуть вид")
        case .helpZoom: ("Zoom", "Приблизить")
        case .helpRoll: ("Roll the dice; end the turn", "Бросить кости; закончить ход")
        case .helpHint: ("Hint; again to play it", "Подсказка; ещё раз — сыграть её")
        case .helpUndo: ("Undo the turn", "Отменить ход")
        case .helpAutoRoll: ("Roll by itself", "Автобросок")
        case .helpCamera: ("Change or reset the view", "Сменить или вернуть вид")
        case .helpNew: ("New game", "Новая игра")
        case .helpGame: ("Long or short nardy", "Длинные или короткие")
        case .helpMode: ("Mode", "Режим")
        case .helpLevel: ("Computer's level", "Уровень компьютера")
        case .helpTheme: ("Theme", "Оформление")
        case .helpSound: ("Sound on or off", "Звук")
        case .helpLanguage: ("Language", "Язык")
        case .helpPanel: ("Show or hide the panel", "Показать или скрыть панель")
        case .helpFullScreen: ("Full screen", "Весь экран")
        case .helpClose: ("Close this help", "Закрыть справку")
        case .rules: ("Rules", "Правила")
        case .rulesLong:
            ("Long nardy. Each player starts with fifteen checkers on the head, and both run the same way round the board, from the head to "
                + "their home and off. A checker moves the number of each die; a double is played four times. A single checker holds a point: "
                + "you may not land where the opponent stands. Only one checker may leave the head a turn, two on a first roll of 6-6, 4-4 or "
                + "3-3. You may not hold six points in a row unless an opponent's checker is already past them. Play both dice if you can, "
                + "else the higher one. Once all fifteen are home they are borne off; the first to bear off all wins, two points (mars) if the "
                + "opponent has borne off none.",
             "Длинные нарды. У каждого пятнадцать шашек на «голове», и оба игрока идут по доске в одну сторону: от головы к своему дому и "
                + "дальше за доску. Шашка ходит на число очков каждой кости, дубль играется четыре раза. Одна шашка уже занимает пункт: туда, "
                + "где стоит соперник, ходить нельзя. С головы за ход снимается одна шашка, а в первый ход при 6-6, 4-4 и 3-3 — две. Нельзя "
                + "ставить шесть пунктов подряд, если впереди них нет ни одной шашки соперника. Нужно сыграть обе кости, если можно, иначе "
                + "большую. Когда все пятнадцать в доме, их выбрасывают; кто первым выбросил все — победил, а если у соперника нет ни одной "
                + "выброшенной — марс, два очка.")
        case .rulesShort:
            ("Short nardy (backgammon). The players run toward each other. A checker moves the number of each die; a double is played four "
                + "times. A point with two or more opposing checkers is closed; a lone checker may be hit, and goes to the bar, from where it "
                + "must enter the opponent's home before any other checker moves. Play both dice if you can, else the higher one. Once all "
                + "fifteen are home they are borne off. A win is one point, mars (the opponent has borne off none) two, koks (and still has a "
                + "checker on the bar or in the winner's home) three.",
             "Короткие нарды (бэкгаммон). Игроки идут навстречу друг другу. Шашка ходит на число очков каждой кости, дубль играется четыре "
                + "раза. Пункт, где стоят две шашки соперника и больше, закрыт; одиночную шашку можно побить — она уходит на бар, и прежде "
                + "чем ходить другими, её нужно ввести в дом соперника. Нужно сыграть обе кости, если можно, иначе большую. Когда все "
                + "пятнадцать в доме, их выбрасывают. Победа — одно очко, марс (у соперника нет ни одной выброшенной) — два, кокс (и вдобавок "
                + "его шашка на баре или в доме победителя) — три.")
        case .menuAbout: ("About 3D Nardy", "Об игре «Нарды 3D»")
        case .menuHide: ("Hide 3D Nardy", "Скрыть «Нарды 3D»")
        case .menuHideOthers: ("Hide Others", "Скрыть остальные")
        case .menuShowAll: ("Show All", "Показать все")
        case .menuQuit: ("Quit 3D Nardy", "Завершить «Нарды 3D»")
        case .menuView: ("View", "Вид")
        case .menuFullScreen: ("Enter Full Screen", "Войти в полноэкранный режим")
        case .menuExitFullScreen: ("Exit Full Screen", "Выйти из полноэкранного режима")
        case .menuWindow: ("Window", "Окно")
        case .menuMinimize: ("Minimize", "Свернуть")
        case .menuZoom: ("Zoom", "Изменить масштаб")
        case .menuHelp: ("Help", "Справка")
        case .menuGameHelp: ("3D Nardy Help", "Справка «Нарды 3D»")
        case .aboutCredits:
            ("Long and short nardy, with a computer opponent of five levels that taught itself by playing millions of games. Written in Swift "
                + "on Metal, with no engine or library.",
             "Длинные и короткие нарды, компьютерный соперник пяти уровней, обученный на миллионах партий с самим собой. Написано на Swift и "
                + "Metal, без движка и библиотек.")
        }
    }
}
