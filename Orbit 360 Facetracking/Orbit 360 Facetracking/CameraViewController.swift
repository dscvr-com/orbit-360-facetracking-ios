//
//  CameraViewController.swift
//  Orbit 360 Facetracking
//
//  Created by Philipp Meyer on 20.10.16.
//  Copyright © 2016 Philipp Meyer. All rights reserved.
//

import Foundation
import UIKit
import AVFoundation

class CameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate{
    var fd = FaceDetection()
    var service: MotorControl!

    let toolbar = UIToolbar()

    var lastMovement = 0
    let steps: Int32 = 500

    var outputSize: CGSize!
    var isRecording = false
    var timeStamp: CMTime!
    var videoOutputURL: NSURL!
    var videoWriter: AVAssetWriter!
    var videoWriterInput: AVAssetWriterInput!
    var dataOutput = AVCaptureVideoDataOutput()
    var audioWriterInput: AVAssetWriterInput!
    var audioOutput = AVCaptureAudioDataOutput()


    override func prefersStatusBarHidden() -> Bool {
        return true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCameraSession()
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        view.layer.addSublayer(previewLayer)
        cameraSession.startRunning()

        let playPause = UIBarButtonItem(title: "Play/Pause", style: .Plain, target: self, action: #selector(CameraViewController.startStopRecording))
        let videoFoto = UIBarButtonItem(title: "Video/Foto", style: .Plain, target: self, action: #selector(CameraViewController.videoFoto))
        toolbar.frame = CGRectMake(0, self.view.frame.size.height - 46, self.view.frame.size.width, 46)
        toolbar.barStyle = .Black
        toolbar.items = [videoFoto, playPause]
        toolbar.setItems(toolbar.items, animated: true)
        self.view.addSubview(toolbar)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }    
    
    lazy var cameraSession: AVCaptureSession = {
        let s = AVCaptureSession()
        s.sessionPreset = AVCaptureSessionPresetHigh
        return s
    }()
    
    lazy var previewLayer: AVCaptureVideoPreviewLayer = {
        let preview =  AVCaptureVideoPreviewLayer(session: self.cameraSession)
        preview.bounds = CGRect(x: 0, y: 0, width: self.view.bounds.width, height: self.view.bounds.height)
        preview.position = CGPoint(x: CGRectGetMidX(self.view.bounds), y: CGRectGetMidY(self.view.bounds))
        preview.videoGravity = AVLayerVideoGravityResizeAspectFill
        return preview
    }()

    func setupCameraSession() {
        let avaiableCameras = AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo)
        var captureDevice = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo) as AVCaptureDevice
        let audioDevice = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeAudio)

        for element in avaiableCameras{
            let element = element as! AVCaptureDevice
            if element.position == AVCaptureDevicePosition.Front {
                captureDevice = element
                break
            }
        }

        let formats = captureDevice.formats as! [AVCaptureDeviceFormat]
        var best = formats[0]
        for element in formats{
            if element.videoFieldOfView >= best.videoFieldOfView && element.highResolutionStillImageDimensions.height >= best.highResolutionStillImageDimensions.height{
                best = element
            }
        }
        outputSize = CGSizeMake(CGFloat(best.highResolutionStillImageDimensions.width), CGFloat(best.highResolutionStillImageDimensions.height))

        try! captureDevice.lockForConfiguration()
        captureDevice.activeFormat = best
        captureDevice.unlockForConfiguration()
        print(captureDevice.activeFormat)

        do {
            let deviceInput = try AVCaptureDeviceInput(device: captureDevice)
            let audioInput = try AVCaptureDeviceInput(device: audioDevice)
            cameraSession.beginConfiguration()
            if (cameraSession.canAddInput(deviceInput) == true) {
                cameraSession.addInput(deviceInput)
            }
            if (cameraSession.canAddInput(audioInput) == true) {
                cameraSession.addInput(audioInput)
            }
            dataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey: NSNumber(unsignedInt: kCVPixelFormatType_32BGRA)]
            dataOutput.alwaysDiscardsLateVideoFrames = true

