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

    private lazy var tingURL: URL? = {
        generateTingWAV()
    }()

    private lazy var pickupURL: URL? = {
        generatePickupWAV()
    }()

    private lazy var reminderBeepURL: URL? = {
        generateReminderBeepWAV()
    }()

    func installNotificationSound() {
        let libDir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
        let soundsDir = libDir.appendingPathComponent("Sounds")
        try? FileManager.default.createDirectory(at: soundsDir, withIntermediateDirectories: true)

        if let src = tingURL {
            let dest = soundsDir.appendingPathComponent("ting.wav")
            if !FileManager.default.fileExists(atPath: dest.path) {
                try? FileManager.default.copyItem(at: src, to: dest)
            }
        }
        if let src = pickupURL {
            let dest = soundsDir.appendingPathComponent("pickup.wav")
            try? FileManager.default.removeItem(at: dest)
            try? FileManager.default.copyItem(at: src, to: dest)
        }
        if let src = reminderBeepURL {
            let dest = soundsDir.appendingPathComponent("reminder.wav")
            try? FileManager.default.removeItem(at: dest)
            try? FileManager.default.copyItem(at: src, to: dest)
        }
    }

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

    func playReminderBeep() {
        guard let url = reminderBeepURL else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: .mixWithOthers)
            try AVAudioSession.sharedInstance().setActive(true)
            player = try AVAudioPlayer(contentsOf: url)
            player?.volume = 0.85
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

    private func bellTone(_ t: Double, freq: Double) -> Double {
        let h1 = sin(2.0 * .pi * freq * t)
        let h2 = 0.5 * sin(2.0 * .pi * freq * 2.0 * t)
        let h3 = 0.25 * sin(2.0 * .pi * freq * 3.0 * t)
        let h4 = 0.12 * sin(2.0 * .pi * freq * 4.5 * t)
        let h5 = 0.06 * sin(2.0 * .pi * freq * 6.0 * t)
        return (h1 + h2 + h3 + h4 + h5) / 1.93
    }

    private func bellEnvelope(t: Double, start: Double, duration: Double) -> Double {
        let elapsed = t - start
        guard elapsed >= 0, elapsed < duration else { return 0 }
        let attack = 0.005
        if elapsed < attack { return elapsed / attack }
        return exp(-elapsed * 4.0 / duration)
    }

    private func generateTingWAV() -> URL? {
        let sampleRate = 44100
        let duration = 1.8
        let numSamples = Int(Double(sampleRate) * duration)

        struct Ting {
            let freq: Double
            let start: Double
            let dur: Double
            let vol: Double
        }

        // "tinggg — ti — tingggg" pattern
        let tings: [Ting] = [
            Ting(freq: 2093.0, start: 0.0,  dur: 0.6, vol: 0.7),   // C7 — long ting
            Ting(freq: 2637.0, start: 0.0,  dur: 0.5, vol: 0.3),   // E7 shimmer
            Ting(freq: 2093.0, start: 0.55, dur: 0.2, vol: 0.45),  // short ti
            Ting(freq: 2637.0, start: 0.85, dur: 0.8, vol: 0.7),   // E7 — long ting
            Ting(freq: 3136.0, start: 0.85, dur: 0.7, vol: 0.35),  // G7 shimmer
        ]

        var audioData = Data()
        audioData.reserveCapacity(numSamples * 2)

        for i in 0..<numSamples {
            let t = Double(i) / Double(sampleRate)
            var sample = 0.0

            for ting in tings {
                let env = bellEnvelope(t: t, start: ting.start, duration: ting.dur)
                if env > 0.001 {
                    sample += bellTone(t - ting.start, freq: ting.freq) * env * ting.vol
                }
            }

            sample = max(-1.0, min(1.0, sample))
            let value = Int16(clamping: Int(sample * 26000))
            var le = value.littleEndian
            audioData.append(Data(bytes: &le, count: 2))
        }

        var wav = Data()
        let dataSize = UInt32(audioData.count)
        let fileSize = UInt32(36 + audioData.count)

        wav.append(contentsOf: [0x52, 0x49, 0x46, 0x46])
        appendLE(&wav, fileSize)
        wav.append(contentsOf: [0x57, 0x41, 0x56, 0x45])
        wav.append(contentsOf: [0x66, 0x6D, 0x74, 0x20])
        appendLE(&wav, UInt32(16))
        appendLE(&wav, UInt16(1))
        appendLE(&wav, UInt16(1))
        appendLE(&wav, UInt32(sampleRate))
        appendLE(&wav, UInt32(sampleRate * 2))
        appendLE(&wav, UInt16(2))
        appendLE(&wav, UInt16(16))
        wav.append(contentsOf: [0x64, 0x61, 0x74, 0x61])
        appendLE(&wav, dataSize)
        wav.append(audioData)

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ting.wav")
        try? wav.write(to: url)
        return url
    }

    private func generatePickupWAV() -> URL? {
        let sampleRate = 44100
        let duration = 2.5
        let numSamples = Int(Double(sampleRate) * duration)

        struct Beep {
            let freq: Double
            let start: Double
            let dur: Double
            let vol: Double
        }

        // Urgent two-tone pattern: high-low-high-low-high, getting louder
        let beeps: [Beep] = [
            Beep(freq: 1318.5, start: 0.0,  dur: 0.15, vol: 0.5),  // E6
            Beep(freq: 987.8,  start: 0.18, dur: 0.15, vol: 0.5),  // B5
            Beep(freq: 1318.5, start: 0.36, dur: 0.15, vol: 0.6),  // E6
            Beep(freq: 987.8,  start: 0.54, dur: 0.15, vol: 0.6),  // B5
            Beep(freq: 1318.5, start: 0.72, dur: 0.15, vol: 0.7),  // E6
            Beep(freq: 987.8,  start: 0.90, dur: 0.15, vol: 0.7),  // B5
            // Final sustained chord
            Beep(freq: 1568.0, start: 1.15, dur: 0.5, vol: 0.75),  // G6
            Beep(freq: 1318.5, start: 1.15, dur: 0.5, vol: 0.5),   // E6
            Beep(freq: 987.8,  start: 1.15, dur: 0.45, vol: 0.35), // B5
        ]

        var audioData = Data()
        audioData.reserveCapacity(numSamples * 2)

        for i in 0..<numSamples {
            let t = Double(i) / Double(sampleRate)
            var sample = 0.0

            for beep in beeps {
                let elapsed = t - beep.start
                guard elapsed >= 0, elapsed < beep.dur else { continue }
                let attack = 0.008
                let env: Double
                if elapsed < attack {
                    env = elapsed / attack
                } else {
                    env = exp(-elapsed * 3.0 / beep.dur)
                }
                let tone = sin(2.0 * .pi * beep.freq * elapsed)
                    + 0.4 * sin(2.0 * .pi * beep.freq * 2.0 * elapsed)
                    + 0.15 * sin(2.0 * .pi * beep.freq * 3.0 * elapsed)
                sample += (tone / 1.55) * env * beep.vol
            }

            sample = max(-1.0, min(1.0, sample))
            let value = Int16(clamping: Int(sample * 28000))
            var le = value.littleEndian
            audioData.append(Data(bytes: &le, count: 2))
        }

        var wav = Data()
        let dataSize = UInt32(audioData.count)
        let fileSize = UInt32(36 + audioData.count)

        wav.append(contentsOf: [0x52, 0x49, 0x46, 0x46])
        appendLE(&wav, fileSize)
        wav.append(contentsOf: [0x57, 0x41, 0x56, 0x45])
        wav.append(contentsOf: [0x66, 0x6D, 0x74, 0x20])
        appendLE(&wav, UInt32(16))
        appendLE(&wav, UInt16(1))
        appendLE(&wav, UInt16(1))
        appendLE(&wav, UInt32(sampleRate))
        appendLE(&wav, UInt32(sampleRate * 2))
        appendLE(&wav, UInt16(2))
        appendLE(&wav, UInt16(16))
        wav.append(contentsOf: [0x64, 0x61, 0x74, 0x61])
        appendLE(&wav, dataSize)
        wav.append(audioData)

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("pickup.wav")
        try? wav.write(to: url)
        return url
    }

    private func generateReminderBeepWAV() -> URL? {
        let sampleRate = 44100
        let duration = 1.2
        let numSamples = Int(Double(sampleRate) * duration)

        struct Beep {
            let freq: Double
            let start: Double
            let dur: Double
            let vol: Double
        }

        // Friendly ascending two-tone: "bee-boop!"
        let beeps: [Beep] = [
            Beep(freq: 880.0,  start: 0.0,  dur: 0.18, vol: 0.65),  // A5
            Beep(freq: 1108.7, start: 0.0,  dur: 0.15, vol: 0.25),  // C#6 shimmer
            Beep(freq: 1174.7, start: 0.22, dur: 0.25, vol: 0.7),   // D6
            Beep(freq: 1480.0, start: 0.22, dur: 0.2,  vol: 0.3),   // F#6 shimmer
            Beep(freq: 1760.0, start: 0.52, dur: 0.35, vol: 0.55),  // A6 - final ring
        ]

        var audioData = Data()
        audioData.reserveCapacity(numSamples * 2)

        for i in 0..<numSamples {
            let t = Double(i) / Double(sampleRate)
            var sample = 0.0

            for beep in beeps {
                let elapsed = t - beep.start
                guard elapsed >= 0, elapsed < beep.dur else { continue }
                let attack = 0.006
                let env: Double
                if elapsed < attack {
                    env = elapsed / attack
                } else {
                    env = exp(-elapsed * 3.5 / beep.dur)
                }
                let tone = sin(2.0 * .pi * beep.freq * elapsed)
                    + 0.35 * sin(2.0 * .pi * beep.freq * 2.0 * elapsed)
                    + 0.1 * sin(2.0 * .pi * beep.freq * 3.0 * elapsed)
                sample += (tone / 1.45) * env * beep.vol
            }

            sample = max(-1.0, min(1.0, sample))
            let value = Int16(clamping: Int(sample * 26000))
            var le = value.littleEndian
            audioData.append(Data(bytes: &le, count: 2))
        }

        var wav = Data()
        let dataSize = UInt32(audioData.count)
        let fileSize = UInt32(36 + audioData.count)

        wav.append(contentsOf: [0x52, 0x49, 0x46, 0x46])
        appendLE(&wav, fileSize)
        wav.append(contentsOf: [0x57, 0x41, 0x56, 0x45])
        wav.append(contentsOf: [0x66, 0x6D, 0x74, 0x20])
        appendLE(&wav, UInt32(16))
        appendLE(&wav, UInt16(1))
        appendLE(&wav, UInt16(1))
        appendLE(&wav, UInt32(sampleRate))
        appendLE(&wav, UInt32(sampleRate * 2))
        appendLE(&wav, UInt16(2))
        appendLE(&wav, UInt16(16))
        wav.append(contentsOf: [0x64, 0x61, 0x74, 0x61])
        appendLE(&wav, dataSize)
        wav.append(audioData)

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("reminder.wav")
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
