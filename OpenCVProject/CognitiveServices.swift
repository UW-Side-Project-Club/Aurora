//
//  CognitiveServices.swift
//  OpenCVProject
//
//  Created by Amirmehdi Sharifzad on 2018-04-05.
//  Copyright © 2018 Hack The Valley II. All rights reserved.
//

import Foundation
import UIKit

protocol APIResponseDelegate: class {
    
    func response()
}

class CognitiveServices {
    
    // Api information
    let subKeyFace  = "b620b11600bb4dee9f8e3b243d9b6b01"
    
    let subKeyVision = "06c3d4a53d684a35ba9eeb848610c494"
    let urlFace = "https://westcentralus.api.cognitive.microsoft.com/face/v1.0"
    let urlVision = "https://westcentralus.api.cognitive.microsoft.com/vision/v1.0"
    let largepersonGroupId = "lpg_"
    var curLpgNum = 1
    var isLpgEmpty = true
    
    
    func postRequest(url: String, subKey: String, method: String, contentType: String) -> URLRequest {
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = method
        if !contentType.isEmpty {
            request.addValue(contentType, forHTTPHeaderField: "Content-Type")
        }
        request.addValue(subKey, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
        
        return request
    }
}
