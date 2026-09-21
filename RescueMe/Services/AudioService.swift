import AVFoundation

final class AudioService {
    static let shared = AudioService()

    // PCM engine — ringtone, mumble, ambient
    private var engine = AVAudioEngine()
    private var playerNode = AVAudioPlayerNode()
    private var callKitOwnsSession = false

    // AVAudioPlayer stack — realistic voice packs (sequenced MP3 clips)
    private var voicePlayer: AVAudioPlayer?
    private var voiceSequenceTask: Task<Void, Never>?

    private init() {
        configureSession()
    }

    // MARK: - Session

    private func configureSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .default,
                options: [.mixWithOthers, .duckOthers]
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("[Audio] Session config error: \(error)")
        }
    }

    func callKitActivated() {
        callKitOwnsSession = true
        if engine.isRunning { return }
        try? engine.start()
    }

    func callKitDeactivated() {
        callKitOwnsSession = false
        stopAll()
    }

    // MARK: - Ringtone

    func playRingtone() {
        stopAll()
        startEngine(buffer: makeRingtoneBuffer())
    }

    func stopRingtone() {
        stopAll()
    }

    // MARK: - Call Audio

    func startCallAudio(mode: AudioMode, contact: Contact?, language: VoiceLanguage) {
        stopAll()
        switch mode {
        case .silence:
            break
        case .mumble, .ambient:
            startEngine(buffer: makeNoiseBuffer(mode: mode))
        case .realistic:
            if let pack = contact?.voicePack {
                startRealistic(pack: pack, language: language)
            }
        }
    }

    // MARK: - Stop

    func stopAll() {
        voiceSequenceTask?.cancel()
        voiceSequenceTask = nil
        voicePlayer?.stop()
        voicePlayer = nil
        playerNode.stop()
        engine.stop()
    }

    // MARK: - Realistic Voice Pack

    private func startRealistic(pack: String, language: VoiceLanguage) {
        // Files live at VoicePacks/{Pack}/{en|zh}/{pack.lowercased()}_{01..05}.mp3
        // The VoicePacks folder is bundled as a folder reference, preserving structure.
        let subdirectory = "VoicePacks/\(pack)/\(language.folderName)"
        let prefix = pack.lowercased()
        var shuffled = (1...5).shuffled()
        var cursor = 0

        voiceSequenceTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                let clipIndex = shuffled[cursor]
                cursor += 1
                if cursor >= shuffled.count {
                    cursor = 0
                    shuffled = (1...5).shuffled()
                }

                let filename = String(format: "%@_%02d", prefix, clipIndex)
                guard let url = Bundle.main.url(
                    forResource: filename,
                    withExtension: "mp3",
                    subdirectory: subdirectory
                ) else {
                    // Missing file — short pause then try next
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    continue
                }

                guard let player = try? AVAudioPlayer(contentsOf: url) else { continue }
                player.volume = 1.0
                player.prepareToPlay()
                await MainActor.run { self.voicePlayer = player }
                player.play()

                let waitNs = UInt64(max(0, player.duration - 0.1) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: waitNs)
                if Task.isCancelled { break }
            }
        }
    }

    // MARK: - PCM Engine

    private func startEngine(buffer: AVAudioPCMBuffer?) {
        guard let buffer else { return }

        engine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()
        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: buffer.format)

        do {
            try engine.start()
        } catch {
            print("[Audio] Engine start error: \(error)")
            return
        }

        playerNode.scheduleBuffer(buffer, at: nil, options: .loops)
        playerNode.play()
    }

    // MARK: - Buffer Generators

    private func makeRingtoneBuffer() -> AVAudioPCMBuffer? {
        let sampleRate: Double = 44100
        let ringDuration: Double = 2.0
        let silenceDuration: Double = 4.0
        let totalFrames = AVAudioFrameCount(sampleRate * (ringDuration + silenceDuration))
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: totalFrames) else { return nil }
        buffer.frameLength = totalFrames
        let ringFrames = Int(sampleRate * ringDuration)

        for ch in 0..<2 {
            let data = buffer.floatChannelData![ch]
            for i in 0..<Int(totalFrames) {
                if i < ringFrames {
                    let t = Double(i) / sampleRate
                    let tone = sin(2 * .pi * 440 * t) + sin(2 * .pi * 480 * t)
                    let env: Double
                    if t < 0.05 { env = t / 0.05 }
                    else if t > ringDuration - 0.08 { env = (ringDuration - t) / 0.08 }
                    else { env = 1.0 }
                    data[i] = Float(tone * 0.32 * max(0, env))
                } else {
                    data[i] = 0
                }
            }
        }
        return buffer
    }

    private func makeNoiseBuffer(mode: AudioMode) -> AVAudioPCMBuffer? {
        let sampleRate: Double = 44100
        let duration: Double = 12.0
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return nil }
        buffer.frameLength = frameCount
        let data = buffer.floatChannelData![0]

        switch mode {
        case .mumble:
            var b0: Float = 0, b1: Float = 0, b2: Float = 0
            var b3: Float = 0, b4: Float = 0, b5: Float = 0, b6: Float = 0
            for i in 0..<Int(frameCount) {
                let w = Float.random(in: -1...1)
                b0 = 0.99886 * b0 + w * 0.0555179
                b1 = 0.99332 * b1 + w * 0.0750759
                b2 = 0.96900 * b2 + w * 0.1538520
                b3 = 0.86650 * b3 + w * 0.3104856
                b4 = 0.55000 * b4 + w * 0.5329522
                b5 = -0.7616 * b5 - w * 0.0168980
                let pink = (b0 + b1 + b2 + b3 + b4 + b5 + b6 + w * 0.5362) * 0.11
                b6 = w * 0.115926
                data[i] = pink * 0.12
            }
        case .ambient:
            var prev: Float = 0
            for i in 0..<Int(frameCount) {
                let w = Float.random(in: -1...1)
                prev = prev * 0.95 + w * 0.05
                data[i] = prev * 0.25
            }
        case .silence, .realistic:
            for i in 0..<Int(frameCount) { data[i] = 0 }
        }

        return buffer
    }
}
