//
//  Speaker.swift
//  OpenCVProject
//
//  Created by Amirmehdi Sharifzad on 2018-04-05.
//  Copyright © 2018 Hack The Valley II. All rights reserved.
//

import Foundation
import AVFoundation
import Speech
import UIKit

class Speaker: NSObject, AVSpeechSynthesizerDelegate {
    let synth = AVSpeechSynthesizer()
    let speechRecognizer = SpeechDetection()
    
    var requiresResponse = false
    
    var caption : UILabel!
    
    override init() {
        super.init()
        synth.delegate = self
    }
    
    init(caption: UILabel) {
        super.init()
        synth.delegate = self
        self.caption = caption
    }
    
    func speak(text: String, requiresResponse: Bool = false) {
        self.requiresResponse = requiresResponse
        print("requires response is \(requiresResponse)")
        let utterance = AVSpeechUtterance(string: text)
        synth.speak(utterance)
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        print("all done")
        if requiresResponse {
            print("requires response")
            if speechRecognizer.audioEngine.isRunning{
                speechRecognizer.stopDetection()
            }
            speechRecognizer.requestSpeechAuth(caption: self.caption)
        }
    }
}

