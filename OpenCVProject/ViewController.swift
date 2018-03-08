//
//  ViewController.swift
//  OpenCVProject
//
//  Created by Amirmehdi Sharifzad on 2018-03-01.
//  Copyright © 2018 Hack The Valley II. All rights reserved.
//

import UIKit
import Speech
import Vision

class ViewController: UIViewController, FrameExtractorDelegate {
   
    var frameExtractor : FrameExtractor!
    
    @IBOutlet weak var imageView: UIImageView!
    
    let audioEngine = AVAudioEngine()
    let speechRecognizer: SFSpeechRecognizer? = SFSpeechRecognizer()
    
    var speechResult : String!
    var imageData: Data!
    var node: AVAudioInputNode!
    var request : SFSpeechAudioBufferRecognitionRequest!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        frameExtractor = FrameExtractor()
        frameExtractor.delegate = self
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func capPressed(_ sender: Any) {
        postRequest(url: "https://westcentralus.api.cognitive.microsoft.com/vision/v1.0/describe", image: imageView.image!)
    }
    func captured(image: UIImage) {
        imageView.image = image
      /*  let delay = DispatchTime.now() + .seconds(10)
        DispatchQueue.main.asyncAfter(deadline: delay) {
            print("delayed")
        } */
    }
    
    func observed(results: [VNClassificationObservation]) {
        // access the AVSpeechSynthesizer Class
        let speakTalk = AVSpeechSynthesizer()
        let observation = results.first
        if (observation?.confidence)! > 0.5 {
            let talk = AVSpeechUtterance(string: (observation?.identifier)!)
            speakTalk.speak(talk)
        }
    }
    
    func postRequest(url: String, image: UIImage) {
        var request = URLRequest(url: URL(string: url)!)
        let session = URLSession.shared
        request.httpMethod = "POST"
        request.httpBody = UIImageJPEGRepresentation(image, 1)
        request.addValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.addValue("5b12f0c970b0483896897cbfaa8672b1", forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
        
        let task = session.dataTask(with: request, completionHandler: {data, response, error -> Void in
            print("Response: \(String(describing: response))")
            let strData = NSString(data: data!, encoding: String.Encoding.utf8.rawValue)
            print("Body: \(String(describing: strData))")
            // parse the result as JSON
            do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(APIResponse.self, from: data!)
                self.speak(text: "I see "+response.description.captions[0].text)
                
                
            } catch {
                print("error parsing data")
                return
            }
        })
        
        task.resume()
    }
    
    func speak(text: String) {
        let synth = AVSpeechSynthesizer()
        let speech = AVSpeechUtterance(string: text )
        synth.speak(speech)
    }
    
    func requestSpeechAuth() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(AVAudioSessionCategoryPlayAndRecord)
        } catch {
            print("Setting category to AVAudioSessionCategoryPlayback failed.")
        }
        self.request = SFSpeechAudioBufferRecognitionRequest()
        node = audioEngine.inputNode
        let recordingFormat = node.outputFormat(forBus: 0)
        node.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.request.append(buffer)
        }
        print("else22")
        
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            return print(error)
        }
        
        print("else24")
        
        let recognizer = SFSpeechRecognizer()
        recognizer?.recognitionTask(with: self.request) { (results, error) in
            
            
            if let error = error {
                print("There was an error: \(error)")
            } else {
                //print(results?.bestTranscription.formattedString as Any)
                //print(results?.isFinal as Any)
                self.speechResult = results?.bestTranscription.formattedString
            }
        }
    }
    

    
}

struct APIResponse : Codable {
    struct MetaData : Codable {
        let height: Int
        let width: Int
        let format: String
    }
    struct Description : Codable {
        struct Captions : Codable {
            let text: String
            let confidence: Float
        }
        let tags: [String]
        let captions: [Captions]
    }
    
    let description: Description
    let requestId: String
    let metadata: MetaData
}

