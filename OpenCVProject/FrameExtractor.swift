//
//  FrameExtractor.swift
//  OpenCVProject
//
//  Created by Amirmehdi Sharifzad on 2018-03-01.
//  Copyright © 2018 Hack The Valley II. All rights reserved.
//

import UIKit
import AVFoundation
import Vision

protocol FrameExtractorDelegate: class {
    func captured(image: UIImage)
    func observed(results: [VNClassificationObservation])
}

class FrameExtractor: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    private var position = AVCaptureDevice.Position.back
    private let quality = AVCaptureSession.Preset.high
    
    private var permissionGranted = false
    private let sessionQueue = DispatchQueue(label: "session queue")
    private let captureSession = AVCaptureSession()
    private let context = CIContext()
    
    weak var delegate: FrameExtractorDelegate?
    
    override init() {
        print("initializing frameExtractor")
        super.init()
        checkPermission()
        sessionQueue.async { [unowned self] in
            self.configureSession()
            self.captureSession.startRunning()
        }
    }
    
    // MARK: AVSession configuration
    private func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: AVMediaType.video) {
        case .authorized:
            permissionGranted = true
        case .notDetermined:
            requestPermission()
        default:
            permissionGranted = false
        }
    }
    
    private func requestPermission() {
        sessionQueue.suspend()
        AVCaptureDevice.requestAccess(for: AVMediaType.video) { [unowned self] granted in
            self.permissionGranted = granted
            self.sessionQueue.resume()
        }
    }
    
    private func configureSession() {
        print("configuring")
        guard permissionGranted else { return }
        captureSession.sessionPreset = quality
        guard let captureDevice = selectCaptureDevice() else { return }
        guard let captureDeviceInput = try? AVCaptureDeviceInput(device: captureDevice) else { return }
        guard captureSession.canAddInput(captureDeviceInput) else { return }
        captureSession.addInput(captureDeviceInput)
        let videoOutput = AVCaptureVideoDataOutput()
    
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "sample buffer"))
        //self.configureDevice(captureDevice: captureDevice)
        guard captureSession.canAddOutput(videoOutput) else { return }
        captureSession.addOutput(videoOutput)
        guard let connection = videoOutput.connection(with: AVFoundation.AVMediaType.video) else { return }
        guard connection.isVideoOrientationSupported else { return }
        guard connection.isVideoMirroringSupported else { return }
        connection.videoOrientation = .portrait
        connection.isVideoMirrored = position == .front
    }
    
    private func configureDevice(captureDevice: AVCaptureDevice?) {
        if let device = captureDevice {
            print("doing1")
            
            // 1
            for vFormat in captureDevice!.formats {
                
                // 2
                var ranges = vFormat.videoSupportedFrameRateRanges as [AVFrameRateRange]
                let frameRates = ranges[0]
                print(frameRates.maxFrameRate)
                // 3
                if frameRates.maxFrameRate == 30 {
                    
                    // 4
                    do {
                        print("doing")
                        try device.lockForConfiguration()
                        device.activeFormat = vFormat as AVCaptureDevice.Format
                        device.activeVideoMinFrameDuration = frameRates.minFrameDuration
                        device.activeVideoMaxFrameDuration = frameRates.maxFrameDuration
                        device.unlockForConfiguration()
                    } catch {
                    
                    }
                    
                }
            }
        }
        
    }
    
    private func selectCaptureDevice() -> AVCaptureDevice? {
        // search for available capture devices
        return AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: AVMediaType.video, position: position).devices.first
    }
    
    // MARK: Sample buffer to UIImage conversion
    private func imageFromSampleBuffer(sampleBuffer: CMSampleBuffer) -> UIImage? {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        //print(imageBuffer)
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        //print(ciImage)
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
    
    // MARK: AVCaptureVideoDataOutputSampleBufferDelegate
    func captureOutput(_ captureOutput: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        //UI Image
        guard let uiImage = imageFromSampleBuffer(sampleBuffer: sampleBuffer) else { return }
        //Classification model
        //guard let model = try? VNCoreMLModel(for: Inceptionv3().model) else { return }
        /* classification request
        let request = VNCoreMLRequest(model: model) { (finishedRequest, error) in
            guard let results = finishedRequest.results as? [VNClassificationObservation]
                else { return }
            DispatchQueue.main.async(execute: { [unowned self] in
                self.delegate?.observed(results: results)
            })
        } */
           
        DispatchQueue.main.async { [unowned self] in
            self.delegate?.captured(image: uiImage)
        }

       // guard let pixelBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // executes request
        //try? VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:]).perform([request])
    }
    
    public func flipCamera() {
        sessionQueue.async { [unowned self] in
            self.captureSession.beginConfiguration()
            guard let currentCaptureInput = self.captureSession.inputs.first else { return }
            self.captureSession.removeInput(currentCaptureInput)
            guard let currentCaptureOutput = self.captureSession.outputs.first else { return }
            self.captureSession.removeOutput(currentCaptureOutput)
            self.position = self.position == .front ? .back : .front
            self.configureSession()
            self.captureSession.commitConfiguration()
        }
    }
}

