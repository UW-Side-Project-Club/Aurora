//
//  ViewController.swift
//  OpenCVProject
//
//  Created by Amirmehdi Sharifzad on 2018-03-01.
//  Copyright © 2018 Hack The Valley II. All rights reserved.
//

import UIKit
import Vision
import AVFoundation
import Speech

class ViewController: UIViewController, FrameExtractorDelegate {
   
    var frameExtractor : FrameExtractor!

    var people : [String : [String : String]] = [:]     //  {personID : {  "name" : name,
                                                        //                 "relation" : relation }
    // falgs for different voice command
    var recognizeBool = false   // remembering a person
    var nameBool = false        // asking for the name
    var relationBool = false    // asking for the relation
    var introUserNameBool = false;  // asking for the user's name
    var takingNote = false
    var noteName = false
    var readQuestion = false
    var readPartB = false
    
    var userName = ""
    
    var personIds : [String] = []
    var numPeople = 0
    
    var name = ""
    
    var notes : [String: String] = [:]
    var speechToText : [String] = []
    
    // class object handling speech recognition and text to speech
    var speaker = Speaker()
    
    let cs = CognitiveServices()
    
    
    @IBOutlet weak var caption: UILabel!
    @IBOutlet weak var imageView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        let tap2 = UITapGestureRecognizer(target: self, action: #selector(doubleTapped))
        tap2.numberOfTapsRequired = 2
        view.addGestureRecognizer(tap2)
        
        let audioSession = AVAudioSession.sharedInstance()
        //print(audioSession.inputDataSources)
        
        do {
            try audioSession.setCategory(AVAudioSessionCategoryPlayAndRecord, with:.defaultToSpeaker)
            print("set category to play and record")
        }
        catch {
            print("audioSession error: \(error.localizedDescription)")
        }
        
        let lpgId = cs.largepersonGroupId + "\(cs.curLpgNum)"
        self.getPeopleListFromGroup(lpgId: lpgId, start: "")
        
        self.printPersons()
        
        self.caption.lineBreakMode = NSLineBreakMode.byTruncatingHead
        self.caption.numberOfLines = 1
        self.speaker = Speaker(caption: self.caption)
        
        frameExtractor = FrameExtractor()
        frameExtractor.delegate = self
        
        if self.isAppAlreadyLaunchedOnce() {
            // intro
            self.intro(askedName: false)
        }
    }
    
    func isAppAlreadyLaunchedOnce()->Bool{
        let defaults = UserDefaults.standard
        if defaults.string(forKey: "isAppAlreadyLaunchedOnce") != nil{
            print("App already launched")
            return true
        }else{
            defaults.set(true, forKey: "isAppAlreadyLaunchedOnce")
            print("App launched first time")
            return false
        }
    }
    
    func intro(askedName: Bool) {
       var introText = "Hi, I am Aurora. I am your visual assistant. I will process your needs through voice command. Any time you need to talk to me, tap the screen, start talking and once done, tap again. Before I move on, may I ask your name?"
        if !askedName {
            self.speaker.speak(text: introText, requiresResponse: true)
            self.introUserNameBool = true
        } else {
            introText = "Pleasure to be your guide \(self.userName). You can ask me to describe your surroundings and I will do so with the best of my ability, although, I am not always right. You can ask me to read text for you. Finally, you can ask me to take notes for you and I will transcribe what I hear and save it as text and can recite it back anytime you ask me to. "
            self.speaker.speak(text: introText)
        }
    }
    
