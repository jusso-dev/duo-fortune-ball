import Foundation
import FortuneCore

/// Launch arguments that start the app in a fixed state, for screenshots and
/// UI tests. For example: `-mockFold open -mockQuestion "Will it rain?"`.
///
/// `-mockFold` takes `closed`, `half`, `open` or `tap` (an iPhone without a
/// hinge). A mocked launch uses the original answers in memory, never the
/// saved ones, and a fixed seed so the same answer shows every time.
struct LaunchOptions {
    enum MockFold: String {
        case closed, half, open, tap

        /// Postures to play after launch, starting from closed.
        var script: [FoldPosture] {
            switch self {
            case .closed, .tap: []
            case .half: [.partiallyOpen(angleDegrees: 90)]
            case .open: MockFoldStateService.openingScript
            }
        }
    }

    var mockFold: MockFold?
    var mockQuestion: String?

    /// Reads `-mockFold` and `-mockQuestion` from the launch arguments,
    /// which `UserDefaults` exposes in its argument domain.
    init(defaults: UserDefaults = .standard) {
        mockFold = defaults.string(forKey: "mockFold").flatMap(MockFold.init(rawValue:))
        mockQuestion = defaults.string(forKey: "mockQuestion")
    }
}

extension FortuneModel {
    static let mockSeed: UInt64 = 27

    /// A model in the given mocked fold state, with the question typed.
    static func mocked(_ fold: LaunchOptions.MockFold, question: String?) -> FortuneModel {
        let mock = MockFoldStateService(initial: .closed)
        let service: any FoldStateService = fold == .tap ? UnavailableFoldStateService() : mock
        let model = FortuneModel(
            foldService: service,
            store: InMemoryAnswerSetStore(),
            generator: SeededGenerator(seed: mockSeed)
        )
        if let question { model.send(.questionChanged(question)) }
        for posture in fold.script {
            mock.send(posture)
            model.send(.postureChanged(posture))
        }
        return model
    }
}
