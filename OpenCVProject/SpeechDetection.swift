//
//  SpeechDetection.swift
//  OpenCVProject
//
//  Created by Amirmehdi Sharifzad on 2018-04-05.
//  Copyright © 2018 Hack The Valley II. All rights reserved.
//

import Foundation
import AVFoundation
import Speech
import UIKit

class SpeechDetection {
    let audioEngine = AVAudioEngine()
    let speechRecognizer: SFSpeechRecognizer? = SFSpeechRecognizer()
    
    var task : SFSpeechRecognitionTask!
    var speechResult : String!
    var node: AVAudioInputNode!
    var request : SFSpeechAudioBufferRecognitionRequest!
    
    func requestSpeechAuth(caption: UILabel) {
        if audioEngine.isRunning {
            self.stopDetection()
        }
        self.request = SFSpeechAudioBufferRecognitionRequest()
        self.request.shouldReportPartialResults = true
       
        node = audioEngine.inputNode

        let recordingFormat = node.outputFormat(forBus: 0)

        node.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.request.append(buffer)
        }

        audioEngine.prepare()

        do {
            try audioEngine.start()
        } catch {
            return print(error)
        }
        
        self.startRecognition(caption: caption)
    }
    
    func startRecognition(caption: UILabel) {
        print("started recognition")
        self.request = SFSpeechAudioBufferRecognitionRequest()
        self.request.shouldReportPartialResults = true
        
        let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        self.task = recognizer?.recognitionTask(with: self.request) { (results, error) in
            if let error = error {
                print("There was an error: \(error)")
            } else {
                if let res = results?.bestTranscription.formattedString {
                    print(res)
                    caption.text = res
                    // once in about every minute recognition task finishes so we need to set up a new one to continue recognition
                    if results?.isFinal == true {
                        print("restarting recognition")
                        self.request = nil
                        self.task = nil
                        self.startRecognition(caption: caption)
                    }
                    
                    //print(results?.isFinal as Any)
                    self.speechResult = res
                }
                
            }
        }
    }
    
    
    func stopDetection() {
        DispatchQueue.main.async {
            print("ass1")
            
            self.audioEngine.inputNode.removeTap(onBus: 0)
            print("ass2")
            self.audioEngine.inputNode.reset()
            print("ass3")
            self.audioEngine.stop()
            print("ass4")
            self.request.endAudio()
            print("ass5")
            self.task.cancel()
            print("ass6")
            self.task = nil
            print("ass7")
            self.request = nil
        }
    }
}
