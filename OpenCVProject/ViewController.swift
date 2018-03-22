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
import AVFoundation

class ViewController: UIViewController, FrameExtractorDelegate {
   
    var frameExtractor : FrameExtractor!
    
    let audioEngine = AVAudioEngine()
    let speechRecognizer: SFSpeechRecognizer? = SFSpeechRecognizer()
    
    var speechResult : String!
    var imageData: Data!
    var node: AVAudioInputNode!
    var request : SFSpeechAudioBufferRecognitionRequest!
    
    @IBOutlet weak var imageView: UIImageView!
    
    @IBAction func speakPressed(_ sender: Any) {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
            self.request.endAudio()
            //activitySpinner.isHidden = true
            print(self.speechResult)
            if self.speechResult != nil && speechResult.lowercased().contains("describe") {
                print("describing")
                self.describe(image: imageView.image!)
            }
            
        } else {
            requestSpeechAuth()
        }
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        let tap2 = UITapGestureRecognizer(target: self, action: #selector(doubleTapped))
        tap2.numberOfTapsRequired = 2
        view.addGestureRecognizer(tap2)
        
        let tap3 = UITapGestureRecognizer(target: self, action: #selector(tripleTapped))
        tap3.numberOfTapsRequired = 3
        view.addGestureRecognizer(tap3)
        
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayAndRecord)
        }
        catch {
            // report for an error
        }
        frameExtractor = FrameExtractor()
        frameExtractor.delegate = self
        
    }
    
    @objc func doubleTapped() {
        // do something here
        frameExtractor.flipCamera()
    }
    
    @objc func tripleTapped() {
        describe(image: imageView.image!)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
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
    
    func postRequest(url: String, subKey: String, image: UIImage) -> URLRequest {
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = "POST"
        request.httpBody = UIImageJPEGRepresentation(image, 1)
        request.addValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.addValue(subKey, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
        
        return request
    }
    
    func describe(image: UIImage) {
        let request = self.postRequest(url: "https://westcentralus.api.cognitive.microsoft.com/vision/v1.0/describe", subKey: "5b12f0c970b0483896897cbfaa8672b1", image: image)
        let session = URLSession.shared
        let task = session.dataTask(with: request, completionHandler: {data, response, error -> Void in
            //print("Response: \(String(describing: response))")
            let strData = NSString(data: data!, encoding: String.Encoding.utf8.rawValue)
            print("Body: \(String(describing: strData))")
            
            do {
                let json =  try JSONSerialization.jsonObject(with: data!, options: []) as? [String: Any]
                let des =  json!["description"] as? [String: Any]
                let cap =  des!["captions"] as? [[String: Any]]
                if (!(cap?.isEmpty)!) {
                    let text = cap![0]["text"] as? String
                    let confidence = cap![0]["confidence"] as? Float
                    if ((text?.contains("man"))! || (text?.contains("men"))! || (text?.contains("person"))! || (text?.contains("woman"))! || (text?.contains("women"))! || (text?.contains("people"))!) {
                        self.analyzeFace(image: image)
                    } else if (confidence! > 0.5) {
                        self.speak(text: "I see " + text!)
                    } else {
                        self.speak(text: "I am Not sure please try again")
                    }
                } else {
                    self.speak(text: "I am Not sure please try again")
                }
                print(cap! as Any)
            } catch {
                print(error.localizedDescription)
            }

          /*  // parse the result as JSON
            do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(APIResponse.self, from: data!)
                self.speak(text: "I see "+response.description.captions[0].text)
            } catch {
                print("error parsing data")
                return
            } */
        })
        task.resume()
    }
 
    
    func analyzeFace(image: UIImage) {
        let faceAttr = "age,gender,smile,facialHair,glasses,emotion,hair"
        let request = self.postRequest(url: "https://westcentralus.api.cognitive.microsoft.com/face/v1.0/detect?returnFaceId=true&returnFaceLandmarks=false&returnFaceAttributes="+faceAttr, subKey: "34bae6d8076e4fcab9c31846bf62131f",image: image)
        let session = URLSession.shared
        let task = session.dataTask(with: request, completionHandler: {data, response, error -> Void in
            //print("Response: \(String(describing: response))")
            let strData = NSString(data: data!, encoding: String.Encoding.utf8.rawValue)
            print("Body: \(String(describing: strData))")
            
            do {
                var json =  try JSONSerialization.jsonObject(with: data!, options: []) as? [[String: Any]]
                if !(json?.isEmpty)! {
                    let faceAttributes = json![0]["faceAttributes"] as? [String: Any]
                    var text = "I see " + self.faceText(faceAttributes: faceAttributes!)
                    self.speak(text: text)
                    json?.remove(at: 0)
                    for face in json! {
                        text = " and " + self.faceText(faceAttributes: (face["faceAttributes"] as? [String: Any])!)
                        self.speak(text: text)
                    }
                }
                
            } catch {
                print(error.localizedDescription)
                return
            }
            
           /* do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(APIFace.self, from: data!)
                if !response.faces.isEmpty {
                    for face in response.faces {
                        let pn = face.gender == "Male" ? "he" : "she"
                        self.speak(text: "I think "+pn+"is"+String(face.age)+"year old")
                    }
                }
            } catch {
                print("error parsing data")
                return
            } */
        })
        task.resume()
    }
    
    func faceText(faceAttributes: [String: Any]) -> String {
        let age = Int((faceAttributes["age"] as? Float)!)
        let gender = faceAttributes["gender"] as? String
        let smile = faceAttributes["smile"] as? Float
        let facialHair = faceAttributes["facialHair"] as? [String: Any]
        let beard = facialHair!["beard"] as? Float
        let glasses = faceAttributes["glasses"] as? String
        let emotions = faceAttributes["emotion"] as? [String: Any]
        let hair = faceAttributes["hair"] as? [String: Any]
        let bald = hair!["bald"] as? Float
        let invisibleHair = hair!["invisible"] as? Bool
        let hairColors = hair!["hairColor"] as? [[String: Any]]
        var text = "a \(String(describing: age)) year old " + gender!
        if (beard! > 0.5) {text += " having beard "}
        if (glasses! != "NoGlasses") {text += " with \(String(describing: glasses!))"}
        if (bald! < 0.5 && invisibleHair! == false) {
            let hairColor = hairColors?.max(by: { (x, y) -> Bool in
                let xConf = x["confidence"] as? Float
                let yConf = y["confidence"] as? Float
                return xConf! < yConf!
            })!["color"] as? String
            text += " and \(String(describing: hairColor!)) hair "}
        if (smile! > 0.5) {text += " smiling "}
        else {
            let emotion = emotions?.max(by: { (x, y) -> Bool in
                let xval = x.value as? Float
                let yval = y.value as? Float
                return xval! < yval!
            })?.key
            text += " looking " + emotion!
        }
        return text
    }
    
    func speak(text: String) {
        let synth = AVSpeechSynthesizer()
        let speech = AVSpeechUtterance(string: text )
        synth.speak(speech)
    }
    
    func requestSpeechAuth() {
        print("speak11")
        self.request = SFSpeechAudioBufferRecognitionRequest()
        print("speak12")
        print(audioEngine.isRunning)
        node = audioEngine.inputNode
        print("speak13")
        let recordingFormat = node.outputFormat(forBus: 0)
        print("speak14")
        node.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.request.append(buffer)
        }
        print("speak15")
        
        audioEngine.prepare()
        print("speak16")
        do {
            try audioEngine.start()
        } catch {
            return print(error)
        }
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

struct APIFace : Codable {
    struct MetaData : Codable {
        let height: Int
        let width: Int
        let format: String
    }
    struct Faces : Codable {
        let age: Int
        let gender: String
        struct FaceRectangle : Codable {
            let left: Int
            let top: Int
            let width: Int
            let height: Int
        }
        let faceRectangle : FaceRectangle
    }
    let faces : [Faces]
    let requestId: String
    let metadata: MetaData
}

struct OCRResult: Codable {
    
}

