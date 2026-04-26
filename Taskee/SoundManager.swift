//
//  SoundManager.swift
//  Taskee
//

import AVFoundation

final class SoundManager {
    static let shared = SoundManager()
    private var player: AVAudioPlayer?

    private lazy var cheerURL: URL? = {
        generateCheerWAV()
    }()

    func playApplause() {
        guard let url = cheerURL else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: .mixWithOthers)
            try AVAudioSession.sharedInstance().setActive(true)
            player = try AVAudioPlayer(contentsOf: url)
            player?.volume = 0.75
            player?.play()
        } catch {}
    }

    private func brassTone(_ t: Double, freq: Double) -> Double {
        let f = freq
        let h1 = sin(2.0 * .pi * f * t)
        let h2 = 0.6 * sin(2.0 * .pi * f * 2.0 * t)
        let h3 = 0.35 * sin(2.0 * .pi * f * 3.0 * t)
        let h4 = 0.2 * sin(2.0 * .pi * f * 4.0 * t)
        let h5 = 0.1 * sin(2.0 * .pi * f * 5.0 * t)
        return (h1 + h2 + h3 + h4 + h5) / 2.25
    }

    private func noteEnvelope(t: Double, start: Double, attack: Double, sustain: Double, release: Double) -> Double {
        let elapsed = t - start
        guard elapsed >= 0 else { return 0 }
        let total = attack + sustain + release
        guard elapsed < total else { return 0 }

        if elapsed < attack {
            return elapsed / attack
        } else if elapsed < attack + sustain {
            return 1.0
        } else {
            let releaseT = elapsed - attack - sustain
            return max(0, 1.0 - releaseT / release)
        }
    }

    private func generateCheerWAV() -> URL? {
        let sampleRate = 44100
        let duration = 2.0
        let numSamples = Int(Double(sampleRate) * duration)

        // Fanfare melody: ascending C major arpeggio → triumphant sustain
        // C5=523, E5=659, G5=784, C6=1047
        struct Note {
            let freq: Double
            let start: Double
            let attack: Double
            let sustain: Double
            let release: Double
            let volume: Double
        }

        let melody: [Note] = [
            // Quick ascending arpeggio
            Note(freq: 523.25, start: 0.0,  attack: 0.02, sustain: 0.12, release: 0.08, volume: 0.5),
            Note(freq: 659.25, start: 0.18, attack: 0.02, sustain: 0.12, release: 0.08, volume: 0.55),
            Note(freq: 783.99, start: 0.36, attack: 0.02, sustain: 0.12, release: 0.08, volume: 0.6),
            // Triumphant sustained chord
            Note(freq: 1046.50, start: 0.55, attack: 0.04, sustain: 0.7,  release: 0.65, volume: 0.7),
            Note(freq: 783.99,  start: 0.55, attack: 0.04, sustain: 0.65, release: 0.6,  volume: 0.45),
            Note(freq: 659.25,  start: 0.55, attack: 0.04, sustain: 0.6,  release: 0.55, volume: 0.35),
            Note(freq: 523.25,  start: 0.55, attack: 0.04, sustain: 0.55, release: 0.5,  volume: 0.25),
        ]

        // Snare-like hit at the chord entrance
        var rng = RandomNumberGenerator_LCG(seed: 99)
        var noise = [Double](repeating: 0, count: numSamples)
        for i in 0..<numSamples {
            noise[i] = Double.random(in: -1.0...1.0, using: &rng)
        }

        var audioData = Data()
        audioData.reserveCapacity(numSamples * 2)

        for i in 0..<numSamples {
            let t = Double(i) / Double(sampleRate)
            var sample = 0.0

            // Melody/brass layer
            for note in melody {
                let env = noteEnvelope(t: t, start: note.start, attack: note.attack, sustain: note.sustain, release: note.release)
                if env > 0 {
                    sample += brassTone(t - note.start, freq: note.freq) * env * note.volume
                }
            }

            // Percussion hit at 0.55s (chord entrance)
            let hitEnv = noteEnvelope(t: t, start: 0.54, attack: 0.005, sustain: 0.01, release: 0.12)
            sample += noise[i] * hitEnv * 0.4

            // Soft shimmer/cymbal wash over the sustained chord
            let shimmerEnv = noteEnvelope(t: t, start: 0.56, attack: 0.1, sustain: 0.5, release: 0.7)
            sample += noise[i] * shimmerEnv * 0.08

            // Master limiter
            sample = max(-1.0, min(1.0, sample))

            let value = Int16(clamping: Int(sample * 24000))
            var le = value.littleEndian
            audioData.append(Data(bytes: &le, count: 2))
        }

        var wav = Data()
        let dataSize = UInt32(audioData.count)
        let fileSize = UInt32(36 + audioData.count)

        wav.append(contentsOf: [0x52, 0x49, 0x46, 0x46]) // RIFF
        appendLE(&wav, fileSize)
        wav.append(contentsOf: [0x57, 0x41, 0x56, 0x45]) // WAVE
        wav.append(contentsOf: [0x66, 0x6D, 0x74, 0x20]) // fmt
        appendLE(&wav, UInt32(16))
        appendLE(&wav, UInt16(1))                          // PCM
        appendLE(&wav, UInt16(1))                          // mono
        appendLE(&wav, UInt32(sampleRate))
        appendLE(&wav, UInt32(sampleRate * 2))             // byte rate
        appendLE(&wav, UInt16(2))                          // block align
        appendLE(&wav, UInt16(16))                         // bits per sample
        wav.append(contentsOf: [0x64, 0x61, 0x74, 0x61]) // data
        appendLE(&wav, dataSize)
        wav.append(audioData)

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("cheer.wav")
        try? wav.write(to: url)
        return url
    }

    private func appendLE<T: FixedWidthInteger>(_ data: inout Data, _ value: T) {
        var le = value.littleEndian
        data.append(Data(bytes: &le, count: MemoryLayout<T>.size))
    }
}

private struct RandomNumberGenerator_LCG: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}
