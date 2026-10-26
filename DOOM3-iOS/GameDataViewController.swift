//
//  GameDataViewController.swift
//  DOOM3-iOS
//
//  The first screen. The game's own files (base/, and d3xp/ for Resurrection
//  of Evil) are never bundled: the player copies them from their own copy
//  into the app's Documents folder, which the Files app shows as
//  On My iPhone > DOOM 3. Until they're there, this says exactly what to copy
//  where; once they are, it starts the game.
//

import UIKit

@objc(GameDataViewController)
class GameDataViewController: UIViewController {

    #if _D3XP
    static let gameFolders = ["base", "d3xp"]
    #else
    static let gameFolders = ["base"]
    #endif

    private let titleLabel = UILabel()
    private let bodyLabel = UILabel()
    private let missingLabel = UILabel()
    private let checkButton = UIButton(type: .system)

    static var documentsURL: URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        titleLabel.text = "Game files needed"
        titleLabel.font = .systemFont(ofSize: 28, weight: .bold)
        titleLabel.textColor = .white

        bodyLabel.text = GameDataViewController.instructions()
        bodyLabel.font = .systemFont(ofSize: 17)
        bodyLabel.textColor = UIColor(white: 0.85, alpha: 1)
        bodyLabel.numberOfLines = 0

        missingLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        missingLabel.textColor = UIColor(red: 1, green: 0.35, blue: 0.3, alpha: 1)
        missingLabel.numberOfLines = 0

        checkButton.setTitle("Check Again", for: .normal)
        checkButton.titleLabel?.font = .systemFont(ofSize: 20, weight: .semibold)
        checkButton.setTitleColor(.black, for: .normal)
        checkButton.backgroundColor = UIColor(red: 0.85, green: 0.15, blue: 0.1, alpha: 1)
        checkButton.layer.cornerRadius = 10
        checkButton.contentEdgeInsets = UIEdgeInsets(top: 12, left: 28, bottom: 12, right: 28)
        checkButton.addTarget(self, action: #selector(checkAgain), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [titleLabel, bodyLabel, missingLabel, checkButton])
        stack.axis = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false

        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        view.addSubview(scroll)

        let margins = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: margins.leadingAnchor, constant: 24),
            scroll.trailingAnchor.constraint(equalTo: margins.trailingAnchor, constant: -24),
            scroll.topAnchor.constraint(equalTo: margins.topAnchor, constant: 16),
            scroll.bottomAnchor.constraint(equalTo: margins.bottomAnchor, constant: -16),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor),
        ])

        // Coming back from the Files app checks again by itself.
        NotificationCenter.default.addObserver(self, selector: #selector(checkAgain),
                                               name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        checkAgain()
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }

    @objc func checkAgain() {
        let missing = GameDataViewController.missingFolders()
        if missing.isEmpty {
            NotificationCenter.default.removeObserver(self)
            startGame()
            return
        }
        missingLabel.text = "Not found yet: " + missing.map { "\($0) (needs pak000.pk4)" }.joined(separator: ", ")
    }

    private func startGame() {
        let game = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "GameVC")
        view.window?.rootViewController = game
    }

    private static func instructions() -> String {
        let device = UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
        let app = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "DOOM 3"
        #if _D3XP
        let what = "DOOM 3: Resurrection of Evil needs the files from your own copies of DOOM 3 and the expansion (for example from Steam).\n\n" +
            "Copy everything inside DOOM 3's base folder into this app's base folder, and everything inside the expansion's d3xp folder into its d3xp folder."
        #else
        let what = "DOOM 3 needs the files from your own copy of the game (for example from Steam).\n\n" +
            "Copy everything inside DOOM 3's base folder into this app's base folder."
        #endif
        return what + "\n\nThe folders are in the Files app: On My \(device) > \(app). " +
            "From a computer, Finder (Mac) or iTunes (Windows) can copy them in too, under Files for this app.\n\n" +
            "This is the original 2004 DOOM 3, not the BFG Edition, whose files don't work here."
    }

    /// The game folders that don't hold a pak000.pk4 yet. Also tidies what a
    /// Windows copy brings: a folder or .pk4 named in other letter case
    /// ("Base", "PAK000.PK4") is renamed to the lower case the game looks for,
    /// and missing folders are created so they show up in Files.
    static func missingFolders() -> [String] {
        let fm = FileManager.default
        let docs = documentsURL
        var missing: [String] = []
        for folder in gameFolders {
            let url = docs.appendingPathComponent(folder)
            renameToLowercase(named: folder, in: docs)
            if !fm.fileExists(atPath: url.path) {
                try? fm.createDirectory(at: url, withIntermediateDirectories: true)
            }
            let files = (try? fm.contentsOfDirectory(atPath: url.path)) ?? []
            for file in files where file.lowercased().hasSuffix(".pk4") && file != file.lowercased() {
                renameToLowercase(named: file.lowercased(), in: url)
            }
            if !fm.fileExists(atPath: url.appendingPathComponent("pak000.pk4").path) {
                missing.append(folder)
            }
        }
        return missing
    }

    private static func renameToLowercase(named name: String, in dir: URL) {
        let fm = FileManager.default
        let entries = (try? fm.contentsOfDirectory(atPath: dir.path)) ?? []
        if entries.contains(name) {
            return
        }
        if let other = entries.first(where: { $0.lowercased() == name }) {
            try? fm.moveItem(at: dir.appendingPathComponent(other), to: dir.appendingPathComponent(name))
        }
    }
}