    func printPersons() {
        for (_, person) in self.people {
            print(person["name"]! + ": " + person["relation"]!)
        }
    }
    
    
    @IBAction func speakPressed(_ sender: Any) {

        let lpgId = cs.largepersonGroupId + "\(cs.curLpgNum)"

        if speaker.speechRecognizer.audioEngine.isRunning {
            print("audio engine is ruuning, ending it")
            speaker.speechRecognizer.stopDetection()

            // read the question
            if readQuestion {
                readQuestion = false
                if let sR = speaker.speechRecognizer.speechResult, sR.lowercased().contains("yes") {
                    self.speaker.speak(text: "Answer each of the following using no more than 2 sentences. Part a, 2 marks, using a decimal notation, state the minimum value that can be represented as a six bit two's complement number")
                }
            }
                
            // user says their name
            else if introUserNameBool {
                if let sR = speaker.speechRecognizer.speechResult {
                    print(sR)
                    self.userName = sR
                    introUserNameBool = false
                    self.intro(askedName: true)
                } else {
                    self.speaker.speak(text: "Sorry I did not catch that, could you repeat please?", requiresResponse: true)
                }
            }
                
            // user responds to whether they want the detected face remembered
            else if recognizeBool {
                if let sR = speaker.speechRecognizer.speechResult {
                    print(sR)
                    if sR.lowercased().contains("yes") || sR.lowercased().contains("yeah") || sR.lowercased().contains("sure") || sR.lowercased().contains("okay") {
                        print("recognizing")
                        recognizeBool = false
                        nameBool = true
                        self.speaker.speak(text: "what is this person's name?",requiresResponse: true)
                    }

                    recognizeBool = false
                } else {
                    self.speaker.speak(text: "Sorry I did not catch that, could you repeat please?", requiresResponse: true)
                }
                
            // user gave the detected person's name
            } else if nameBool {
                if let name = speaker.speechRecognizer.speechResult {
                    nameBool = false
                    relationBool = true
                    self.name = name
                    self.speaker.speak(text: "what is \(self.name)'s relation to you?", requiresResponse: true)
                } else {
                    self.speaker.speak(text: "Sorry I did not catch that, could you repeat please?", requiresResponse: true)
                }
                
            // user gave the detected person's relation
            } else if relationBool {
                relationBool = false
                self.createPerson(lpg: lpgId ,name: self.name, userData: speaker.speechRecognizer.speechResult!)
                
            // user requested note taking
            } else if self.takingNote {
                self.takingNote = false
                self.noteName = true
                speechToText.append(speaker.speechRecognizer.speechResult)
                speaker.speak(text: "what do you want me to name this note?", requiresResponse: true)
           
            // user gave the name for the taken note
            } else if self.noteName {
                self.noteName = false
                guard let noteName = speaker.speechRecognizer.speechResult else {
                    self.speaker.speak(text: "Sorry I did not catch that, could you repeat please?", requiresResponse: true)
                    return
                }
                print("note name is \(noteName.lowercased())")
                self.notes.updateValue(self.speechToText.last!, forKey: noteName.lowercased())
                self.speaker.speak(text: "saved this note as \(noteName)")
                
            // check for the voice commands
            } else if let sR = speaker.speechRecognizer.speechResult  {
                
                // describe sourounding
                if sR.lowercased().contains("describe") {
                    print("describing")
                    speaker.speak(text: "processing")
                    self.describe(image: imageView.image!)
                    
                // read text (OCR)
                } else if sR.lowercased().contains("read") && sR.lowercased().contains("text"){
                    print("reading")
                    speaker.speak(text: "processing")
                    if sR.lowercased().contains("hand") {
                        self.recognizeText(image: imageView.image!, handWritting: true)
                    } else {
                        //self.OCR(image: imageView.image!)
                         self.recognizeText(image: imageView.image!, handWritting: true)
                    }
                    
                // delete person (used for debugging) TODO: remove later
                } else if sR.lowercased().contains("delete") {
                    print("deleting all persons")
                    speaker.speak(text: "processing")
                    for personId in personIds{
                        self.deletePerson(lpgId: lpgId, personId: personId)
                    }
                    personIds = []
                    numPeople = 0
                // trains the lpg (used for debugging) TODO: remove later
                } else if sR.lowercased().contains("train") {
                    print("training")
                    speaker.speak(text: "processing")
                    self.train(lpg: lpgId)
                    
                // take note (start speech recognition)
                } else if sR.lowercased().contains("note") && sR.lowercased().contains("take") {
                    print("taking note")
                    self.takingNote = true
                    self.speaker.speechRecognizer.requestSpeechAuth(caption: self.caption)
                    
                // read a saved note if it exists
                } else if sR.lowercased().contains("note") && sR.lowercased().contains("read") {
                    let noteName : String = String(sR.split(separator: " ").last!).lowercased()
                    print("note name is \(noteName)")
                    print(notes)
                    if let note = self.notes[noteName] {
                        self.speaker.speak(text: note)
                    } else {
                        self.speaker.speak(text: "did not find any notes with name \(noteName)")
                    }
                    
                // read part b of the question
                } else if sR.lowercased().contains("part b") {
                    self.speaker.speak(text: "Part b, 2 marks, Using hexadecimal notation, state the maximum value that can be represented as a thirty two bit two's complement number")
                
                // scan document
                } else if sR.lowercased().contains("scan") {
                    scanDoc()
                }
            } else {
                self.speaker.speak(text: "Sorry I did not catch that, could you repeat please?")
            }
            self.speaker.speechRecognizer.speechResult = ""
        } else {
            print("audio engine not running")
            speaker.speechRecognizer.requestSpeechAuth(caption: self.caption)
        }
    }
    
    
    @objc func doubleTapped() {
        // do something here
        frameExtractor.flipCamera()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    func scanDoc() {
        self.readQuestion = true
        self.speaker.speak(text: "Scan completed. There is one question on this page with 12 marks total and it has 6 subprts. Do you want me to read the question for you?", requiresResponse: true)
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
    
    // gets the list of persons stored in the group with id lpgId (start to max top)
    func getPeopleListFromGroup(lpgId: String, start: String, top: Int = 1000) {
        var url = cs.urlFace + "/largepersongroups/\(lpgId)/persons"
        if !start.isEmpty {
            url += "?start=\(start)"
            if top != -1 {
                url += "&top=\(top)"
            }
        } else if top != -1 {
            url += "?top=\(top)"
        }
        let request = self.cs.postRequest(url: url, subKey: cs.subKeyFace, method: "GET", contentType: "")
        let session = URLSession.shared
        let task = session.dataTask(with: request) { (data, response, error) in
            guard let data = data, let response = response as? HTTPURLResponse, error == nil && response.statusCode == 200 else {
                print(error?.localizedDescription ?? "No data")
                return
            }
            print("successfully got persons list from\(lpgId)")
            let strData = NSString(data: data, encoding: String.Encoding.utf8.rawValue)
            print("Body: \(String(describing: strData!))")
            if let responseDict = try? JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] {
                if (responseDict?.isEmpty)!{
                    print("no persons in \(lpgId)")
                    self.cs.isLpgEmpty = true
                    return
                }
                self.cs.isLpgEmpty = false
                for person in responseDict! {
                    self.personIds = []
                    self.numPeople = 0
                    let personId = person["personId"] as? String
                    self.personIds.append(personId!)
                    self.numPeople += 1
                    let personName = person["name"] as? String
                    //self.deletePerson(lpgId: lpgId, personId: personId!)
                    if let relation = person["userData"] as? String {
                        print(relation)
                        self.people.updateValue(["name" : personName!, "relation": relation], forKey: personId!)
                    } else {
                        self.people.updateValue(["name" : personName!, "relation": ""], forKey: personId!)
                    }
                }
            }
        }
        task.resume()
    }
    
    // deletes the person with personId from the large person group with id lpgId
    func deletePerson(lpgId: String, personId: String) {
        let url = cs.urlFace + "/largepersongroups/\(lpgId)/persons/\(personId)"
        let request = self.cs.postRequest(url: url, subKey: cs.subKeyFace, method: "DELETE", contentType: "")
        let session = URLSession.shared
        let task = session.dataTask(with: request) { (data, response, error) in
            guard let response = response as? HTTPURLResponse, error == nil && response.statusCode == 200 else {
                print(error?.localizedDescription ?? "No data")
                return
            }
            print("successfully deleted \(personId) from \(lpgId)")
        }
        task.resume()
    }
    
    
    // creates a large person group with the given id and data
    func createLargePersonGroup(largePersonGroupId: String, userData: String) {
        print("creating large person group \(largePersonGroupId)")
        let url = self.cs.urlFace+"/largepersongroups/\(largePersonGroupId)"
        print(url)
        let body : [String: String] = ["name": largePersonGroupId,
                                       "userData" : userData]
        let bodyData = try? JSONSerialization.data(withJSONObject: body, options: [])
        var request = self.cs.postRequest(url: url, subKey: self.cs.subKeyFace, method: "PUT",contentType:  "application/json")
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
    
    // sends a request to Vision API to get a description of the captured image
    func describe(image: UIImage) {
        var request = self.cs.postRequest(url: self.cs.urlVision+"/describe", subKey: self.cs.subKeyVision, method: "POST", contentType: "application/octet-stream")
        request.httpBody = UIImageJPEGRepresentation(image, 1)
        let session = URLSession.shared
        let task = session.dataTask(with: request, completionHandler: {data, response, error -> Void in
            //print("Response: \(String(describing: response))")
            let strData = NSString(data: data!, encoding: String.Encoding.utf8.rawValue)
            print("Body: \(String(describing: strData))")
            
            do {
                let json =  try JSONSerialization.jsonObject(with: data!, options: []) as? [String: Any]
                let des =  json!["description"] as? [String: Any]
                
                if let cap =  des!["captions"] as? [[String: Any]], (!(cap.isEmpty)) {
                    guard let text = cap[0]["text"] as? String else {
                        // text is nil
                        print("text is nil")
                        self.speaker.speak(text: "I am Not sure please try again")
                        return
                    }
                    if ((text.contains("man")) ||  (text.contains("person")) || (text.contains("woman"))) {
                        print("there is face/s in the image")
                        self.analyzeFace(image: image)
                    } else if let confidence = cap[0]["confidence"] as? Double, confidence > 0.5 {
                        self.speaker.speak(text: "I see " + text, requiresResponse: false)
                    } else {
                        print("there are no faces or conf < 0.5 or conf == nil")
                        self.speaker.speak(text: "I am Not sure please try again", requiresResponse: false)
                    }
                } else {
                    print("cap is empty or nil")
                    self.speaker.speak(text: "I am Not sure please try again", requiresResponse: false)
                }
            } catch {
                print(error.localizedDescription)
            }
        })
        task.resume()
    }
 
    // sends a request to face API to detect faces in the captured image
    func analyzeFace(image: UIImage) {
        print("analysing face")
        let faceAttr = "age,gender,smile,facialHair,glasses,emotion,hair"
        var request = self.cs.postRequest(url: self.cs.urlFace+"/detect?returnFaceId=true&returnFaceLandmarks=false&returnFaceAttributes="+faceAttr, subKey: self.cs.subKeyFace, method: "POST", contentType: "application/octet-stream")
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
                    //self.speak(text: text)
                    let faceRectangle  = json![0]["faceRectangle"] as? [String: Int]
                    let targetFace = String(describing: faceRectangle!["left"]!) + "," + String(describing: faceRectangle!["top"]!) + "," + String(describing: faceRectangle!["width"]!) + "," + String(describing: faceRectangle!["height"]!)
                    print(targetFace)
                    //self.addFace(faceListId: "face_list1", userData: "", targetFace: targetFace, image: image)
                    var faceId = json![0]["faceId"] as? String
                    var faceIds : [String] = []
                    //json?.remove(at: 0)
                    var textList : [String] = []
                    for face in json! {
                        faceId = face["faceId"] as? String
                        faceIds.append(faceId!)
                        text += " and " + self.faceText(faceAttributes: (face["faceAttributes"] as? [String: Any])!)
                        //self.speak(text: text)
                        textList.append("I see " + self.faceText(faceAttributes: (face["faceAttributes"] as? [String: Any])!))
                    }
                    self.Identify(faceIds: faceIds, largePersonGroupId: self.cs.largepersonGroupId+"\(self.cs.curLpgNum)", maxNumOfCandiadatesReturned: 1, confidenceThreshold: 0.5, textList: textList)
                }
                
            } catch {
                print(error.localizedDescription)
                return
            }
        })
        task.resume()
    }
    
    
    // generates the text for the face with given attributes
    func faceText(faceAttributes: [String: Any]) -> String {
        let age = Int((faceAttributes["age"] as? Double)!)
        let gender = faceAttributes["gender"] as? String
        let smile = faceAttributes["smile"] as? Double
        let facialHair = faceAttributes["facialHair"] as? [String: Any]
        let beard = facialHair!["beard"] as? Double
        let glasses = faceAttributes["glasses"] as? String
        let emotions = faceAttributes["emotion"] as? [String: Any]
        
        let hair = faceAttributes["hair"] as? [String: Any]
        let bald = hair!["bald"] as? Double
        let invisibleHair = hair!["invisible"] as? Bool
        let hairColors = hair!["hairColor"] as? [[String: Any]]
        var text = "a \(String(describing: age)) year old " + gender!
        if (beard! > 0.5) {text += " with a beard "}
        if (glasses! != "NoGlasses") {text += " with \(String(describing: glasses!))"}
        if (bald! < 0.5 && invisibleHair! == false) {
            let hairColor = hairColors?.max(by: { (x, y) -> Bool in
                let xConf = x["confidence"] as? Double
                let yConf = y["confidence"] as? Double
                return xConf! < yConf!
            })!["color"] as? String
            text += " with \(String(describing: hairColor!)) hair "}
        if (smile! > 0.5) {text += " smiling "}
        else {
            var emotion = emotions?.max(by: { (x, y) -> Bool in
                let xval = x.value as? Double
                let yval = y.value as? Double
                return xval! < yval!
            })?.key
            if emotion?.lowercased() == "anger" {
                emotion = "angry"
            }
            if emotion?.lowercased() == "sadness" {
                emotion = "sad"
            }
            text += " looking " + emotion!
        }
        return text
    }
    
    // identifies the faces in faceIds with the stored and trained persons in the largePersonGroupId
    // textList is a list generated for each face from face API describing the face
    func Identify(faceIds: [String] , largePersonGroupId: String , maxNumOfCandiadatesReturned: Int , confidenceThreshold: Float, textList: [String]) {
        print("identifying")
        var request = cs.postRequest(url: cs.urlFace+"/identify", subKey: cs.subKeyFace, method: "POST", contentType: "application/json")
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
            if let responseDict = try? JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] {
                var i = 0
                for face in responseDict! {
                    let text = textList[i]
                    let candidates = face["candidates"] as? [[String: Any]]
                    if (!((candidates?.isEmpty)!) && self.numPeople != 0){
                        let textSliced = text.split(separator: " ")[7...].joined(separator: " ")
                        let personID = candidates![0]["personId"] as? String
                        if let key = self.people[personID!] {
                            print(key)
                            let name = key["name"]
                            if let relation = key["relation"] {
                                print(relation)
                                self.speaker.speak(text: "I see your " + relation + " , " + name! + " " + textSliced)
                            } else {
                                self.speaker.speak(text: "I see \(name!)" + " " + textSliced)
                            }
                        } else {
                            print("personId: \(personID!) does not exist!")
                            self.recognizeBool=true
                            self.speaker.speak(text: text+". Do you want to remember this person?", requiresResponse: true)
                        }
                    }
                    else{
                        print("ass34")
                        //self.speaker.speak(text: text, requiresResponse: false)
                        print("ass35")
                        self.recognizeBool=true
                        self.speaker.speak(text: text+". Do you want to remember this person?", requiresResponse: true)
                        
                    }
                }
            }
        })
        task.resume()
    }
    
    
    
    // creates a person with name: name , relation: userData in large person group with id lpg
    func createPerson(lpg: String, name: String, userData: String) {
        print("creating person \(name) in \(lpg)")
        self.cs.isLpgEmpty = false
        var personId = ""
        let url = self.cs.urlFace+"/largepersongroups/\(lpg)/persons"
        let body : [String: String] = ["name": name,
                                       "userData" : userData]
        let bodyData = try? JSONSerialization.data(withJSONObject: body, options: [])
        var request = self.cs.postRequest(url: url, subKey: self.cs.subKeyFace, method: "POST",contentType: "application/json")
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
                //print(self.personIds.last)
                self.numPeople += 1
                self.people.updateValue(["name" : name, "relation": userData], forKey: personId)
                self.speaker.speak(text: "hold while I remember \(name)", requiresResponse: false)
                DispatchQueue.main.async {
                    // add a face to this person for training
                    self.addFaceToPerson(lpgId: lpg, personId: personId, userData: userData, targetFace: "", image: self.imageView.image! ,num: 1)
                }
                
            }
        })
        task.resume()
        print(personId)
    }
    
    // add (num) faces to the preson with id personId from the large person group with lpgId from the captured image
    func addFaceToPerson(lpgId: String, personId: String, userData: String, targetFace: String, image: UIImage, num:Int) {
        print("adding face to person \(personId)")
        let url = self.cs.urlFace + "/largepersongroups/\(lpgId)/persons/\(personId)/persistedfaces"
        var request = self.cs.postRequest(url: url, subKey: self.cs.subKeyFace, method: "POST", contentType: "application/octet-stream")
        request.httpBody = UIImageJPEGRepresentation(image, 1)
        let session = URLSession.shared
        session.dataTask(with: request)
        let task = session.dataTask(with: request, completionHandler: {data, response, error -> Void in
            //print("Response: \(String(describing: response))")
            guard let data = data, let response = response as? HTTPURLResponse, error == nil && response.statusCode == 200 else {
                print(error?.localizedDescription ?? "No data")
                self.speaker.speak(text: "did not detect a face, let me try again")
                DispatchQueue.main.async {
                    self.addFaceToPerson(lpgId: lpgId, personId: personId, userData: userData, targetFace: targetFace, image: self.imageView.image! ,num: num)
                }
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
    
    // trains the large person group lpg with the persons inside it
    // (there has to be persons created in the group with at list one face for each person)
    func train(lpg: String) {
        print("training \(lpg)")
        let url = self.cs.urlFace+"/largepersongroups/\(lpg)/train"
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = "POST"
        request.addValue(self.cs.subKeyFace, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
        let session = URLSession.shared
        let task = session.dataTask(with: request) { (data, response, error) in
            //print("Response: \(String(describing: response))")
            guard error == nil else {
                print(error?.localizedDescription ?? "No data")
                return
            }
            if let response = response as? HTTPURLResponse, response.statusCode == 202 {
                print("train successful")
                self.speaker.speak(text: "I will now remember \(self.name)")
            }
            
        }
        task.resume()
    }
    
    // sends a request to Vision API for text detection (OCR)
    func OCR(image: UIImage){
        var request = self.cs.postRequest(url: self.cs.urlVision+"/ocr?en", subKey: self.cs.subKeyVision , method: "POST", contentType: "application/octet-stream")
        request.httpBody = UIImageJPEGRepresentation(image, 1)
        let session = URLSession.shared
        let task = session.dataTask(with: request, completionHandler: {data, response, error -> Void in
            //print("Response: \(String(describing: response))")
            let strData = NSString(data: data!, encoding: String.Encoding.utf8.rawValue)
            print("Body: \(String(describing: strData))")
            guard let data = data, let response = response as? HTTPURLResponse, error == nil && response.statusCode == 200 else {
                print(error?.localizedDescription ?? "No data")
                return
            }
            if let responseDict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                let regions = responseDict!["regions"] as? [[String: Any]]
                if (!(regions?.isEmpty)!) {
                    var text = ""
                    for region in regions! {
                        let lines = region["lines"] as? [[String: Any]]
                        for line in lines! {
                            let words = line["words"] as? [[String: String]]
                            for word in words! {
                                text += word["text"]! + " "
                            }
                        }
                    }
                    let lines = text.split(separator: ".")
                    for line in lines {
                        self.speaker.speak(text: String(line), requiresResponse: false)
                    }
                }
            }
        })
        task.resume()
    }
    
    func recognizeText(image: UIImage, handWritting: Bool) {
        print("recogniziong text")
        var request = self.cs.postRequest(url: self.cs.urlVision+"/recognizeText?handWriting=\(handWritting.description)", subKey: self.cs.subKeyVision , method: "POST", contentType: "application/octet-stream")
        request.httpBody = UIImageJPEGRepresentation(image, 1)
        let session = URLSession.shared
        let task = session.dataTask(with: request) { (data, response, error) in
            guard let _ = data, let response = response as? HTTPURLResponse, error == nil && response.statusCode == 202 else {
                print(error?.localizedDescription ?? "No data")
                return
            }
        
            if let operationLocation = response.allHeaderFields["Operation-Location"] as? String {
                self.getTextOperationResult(operationLocation: operationLocation)
            }
        }
        
        task.resume()
    }
    
    func getTextOperationResult(operationLocation: String) {
        print("getting text operation result")
        let request = self.cs.postRequest(url: operationLocation, subKey: self.cs.subKeyVision , method: "GET", contentType: "")
        let session = URLSession.shared
        let task = session.dataTask(with: request) { (data, response, error) in
            guard let data = data, let response = response as? HTTPURLResponse, error == nil && response.statusCode == 200 else {
                print(error?.localizedDescription ?? "No data")
                return
            }
            print(response.description)
            let strData = NSString(data: data, encoding: String.Encoding.utf8.rawValue)
            print("Body: \(String(describing: strData))")
            if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                if json!["status"] as? String == "Succeeded", let recognitionResult = json!["recognitionResult"] as? [String: Any] {
                    print("succeeded")
                    if let lines = recognitionResult["lines"] as? [[String:Any]] {
                        for line in lines {
                            if let text = line["text"] as? String {
                                self.speaker.speak(text: text)
                            }
                        }
                    }
                } else {
                    print(json!["status"] as? String as Any)
                    // the result not ready yet wait 4s and check again
                    DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(4), execute: {
                        // Put your code which should be executed with a delay here
                        print("after 4s")
                        self.getTextOperationResult(operationLocation: operationLocation)
                    })
                    
                }
            }
        }
        task.resume()
    }
}







