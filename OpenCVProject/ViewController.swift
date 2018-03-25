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
    var personCounter = 0
    var faceCounter = 0
    var recognizeBool = false
    var nameBool = false
    var relationBool = false
    
    let audioEngine = AVAudioEngine()
    let speechRecognizer: SFSpeechRecognizer? = SFSpeechRecognizer()
    
    var speechResult : String!
    var imageData: Data!
    var node: AVAudioInputNode!
    var request : SFSpeechAudioBufferRecognitionRequest!
    
    private let subKeyFace  = "b620b11600bb4dee9f8e3b243d9b6b01"
    private let subKeyVision = "06c3d4a53d684a35ba9eeb848610c494"
    let urlFace = "https://westcentralus.api.cognitive.microsoft.com/face/v1.0"
    let urlVision = "https://westcentralus.api.cognitive.microsoft.com/vision/v1.0"
    let largepersonGroupId = "lpg#"
    var curLpgNum = 1
    var people : [String : [String: String]]!
    
    @IBOutlet weak var imageView: UIImageView!
    
    @IBAction func speakPressed(_ sender: Any) {
       if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
            self.request.endAudio()
            //activitySpinner.isHidden = true
            print(self.speechResult)
            var name : String
        var id: String
            if (recognizeBool) {
                let sR = speechResult.lowercased()
                if sR.contains("yes") || sR.contains("yeah") || sR.contains("sure") || sR.contains("okay") {
                    print("recognizing")
                    id = self.createPerson("","","")//TO DO
                }
            } else if nameBool {
                name = self.speechResult
            } else if relationBool {
                people[id] = ["name" : name, "relation" : self.speechResult]
            } else if self.speechResult != nil {
                if speechResult.lowercased().contains("describe") {
                    print("describing")
                    self.describe(image: imageView.image!)
                }
            }
            
        } else {
            //  requestSpeechAuth()
        }
        self.analyzeFace(image: imageView.image!)
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
        
        //self.createLargePersonGroup(largePersonGroupId: largepersonGroupId+"1", userData: "")
        
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
    
    func postRequest(url: String, subKey: String, method: String, contentType: String) -> URLRequest {
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = method
        request.addValue(contentType, forHTTPHeaderField: "Content-Type")
        request.addValue(subKey, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
        
        return request
    }
    
    func Identify(faceIds: [String] , largePersonGroupId: String , maxNumOfCandiadatesReturned: Int , confidenceThreshold: Float) {
        print("identifying")
        var request = self.postRequest(url: urlFace+"/identify", subKey: subKeyFace, method: "POST", contentType: "application/json")
        let session = URLSession.shared
        let body : [String: Any] = ["faceids":faceIds,
                                    "largePersonGroupId": largePersonGroupId,
                                    "maxNumOfCandidatesReturned": maxNumOfCandiadatesReturned,
                                    "confidenceThreshold": confidenceThreshold]
        let bodyData = try? JSONSerialization.data(withJSONObject: body, options: [])
        request.httpBody = bodyData
        let task = session.dataTask(with: request, completionHandler : { (data, response, error) in
            guard let data = data, error == nil else {
                print(error?.localizedDescription ?? "No data")
                return
            }
            let strData = NSString(data: data, encoding: String.Encoding.utf8.rawValue)
            print("Body: \(String(describing: strData))")
            if let responseDict = try? JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] {
                for face in responseDict! {
                    let candidates = face["candidates"] as? [[String: Any]]
                    if (!((candidates?.isEmpty)!)){
                        let personID = candidates![0]["personID"] as? String
                        let name = self.people[personID!]!["name"]
                        let relation = self.people[personID!]!["relation"]
                        self.speak(text: "I see your"+relation!+name!)
                    }
                    else{
                        self.speak(text: "Do you want to remember this person?")
                        self.recognizeBool=true
                        self.requestSpeechAuth()

                        
                    }
                }
            }
        })
        task.resume()
    }
    
    func addFace(faceListId: String, userData: String, targetFace: String, image: UIImage) {
        print("adding face")
        var url = urlFace+"/facelists/" + faceListId + "/persistedFaces"
        if !(userData.isEmpty) {
            url += "?userData="+userData
            if !(targetFace.isEmpty) {
                url += "&targetFace=" + targetFace
            }
        } else if !(targetFace.isEmpty) {
            url += "?targetFace=" + targetFace
        }
        print(url)
        var request = self.postRequest(url: url, subKey: subKeyFace, method: "POST", contentType: "application/octet-stream")
        request.httpBody = UIImageJPEGRepresentation(image, 1)
        let session = URLSession.shared
        session.dataTask(with: request)
        let task = session.dataTask(with: request, completionHandler: {data, response, error -> Void in
            let strData = NSString(data: data!, encoding: String.Encoding.utf8.rawValue)
            print("Body: \(String(describing: strData))")
        })
        task.resume()
    }
    
    func train(lpg: String) {
        print("training\(lpg)")
        let url = urlFace+"/largepersongroups/\(lpg)/train"
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = "POST"
        request.addValue(subKeyFace, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
        let session = URLSession.shared
        let task = session.dataTask(with: request) { (data, response, error) in
            guard let data = data, error == nil else {
                print(error?.localizedDescription ?? "No data")
                return
            }
            print("Response: \(String(describing: response))")
        }
        task.resume()
    }
    
    func createPerson(lpg: String, name: String, userData: String) {
        print("creating person \(name) in \(lpg)")
        let url = urlFace+"/largepersongroups/\(lpg)/persons"
        let body : [String: String] = ["name": name,
                                       "userData" : userData]
        let bodyData = try? JSONSerialization.data(withJSONObject: body, options: [])
        var request = self.postRequest(url: url, subKey: subKeyFace, method: "POST",contentType:  "application/json")
        request.httpBody = bodyData
        let session = URLSession.shared
        let task = session.dataTask(with: request, completionHandler: {data, response, error -> Void in
            //print("Response: \(String(describing: response))")
            guard let data = data, error == nil else {
                print(error?.localizedDescription ?? "No data")
                return
            }
            let strData = NSString(data: data, encoding: String.Encoding.utf8.rawValue)
            print("Body: \(String(describing: strData))")
        })
        task.resume()
    }
    
    
    
    func createLargePersonGroup(largePersonGroupId: String, userData: String) {
        print("creating large person group \(largePersonGroupId)")
        let url = urlFace+"/largepersongroups/\(largePersonGroupId)"
        print(url)
        let body : [String: String] = ["name": largePersonGroupId,
                                       "userData" : userData]
        let bodyData = try? JSONSerialization.data(withJSONObject: body, options: [])
        var request = self.postRequest(url: url, subKey: subKeyFace, method: "PUT",contentType:  "application/json")
        request.httpBody = bodyData
        let session = URLSession.shared
        let task = session.dataTask(with: request, completionHandler: {data, response, error -> Void in
            //print("Response: \(String(describing: response))")
            guard let data = data, error == nil else {
                print(error?.localizedDescription ?? "No data")
                return
            }
            let strData = NSString(data: data, encoding: String.Encoding.utf8.rawValue)
            print("Body: \(String(describing: strData))")
        })
        task.resume()
        
    }
    
    func describe(image: UIImage) {
        var request = self.postRequest(url: "https://westcentralus.api.cognitive.microsoft.com/vision/v1.0/describe", subKey: "5b12f0c970b0483896897cbfaa8672b1", method: "POST", contentType: "application/octet-stream")
        request.httpBody = UIImageJPEGRepresentation(image, 1)
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
                        self.personCounter+=1
                    } else if (confidence! > 0.5) {
                        self.speak(text: "I see " + text!)
                    } else {
                        self.speak(text: "I am not sure please try again")
                    }
                } else {
                    self.speak(text: "I am not sure please try again")
                }
                print(cap! as Any)
            } catch {
                print(error.localizedDescription)
            }
        })
        task.resume()
    }
 
    
    func analyzeFace(image: UIImage) {
        print("analysing face")
        let faceAttr = "age,gender,smile,facialHair,glasses,emotion,hair"
        var request = self.postRequest(url: "https://westcentralus.api.cognitive.microsoft.com/face/v1.0/detect?returnFaceId=true&returnFaceLandmarks=false&returnFaceAttributes="+faceAttr, subKey: "34bae6d8076e4fcab9c31846bf62131f", method: "POST", contentType: "application/octet-stream")
        request.httpBody = UIImageJPEGRepresentation(image, 1)
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
                    let faceRectangle  = json![0]["faceRectangle"] as? [String: Int]
                    let targetFace = String(describing: faceRectangle!["left"]!) + "," + String(describing: faceRectangle!["top"]!) + "," + String(describing: faceRectangle!["width"]!) + "," + String(describing: faceRectangle!["height"]!)
                    print(targetFace)
                    //self.addFace(faceListId: "face_list1", userData: "", targetFace: targetFace, image: image)
                    var faceId = json![0]["faceId"] as? String
                    var faceIds = [faceId!]
                    json?.remove(at: 0)
                    for face in json! {
                        faceId = face["faceId"] as? String
                        faceIds.append(faceId!)
                        text = " and " + self.faceText(faceAttributes: (face["faceAttributes"] as? [String: Any])!)
                        self.speak(text: text)
                    }
                    self.Identify(faceIds: faceIds, largePersonGroupId: self.largepersonGroupId, maxNumOfCandiadatesReturned: 1, confidenceThreshold: 0.5)
                }
                
            } catch {
                print(error.localizedDescription)
                return
            }
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
    func daySummary(){
        if (!(personCounter==0)){
            self.speak(text: "You have seen \(personCounter)" + "faces")
        }
        
    }
}



