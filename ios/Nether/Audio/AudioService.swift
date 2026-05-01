import Foundation
import AVFoundation

protocol AudioServiceProtocol {
    /// Plays a sound file with the given name and extension.
    /// - Parameters:
    ///   - name: The name of the sound file.
    ///   - ext: The file extension (e.g., "m4a").
    func playSound(named name: String, extension ext: String)
}

/// A service responsible for handling audio playback.
class AudioService: AudioServiceProtocol {
    private var audioPlayer: AVAudioPlayer?
    private let bundle: Bundle

    /// Creates an AudioService.
    /// - Parameter bundle: The bundle used to locate sound resources. Defaults to `.main`.
    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    /// Plays a sound file with the given name and extension.
    /// - Parameters:
    ///   - name: The name of the sound file.
    ///   - ext: The file extension (e.g., "m4a").
    func playSound(named name: String, extension ext: String) {
        if let player = audioPlayer, player.isPlaying {
            return
        }

        guard let url = bundle.url(forResource: name, withExtension: ext) else { return }
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
        } catch {
            print("Error playing sound: \(error.localizedDescription)")
        }
    }
}
