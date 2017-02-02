//
//  ViewController.swift
//  HLS Tap
//
//  Created by Kent Karlsson on 2/2/17.
//  Copyright © 2017 Kent Karlsson. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {

    @IBOutlet var textView: UITextView?

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func clearLog() {
        textView?.text = ""
    }

    func log(_ message:String = "", caller: String = #function) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async {
                self.log(message, caller: caller)
            }
            return
        }

        textView?.insertText("\(caller) \(message)\n")
    }

    override func viewWillAppear(_ animated: Bool) {
        clearLog()
    }

    override func viewDidAppear(_ animated: Bool) {
        loadMovie()
    }


    var playerItem: AVPlayerItem!
    var player: AVPlayer!
    func loadMovie() {
        log()

        let url = URL(string: "http://devimages.apple.com/iphone/samples/bipbop/bipbopall.m3u8")!
//        let url = URL(string: "http://10.0.42.110:8080/demo.mp4")!
        let asset = AVURLAsset(url: url)
        playerItem = AVPlayerItem(asset: asset, automaticallyLoadedAssetKeys: ["tracks"])
        playerItem.addObserver(self, forKeyPath: "status", options: .new, context: nil)

        player = AVPlayer(playerItem: playerItem)
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "status" {
            log("playerItem.status == \(playerItem.status)")

            if !tapInstalled && playerItem.status == .readyToPlay {
                startPlayer()
            }
        }
    }

    func startPlayer() {
        installTap()

        player.seek(to: CMTime(value: 0, timescale: 1)) { (seekDone: Bool) in
            self.log("seekDone: \(seekDone)")
            self.log("playing...")
            self.player.play()
        }
    }

    var tapInstalled = false
    func installTap() {
        log()

        tapInstalled = true

        var callbacks = MTAudioProcessingTapCallbacks(
            version: kMTAudioProcessingTapCallbacksVersion_0,
            clientInfo: Unmanaged.passUnretained(self).toOpaque(),
            init: tapInit,
            finalize: tapFinalize,
            prepare: tapPrepare,
            unprepare: tapUnprepare,
            process: tapProcess)

        var tap: Unmanaged<MTAudioProcessingTap>?
        let err = MTAudioProcessingTapCreate(kCFAllocatorDefault, &callbacks, kMTAudioProcessingTapCreationFlag_PostEffects, &tap)

        guard err == noErr else {
            print("Failed to create TAP: \(err)")
            return
        }

        if let audioTrack = playerItem.asset.tracks(withMediaType: AVMediaTypeAudio).first {
            let inputParams = AVMutableAudioMixInputParameters(track: audioTrack)
            inputParams.audioTapProcessor = tap?.takeUnretainedValue()

            let audioMix = AVMutableAudioMix()
            audioMix.inputParameters = [inputParams]

            playerItem.audioMix = audioMix
            log("Tap installed!")
        } else {
            let status = playerItem.asset.statusOfValue(forKey: "tracks", error: nil)
            log("Error: No audio tracks! (tracks -> \(status))")
        }
    }

    let tapInit: MTAudioProcessingTapInitCallback = {
        (tap, clientInfo: UnsafeMutableRawPointer?, tapStorageOut: UnsafeMutablePointer<UnsafeMutableRawPointer?>) in

//        if var clientSelf = clientInfo?.assumingMemoryBound(to: ViewController.self).pointee {
        if let clientInfo = clientInfo {
            let clientSelf = Unmanaged<ViewController>.fromOpaque(clientInfo).takeUnretainedValue()
            clientSelf.log(caller: "tapInit()")

            tapStorageOut.initialize(to: Unmanaged.passUnretained(clientSelf).toOpaque(), count: 1)
        }
    }
    
    let tapFinalize: MTAudioProcessingTapFinalizeCallback = {
        (tap) in

        let vc = MTAudioProcessingTapGetStorage(tap).assumingMemoryBound(to: ViewController.self).pointee
        vc.log(caller: "tapFinalize()")

    }

    let tapPrepare: MTAudioProcessingTapPrepareCallback = {
        (tap, count, audioDesc) in

        let vc = Unmanaged<ViewController>.fromOpaque(MTAudioProcessingTapGetStorage(tap)).takeUnretainedValue()
        vc.log("count: \(count), audioDesc: \(audioDesc)", caller: "tapPrepare()")
}

    let tapUnprepare: MTAudioProcessingTapUnprepareCallback = {
        (tap) in

        let vc = Unmanaged<ViewController>.fromOpaque(MTAudioProcessingTapGetStorage(tap)).takeUnretainedValue()
        vc.log(caller: "tapUnprepare()")
}

    let tapProcess: MTAudioProcessingTapProcessCallback = {
        (tap: MTAudioProcessingTap, count: CMItemCount, flags: MTAudioProcessingTapFlags, bufferListInOut: UnsafeMutablePointer<AudioBufferList>, frameCountOut: UnsafeMutablePointer<CMItemCount>, flagsOut: UnsafeMutablePointer<MTAudioProcessingTapFlags>) in

        let vc = Unmanaged<ViewController>.fromOpaque(MTAudioProcessingTapGetStorage(tap)).takeUnretainedValue()
        vc.log(caller: "tapProcess()")
    }

}

extension AVKeyValueStatus: CustomStringConvertible {
    public var description: String {
        switch self {
        case .cancelled: return ".cancelled"
        case .failed: return ".failed"
        case .loaded: return ".loaded"
        case .loading: return ".loading"
        default: return ".unknown"
        }
    }
}

extension AVPlayerItemStatus: CustomStringConvertible {
    public var description: String {
        switch self {
        case .failed: return ".failed"
        case .readyToPlay: return ".readyToPlay"
        default: return ".unknown"
        }
    }
}