            if (cameraSession.canAddOutput(dataOutput) == true) {
                cameraSession.addOutput(dataOutput)
            }
            if (cameraSession.canAddOutput(audioOutput) == true) {
                cameraSession.addOutput(audioOutput)
            }
            cameraSession.commitConfiguration()
            let queue = dispatch_queue_create("videoQueue", DISPATCH_QUEUE_SERIAL)
            dataOutput.setSampleBufferDelegate(self, queue: queue)
            audioOutput.setSampleBufferDelegate(self, queue: queue)
            
        }
        catch let error as NSError {
            NSLog("\(error), \(error.localizedDescription)")
        }
    }

    func startStopRecording() {
        if (isRecording == false) {
            let fileManager = NSFileManager.defaultManager()
            let urls = fileManager.URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)
            guard let documentDirectory: NSURL = urls.first else {
                fatalError("documentDir Error")
            }
            videoOutputURL = documentDirectory.URLByAppendingPathComponent("OutputVideo.mp4")
            if NSFileManager.defaultManager().fileExistsAtPath(videoOutputURL.path!) {
                do {
                    try NSFileManager.defaultManager().removeItemAtPath(videoOutputURL.path!)
                } catch {
                    fatalError("Unable to delete file: \(error) : \(#function).")
                }
            }
            videoWriter = try? AVAssetWriter(URL: videoOutputURL, fileType: AVFileTypeMPEG4)
            let outputSettings = [AVVideoCodecKey : AVVideoCodecH264,
                                  AVVideoWidthKey : NSNumber(float: Float(outputSize.width)),
                                  AVVideoHeightKey : NSNumber(float: Float(outputSize.height))]
            guard videoWriter.canApplyOutputSettings(outputSettings, forMediaType: AVMediaTypeVideo) else {
                fatalError("Negative : Can't apply the Output settings...")
            }
            videoWriterInput = AVAssetWriterInput(mediaType: AVMediaTypeVideo, outputSettings: outputSettings)
            videoWriterInput.transform = CGAffineTransformMakeRotation(CGFloat(M_PI * 90 / 180.0))
            if videoWriter.canAddInput(videoWriterInput) {
                videoWriter.addInput(videoWriterInput)
            }
            videoWriterInput.expectsMediaDataInRealTime = true
            var acl = AudioChannelLayout()
            acl.mChannelLayoutTag = kAudioChannelLayoutTag_Mono
            let audioOutputSettings = [
                AVFormatIDKey : Int(kAudioFormatMPEG4AAC),
                AVNumberOfChannelsKey : Int(1),
                AVSampleRateKey : Int(44100.0),
                AVEncoderBitRateKey : Int(64000),
                //AVChannelLayoutKey : NSData(bytes: &acl, length: sizeof(acl))
            ]
            audioWriterInput = AVAssetWriterInput(mediaType: AVMediaTypeAudio, outputSettings: audioOutputSettings)
            audioWriterInput.expectsMediaDataInRealTime = true
            if videoWriter.canAddInput(audioWriterInput) {
                videoWriter.addInput(audioWriterInput)
            }
            videoWriter.startWriting()
            videoWriter.startSessionAtSourceTime(timeStamp)
            isRecording = true
        } else {
            videoWriter.finishWritingWithCompletionHandler({})
            UISaveVideoAtPathToSavedPhotosAlbum(videoOutputURL.path!, nil, nil, nil)
            isRecording = false
        }
    }

    func videoFoto() {

    }

    func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        // Here you collect each frame and process it
        timeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

        if captureOutput == audioOutput {
            if (isRecording == true) {
                if(audioWriterInput.readyForMoreMediaData) {
                    audioWriterInput.appendSampleBuffer(sampleBuffer)
                }
            }
            return
        }

        if captureOutput == dataOutput {
            if (isRecording == true) {
                if(videoWriterInput.readyForMoreMediaData) {
                    videoWriterInput.appendSampleBuffer(sampleBuffer)
                }
            }
        }



        if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly)
            let bufferData = CVPixelBufferGetBaseAddress(pixelBuffer)
            let bufferWidth = UInt32(CVPixelBufferGetWidth(pixelBuffer))
            let bufferHeight = UInt32(CVPixelBufferGetHeight(pixelBuffer))
            let face = fd.detectFaces(bufferData, bufferWidth, bufferHeight)
            if(face.midX == 0 && face.midY == 0) {
                //self.service.sendStop()
                print("stop")
                return
            }
            print(face)
            
//            let diffX = face.midX - CGFloat(bufferHeight) / CGFloat(2)
//            let diffY = face.midY - CGFloat(bufferWidth) / CGFloat(2)
//
//            switch (diffX, diffY) {
//            case (-100...100, -100...100):
//                if lastMovement == 0 {
//                    return
//                }
//                self.service.sendStop()
//                lastMovement = 0
//                break
//            case (CGFloat(Int.min) ... -101, -100...100):
//                if lastMovement == 1 {
//                    return
//                }
//                self.service.moveX(-steps)
//                lastMovement = 1
//                break
//            case (101 ... CGFloat(Int.max), -100...100):
//                if lastMovement == 2 {
//                    return
//                }
//                self.service.moveX(steps)
//                lastMovement = 2
//                break
//            case (-100...100, CGFloat(Int.min) ... -101):
//                if lastMovement == 3 {
//                    return
//                }
//                self.service.moveY(-steps)
//                lastMovement = 3
//                break
//            case (-100...100, 101 ... CGFloat(Int.max)):
//                if lastMovement == 4 {
//                    return
//                }
//                self.service.moveY(steps)
//                lastMovement = 4
//                break
//            case (CGFloat(Int.min) ... -101, CGFloat(Int.min) ... -101):
//                if lastMovement == 5 {
//                    return
//                }
//                self.service.moveXandY(-steps, stepsY: -steps)
//                lastMovement = 5
//                break
//            case (CGFloat(Int.min) ... -101, 101 ... CGFloat(Int.max)):
//                if lastMovement == 6 {
//                    return
//                }
//                self.service.moveXandY(-steps, stepsY: steps)
//                lastMovement = 6
//                break
//            case (101 ... CGFloat(Int.max), CGFloat(Int.min) ... -101):
//                if lastMovement == 7 {
//                    return
//                }
//                self.service.moveXandY(steps, stepsY: -steps)
//                lastMovement = 7
//                break
//            case (101 ... CGFloat(Int.max), 101 ... CGFloat(Int.max)):
//                if lastMovement == 8 {
//                    return
//                }
//                self.service.moveXandY(steps, stepsY: steps)
//                lastMovement = 8
//                break
//            default:
//                self.service.sendStop()
//                break
//            }
//
//            if (abs(diffX) > 100) {
//                if (diffX < 0) {
//                    if (lastMovement == -1) {
//                        return
//                    }
//                    self.service.moveX(-1000)
//                    lastMovement = -1
//                } else {
//                    if (lastMovement == 1) {
//                        return
//                    }
//                    self.service.moveX(1000)
//                    lastMovement = 1
//                }
//            } else {
//                if (lastMovement == 0) {
//                    return
//                } else {
//                    self.service.sendStop()
//                    lastMovement = 0
//                }
//            }
        }
    }

    func captureOutput(captureOutput: AVCaptureOutput!, didDropSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        // Here you can count how many frames are dopped
    }
    
}