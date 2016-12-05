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
    var commandIsAllowed = true

    let toolbar = UIToolbar()
    var isRecording = false
    var isInPhotoMode = false

    var lastMovement = 0
    let steps: Int32 = 500
    var firstRun = true
    var nextCommandFinished: CFAbsoluteTime = 0

    var outputSize: CGSize!
    var timeStamp: CMTime!
    var videoOutputURL: NSURL!
    var videoWriter: AVAssetWriter!
    var videoWriterInput: AVAssetWriterInput!
    var dataOutput = AVCaptureVideoDataOutput()
    var audioWriterInput: AVAssetWriterInput!
    var audioOutput = AVCaptureAudioDataOutput()
    var imageOutput = AVCaptureStillImageOutput()

    let focalLengthOld = 2.139
    let focalLengthNew = /*3.50021*/ 1.537
    var pixelFocalLength: Double!

    override func prefersStatusBarHidden() -> Bool {
        return true
    }
    
    override func viewDidLoad() {
        setupCameraSession()
        super.viewDidLoad()
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

    /* Sets up in and outputs for the camerasession */
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
            if (cameraSession.canAddOutput(imageOutput) == true) {
                cameraSession.addOutput(imageOutput)
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
            /*
             Get path to the Outputfile in the DocumentDirectory of the App and delete previously created files.
             */
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

            /* 
             Initiate new AVAssetWriter to record Video + Audio.
             */
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
            /*
             Finished video recording and export to photo roll.
             */
            isRecording = false
            videoWriter.finishWritingWithCompletionHandler({})
            UISaveVideoAtPathToSavedPhotosAlbum(videoOutputURL.path!, nil, nil, nil)
        }
    }

    func videoFoto() {
        if isInPhotoMode {

            isInPhotoMode = false
        } else {

            isInPhotoMode = true
        }
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
            CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags.ReadOnly)
            let bufferData = CVPixelBufferGetBaseAddress(pixelBuffer)
            let bufferWidth = UInt32(CVPixelBufferGetWidth(pixelBuffer))
            let bufferHeight = UInt32(CVPixelBufferGetHeight(pixelBuffer))

            if firstRun {
                outputSize = CGSizeMake(CGFloat(bufferWidth), CGFloat(bufferHeight))
                switch UIDevice.currentDevice().deviceType {
                case .iPhone2G, .iPhone3G, .iPhone3GS, .iPhone4, .iPhone4S, .iPhone5, .iPhone5S:
                    pixelFocalLength = Double(outputSize.height) * focalLengthOld
                    break
                case .iPhoneSE, .iPhone6, .iPhone6Plus, .iPhone6S, .iPhone6SPlus, .iPhone7, .iPhone7Plus:
                    pixelFocalLength = Double(outputSize.height) * focalLengthNew
                    break
                default:
                    pixelFocalLength = Double(outputSize.height) * focalLengthNew
                    break
                }
                firstRun = false
            }

            let faces = fd.detectFaces(bufferData, bufferWidth, bufferHeight)
            CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags.ReadOnly)
            if(faces.count == 0) {
                print("stop")
                return
            }

            let face = faces[0].CGRectValue()


            print(face)
            let stopWidthX: Double = 0
            let stopWidthY: Double = 100

            let diffX = Double(face.midX) - Double(bufferHeight) / 2
            let diffY = Double(face.midY) - Double(bufferWidth) / 2
            print("Faceoffset: ", diffX, diffY)

            let vectorPercentageX1 = (abs(diffX) - stopWidthX)
            let vectorPercentageX2 = ((Double(bufferHeight) / 2 - (Double(face.width) / 2)) - stopWidthX)
            var vectorPercentageX = vectorPercentageX1 / vectorPercentageX2
            vectorPercentageX = min(1, max(vectorPercentageX, 0))
            var speedX = vectorPercentageX * 1000
//            print(vectorPercentageX)
//            print(speedX)


            let angleX = atan2(diffX, pixelFocalLength)
            let angleY = atan2(diffY, pixelFocalLength)
//            print("AngleX + AngleY: ", angleX*180/M_PI, angleY*180/M_PI)

            let stepsX = 5111 * angleX/(M_PI*2)
            let stepsY = 17820 * angleY/(M_PI*2)
//            print("StepsX + StepsY: ", stepsX, stepsY)

            if(CFAbsoluteTimeGetCurrent() < nextCommandFinished) {
                return
            }

            let expectedDuration = (1 / speedX) * abs(stepsX);

            nextCommandFinished = CFAbsoluteTimeGetCurrent() + expectedDuration

//            if (abs(diffX) < stopWidthX) {
//                self.service.sendStop()
//                commandIsAllowed = true
//                return
//            }

//            if (abs(diffY) < stopWidthY) {
//                self.service.sendStop()
//                commandIsAllowed = true
//                return
//            }

            self.service.moveX(Int32(stepsX), speed: Int32(speedX))
//            if commandIsAllowed {
//                self.service.moveX(Int32(stepsX), speed: Int32(speedX))
//                commandIsAllowed = false
//            }
        }
    }

    func captureOutput(captureOutput: AVCaptureOutput!, didDropSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        // Here you can count how many frames are dopped
    }

    func captureStillImageAsynchronously(from connection: AVCaptureConnection!, completionHandler handler: ((CMSampleBuffer?, NSError?) -> Void)!) {
        
    }

}
