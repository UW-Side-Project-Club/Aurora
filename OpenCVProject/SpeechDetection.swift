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
    
    var restartedRec = false
    
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
                    if let sr = self.speechResult, self.restartedRec  {
                        self.speechResult = sr + res + " "
                        self.restartedRec = false
                    } else {
                        self.speechResult = res
                    }
                    caption.text = self.speechResult
                    // once in about every minute recognition task finishes so we need to set up a new one to continue recognition
                    if results?.isFinal == true {
                        print("restarting recognition")
                        self.request = nil
                        self.task = nil
                        self.restartedRec = true
                        self.startRecognition(caption: caption)
                    }
                    
                    //print(results?.isFinal as Any)
                    
                }
                
            }
        }
    }
    
    
    func stopDetection() {
        print("stopDetection")
        self.audioEngine.inputNode.removeTap(onBus: 0)
        self.audioEngine.inputNode.reset()
        self.audioEngine.stop()
        self.request.endAudio()
        self.task.cancel()
        self.task = nil
        self.request = nil
    }
}
