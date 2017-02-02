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

class CameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate, AVCaptureMetadataOutputObjectsDelegate{
    var fd = FaceDetection()
    var service: MotorControl!

    let toolbar = UIToolbar()
    var switchToPhoto: UIBarButtonItem!
    var switchToVideo: UIBarButtonItem!
    var recordVideo: UIBarButtonItem!
    var stopVideo: UIBarButtonItem!
    var isRecording = false

    var faceFrame: UIView?
    var face: CGRect! = nil
    var firstRun = true
    var timer: NSTimer!

    var outputSize: CGSize!
    var timeStamp: CMTime!
    var videoOutputURL: NSURL!
    var videoWriter: AVAssetWriter!
    var videoWriterInput: AVAssetWriterInput!
    var dataOutput = AVCaptureVideoDataOutput()
    var metaOutput = AVCaptureMetadataOutput()
    var audioWriterInput: AVAssetWriterInput!
    var audioOutput = AVCaptureAudioDataOutput()
    var imageOutput = AVCaptureStillImageOutput()

    let focalLengthOld = 2.139
    let focalLengthNew = /*3.50021*/ 1.537
    var pixelFocalLength: Double!
    var filter: Tracker?

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

        switchToPhoto = UIBarButtonItem(title: "\u{1F4F9}", style: .Plain, target: self, action: #selector(CameraViewController.toPhoto))
        switchToVideo = UIBarButtonItem(title: "\u{1F4F7}", style: .Plain, target: self, action: #selector(CameraViewController.toVideo))
        recordVideo = UIBarButtonItem(title: "\u{25B6}", style: .Plain, target: self, action: #selector(CameraViewController.startRecording))
        stopVideo = UIBarButtonItem(title: "\u{25A0}", style: .Plain, target: self, action: #selector(CameraViewController.stopRecording))

        toolbar.frame = CGRectMake(0, self.view.frame.size.height - 46, self.view.frame.size.width, 46)
        toolbar.barStyle = .Black
        toolbar.items = [switchToPhoto, recordVideo]
        toolbar.setItems(toolbar.items, animated: true)
        self.view.addSubview(toolbar)

        faceFrame = UIView()
        faceFrame?.layer.borderColor = UIColor.greenColor().CGColor
        faceFrame?.layer.borderWidth = 2
        view.addSubview(faceFrame!)
        view.bringSubviewToFront(faceFrame!)
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
    var captureDevice = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo) as AVCaptureDevice

    /* Sets up in and outputs for the camerasession */
    func setupCameraSession() {
        let avaiableCameras = AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo)
//        var captureDevice = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo) as AVCaptureDevice
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
            if (cameraSession.canAddOutput(metaOutput) == true) {
                cameraSession.addOutput(metaOutput)
            metaOutput.setMetadataObjectsDelegate(self, queue: dispatch_get_main_queue())
            metaOutput.metadataObjectTypes = [AVMetadataObjectTypeFace]
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

    func startRecording() {
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
        toolbar.items = [switchToPhoto, stopVideo]
        isRecording = true
    }

    func stopRecording() {
        /*
         Finished video recording and export to photo roll.
         */
        isRecording = false
        videoWriter.finishWritingWithCompletionHandler({})
        UISaveVideoAtPathToSavedPhotosAlbum(videoOutputURL.path!, nil, nil, nil)
        toolbar.items = [switchToPhoto, recordVideo]
    }

    func toPhoto() {
        toolbar.items = [switchToVideo]
//        cameraSession.sessionPreset = AVCaptureSessionPresetPhoto
        let connection = self.imageOutput.connectionWithMediaType(AVMediaTypeVideo)
        connection.videoOrientation = AVCaptureVideoOrientation(rawValue: UIDevice.currentDevice().orientation.rawValue)!

        self.imageOutput.captureStillImageAsynchronouslyFromConnection(connection) {
            (imageDataSampleBuffer, error) -> Void in
            if error == nil {
                // if the session preset .Photo is used, or if explicitly set in the device's outputSettings
                // we get the data already compressed as JPEG
                let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(imageDataSampleBuffer)

                if let image = UIImage(data: imageData) {
                    UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                }
            }
            else {
                NSLog("error while capturing still image: \(error)")
            }
        }

    }

    func toVideo() {
//        cameraSession.sessionPreset = AVCaptureSessionPresetHigh
        toolbar.items = [switchToPhoto, recordVideo]

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
            }

//            let faces = fd.detectFaces(bufferData, bufferWidth, bufferHeight)
            CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags.ReadOnly)
//            if(faces.count == 0) {
//                return
//            }

//            face = faces[0].CGRectValue()
            if (face == nil) {
                return
            }
            print(face.midX, face.midY)
            let diffX = Double(face.midX) - Double(bufferHeight) / 2
            let diffY = Double(face.midY) - Double(bufferWidth) / 2

            if firstRun {
                filter = Tracker(Float(diffX), Float(diffY))
                firstRun = false
                return
            }
            let result = filter!.update(Float(diffX), Float(diffY))

        }
    }

    func captureOutput(captureOutput: AVCaptureOutput!, didDropSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        // Here you can count how many frames are dopped
    }

    func captureOutput(captureOutput: AVCaptureOutput!, didOutputMetadataObjects metadataObjects: [AnyObject]!, fromConnection connection: AVCaptureConnection!) {

        // Check if the metadataObjects array is not nil and it contains at least one object.
        if metadataObjects == nil || metadataObjects.count == 0 {
            faceFrame?.frame = CGRectZero
            return
        }

        let metadataObj = metadataObjects[0]
        if metadataObj.type == AVMetadataObjectTypeFace {
            let faceObject = previewLayer.transformedMetadataObjectForMetadataObject(metadataObj as! AVMetadataFaceObject) as! AVMetadataFaceObject
            faceFrame?.frame = faceObject.bounds
            face = faceObject.bounds
        }

    }

    func captureStillImageAsynchronously(from connection: AVCaptureConnection!, completionHandler handler: ((CMSampleBuffer?, NSError?) -> Void)!) {
        
    }

}
