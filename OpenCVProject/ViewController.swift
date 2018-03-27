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
    let largepersonGroupId = "lpg_"
    var curLpgNum = 1

    var people : [String : [String : String]] = [:]     //  {personID : {  "name" : name,
                                                        //                 "relation" : relation }
    
    var recognizeBool = false
    var nameBool = false
    var relationBool = false
    
    var personIds : [String] = []
    var numPeople = 0
    
    @IBOutlet weak var imageView: UIImageView!
    
    @IBAction func speakPressed(_ sender: Any) {

        let lpgId = self.largepersonGroupId + "\(self.curLpgNum)"
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
            self.request.endAudio()
            //activitySpinner.isHidden = true
            print(self.speechResult)

            if recognizeBool {
                let sR = speechResult.lowercased()
                if sR.contains("yes") || sR.contains("yeah") || sR.contains("sure") || sR.contains("okay") {
                    print("recognizing")
                    recognizeBool = false
                    self.createPerson(lpg: lpgId ,name: "person_6", userData: "")//TO DO
                }
                recognizeBool = false
            } else if nameBool {
                print("lats is: "+self.personIds.last!)
                people.updateValue(["name" : self.speechResult], forKey: self.personIds.last!)
               // people[self.personIds.last!] = ["name" : self.speechResult]
                nameBool = false
                self.speak(text: "what is this person's relation with you?")
                relationBool = true
                requestSpeechAuth()
            } else if relationBool {
                people[self.personIds.last!]?.updateValue(self.speechResult, forKey: "relation")
                relationBool = false
                self.speak(text: "I now remember \(String(describing: people[self.personIds.last!]!["name"]))")

            } else if self.speechResult != nil {
                if speechResult.lowercased().contains("describe") {
                    print("describing")
                    self.describe(image: imageView.image!)
                }
            }
            
        } else {

            requestSpeechAuth()
        }
        //self.analyzeFace(image: imageView.image!)
        //self.addFaceToPerson(lpgId: "lpg_1", personId: "1f01ca93-198a-4c4a-8b82-d8ba4190ce78", userData: "", targetFace: "", image: imageView.image!, num: 3)
        
        //self.createPerson(lpg: lpgId, name: "person_5", userData: "")

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
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayAndRecord, with:.defaultToSpeaker)
            print("setting category to play and record")
        }
        catch {
            // report for an error
        }
        frameExtractor = FrameExtractor()
        frameExtractor.delegate = self
        let lpgId = self.largepersonGroupId + "\(self.curLpgNum)"
        print(lpgId)
        //self.createLargePersonGroup(largePersonGroupId: lpgId, userData: "")
        //self.createPerson(lpg: lpgId, name: "person_1", userData: "")
        print(self.personIds.joined(separator: " "))
        //"eb08a607-8b28-4672-9393-b385178c3a96"
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
        print(faceIds)
        let body : [String: Any] = ["faceids":faceIds,
                                    "largePersonGroupId": largePersonGroupId,
                                    "maxNumOfCandidatesReturned": maxNumOfCandiadatesReturned,
                                    "confidenceThreshold": confidenceThreshold]
        let bodyData = try? JSONSerialization.data(withJSONObject: body, options: [])
        request.httpBody = bodyData
        let task = session.dataTask(with: request, completionHandler : { (data, response, error) in
            print("Response: \(String(describing: response))")
            let strData = NSString(data: data!, encoding: String.Encoding.utf8.rawValue)
            print("Body: \(String(describing: strData))")
            guard let data = data, let response = response as? HTTPURLResponse, error == nil && response.statusCode == 200 else {
                print(error?.localizedDescription ?? "No data")
                return
            }

            print(response.statusCode)
           // let strData = NSString(data: data, encoding: String.Encoding.utf8.rawValue)
           // print("Body: \(String(describing: strData))")
            if let responseDict = try? JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] {
                for face in responseDict! {
                    let candidates = face["candidates"] as? [[String: Any]]
                    if (!((candidates?.isEmpty)!)){

                        let personID = candidates![0]["personId"] as? String
                        print(personID!)
                        print(self.personIds.joined(separator: " "))
                        if let key = self.people[personID!] {
                            let name = key["name"]
                            let relation = key["relation"]
                            self.speak(text: "I see your"+relation!+name!)
                        } else {
                            print("fuckkk")
                        }
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
            //print("Response: \(String(describing: response))")
            guard let data = data, let response = response as? HTTPURLResponse, error == nil && response.statusCode == 200 else {
                print(error?.localizedDescription ?? "No data")
                return
            }
            print(response.statusCode)
            let strData = NSString(data: data, encoding: String.Encoding.utf8.rawValue)
            print("Body: \(String(describing: strData))")
        })
        task.resume()
    }
    
    func train(lpg: String) {
        print("training \(lpg)")
        let url = urlFace+"/largepersongroups/\(lpg)/train"
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = "POST"
        request.addValue(subKeyFace, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
        let session = URLSession.shared
        let task = session.dataTask(with: request) { (data, response, error) in
            //print("Response: \(String(describing: response))")
            guard let data = data,  error == nil else {
                print(error?.localizedDescription ?? "No data")
                return
            }
            if let response = response as? HTTPURLResponse, response.statusCode == 202 {
                print(response.statusCode)
                self.speak(text: "what is this person's name?")
                self.nameBool = true
                self.requestSpeechAuth()
            }
            
        }
        task.resume()
    }
    
    func createPerson(lpg: String, name: String, userData: String) {
        print("creating person \(name) in \(lpg)")
        var personId = ""
        let url = urlFace+"/largepersongroups/\(lpg)/persons"
        let body : [String: String] = ["name": name,
                                       "userData" : userData]
        let bodyData = try? JSONSerialization.data(withJSONObject: body, options: [])
        var request = self.postRequest(url: url, subKey: subKeyFace, method: "POST",contentType:  "application/json")
        request.httpBody = bodyData
        let session = URLSession.shared
        let task = session.dataTask(with: request, completionHandler: {data, response, error -> Void in
            //print("Response: \(String(describing: response))")
            guard let data = data, let response = response as? HTTPURLResponse, error == nil && response.statusCode == 200 else {
                print(error?.localizedDescription ?? "No data")
                return
            }
            print(response.statusCode)
            let strData = NSString(data: data, encoding: String.Encoding.utf8.rawValue)
            print("Body: \(String(describing: strData))")
            if let responseDict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: String] {
                personId = responseDict!["personId"]!
                print(personId)
                self.personIds.append(personId)
                print(self.personIds.last)
                self.numPeople += 1
                self.speak(text: "hold while I remember this person")
                DispatchQueue.main.async {
                    self.addFaceToPerson(lpgId: lpg, personId: personId, userData: userData, targetFace: "", image: self.imageView.image! ,num: 3)
                }
                
            }
        })
        task.resume()
        print(personId)
    }
    
    func addFaceToPerson(lpgId: String, personId: String, userData: String, targetFace: String, image: UIImage, num:Int) {
        print("adding face to person \(personId)")
        let url = urlFace + "/largepersongroups/\(lpgId)/persons/\(personId)/persistedfaces"
        var request = self.postRequest(url: url, subKey: subKeyFace, method: "POST", contentType: "application/octet-stream")
        request.httpBody = UIImageJPEGRepresentation(image, 1)
        let session = URLSession.shared
        session.dataTask(with: request)
        let task = session.dataTask(with: request, completionHandler: {data, response, error -> Void in
            //print("Response: \(String(describing: response))")
            guard let data = data, let response = response as? HTTPURLResponse, error == nil && response.statusCode == 200 else {
                print(error?.localizedDescription ?? "No data")
                return
            }
            print(response.statusCode)
            let strData = NSString(data: data, encoding: String.Encoding.utf8.rawValue)
            print("Body: \(String(describing: strData))")
            if num != 1 {
                DispatchQueue.main.async {
                    self.addFaceToPerson(lpgId: lpgId, personId: personId, userData: userData, targetFace: targetFace, image: self.imageView.image! ,num: num-1)
                }
            } else {
                self.train(lpg: lpgId)
            }
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
            guard let data = data, let response = response as? HTTPURLResponse, error == nil && response.statusCode == 200 else {
                print(error?.localizedDescription ?? "No data")
                return
            }
            print(response.statusCode)
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
        var request = self.postRequest(url: urlFace+"/detect?returnFaceId=true&returnFaceLandmarks=false&returnFaceAttributes="+faceAttr, subKey: subKeyFace, method: "POST", contentType: "application/octet-stream")
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
                    self.Identify(faceIds: faceIds, largePersonGroupId: self.largepersonGroupId+"\(self.curLpgNum)", maxNumOfCandiadatesReturned: 1, confidenceThreshold: 0.5)
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
    
   /* func OCR(image: UIImage){
        let request = self.postRequest(url: urlVision+"/ocr?en", subKey: subKeyVision, method: "POST", contentType: "application/octet-stream")
        let session = URLSession.shared
        let task = session.dataTask(with: request, completionHandler: {data, response, error -> Void in
            //print("Response: \(String(describing: response))")
            let strData = NSString(data: data!, encoding: String.Encoding.utf8.rawValue)
            print("Body: \(String(describing: strData))")
            do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(APIOCR.self, from: data!)
                if !response.regions.isEmpty {
                    for region in response.regions {
                        for line in region.lines {
                            var lineString = ""
                            for word in line.words {
                                lineString += word.text
                            }
                            self.speak(text: lineString)
                        }
                    }
                }
            } catch {
                print("error parsing data")
                return
            }
            
        })
        
        task.resume()
    } */
    
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



