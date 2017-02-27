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

// Global constants
let focalLen = 3.50021
let aspectPortrait = Float(1280) / Float(720)
let aspectLandscape = Float(1280) / Float(720)
let motorStepsX = 5111
let motorStepsY = 17820

class CameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate, AVCaptureMetadataOutputObjectsDelegate, VCSessionDelegate{
    var service: MotorControl!

    var liveSession: VCSimpleSession!
    var livePrivacy: FBLivePrivacy = .closed

    var isRecording = false
    var faceFrame: UIView?
    var face: CGRect! = nil
    var firstRun = true
    var firstRunMeta = true
    var timer: NSTimer!

    @IBOutlet weak var movieButton: UIButton!
    @IBOutlet weak var controlBar: UIView!
    @IBOutlet weak var liveButton: UIButton!

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
    var pixelFocalLength: Double!
    let fps: Int32 = 30
    var lastMovementTime = CFAbsoluteTimeGetCurrent()

    // Movement thresholds
    let xThresh = 10
    let yThresh = 10
    
    var toCorrectOrientation: GenericTransform!
    var toUnitSpace: CameraToUnitSpaceCoordinateConversion!
    var toAngle: UnitToMotorSpaceCoordinateConversion!
    var toSteps: MotorSpaceToStepsConversion!
    var controlTarget: Point!
    let controlLogic = PControl<Point>(p: 0.5) // Emulate I-control, since motor does integrating
    let speedFactorX: Float = 0.5
    let speedFactorY: Float = 0.5
    
    func initializeProcessing() {
        let orientation = UIDevice.currentDevice().orientation
        switch (orientation) {
            case .LandscapeLeft:
                toCorrectOrientation = GenericTransform(m11: 1, m12: 0, m21: 0, m22: -1)
                toUnitSpace = CameraToUnitSpaceCoordinateConversion(cameraWidth: 1, cameraHeight: 1, aspect: aspectLandscape)
                controlTarget = Point(x: 0.5, y: 0.66) // Target to the upper third.
                break
            case .LandscapeRight:
                toCorrectOrientation = GenericTransform(m11: -1, m12: 0, m21: 0, m22: 1)
                toUnitSpace = CameraToUnitSpaceCoordinateConversion(cameraWidth: 1, cameraHeight: 1, aspect: aspectLandscape)
                controlTarget = Point(x: 0.5, y: 0.33) // Target to the upper third.
                break
            case .PortraitUpsideDown:
                /*toCorrectOrientation = GenericTransform(m11: 0, m12: -1, m21: 1, m22: 0)
                toUnitSpace = CameraToUnitSpaceCoordinateConversion(cameraWidth: 1, cameraHeight: 1, aspect: aspectPortrait)
                controlTarget = Point(x: 0.33, y: 0.5) // Target to the upper third.*/
                break
            default:
                // Portrait case
                toCorrectOrientation = GenericTransform(m11: 0, m12: 1, m21: 1, m22: 0)
                toUnitSpace = CameraToUnitSpaceCoordinateConversion(cameraWidth: 1, cameraHeight: 1, aspect: aspectPortrait)
                controlTarget = Point(x: 0.33, y: 0.5) // Target to the upper third.
                break
        }
        
        toAngle = UnitToMotorSpaceCoordinateConversion(unitFocalLength: Float(focalLen))
        toSteps = MotorSpaceToStepsConversion(fullStepsX: Float(motorStepsX), fullStepsY: Float(motorStepsY))
    }

    override func prefersStatusBarHidden() -> Bool {
        return true
    }

    override func viewDidLoad() {
        UIApplication.sharedApplication().idleTimerDisabled = true
        initializeProcessing()
        setupCameraSession()
        liveSession = VCSimpleSession(videoSize: CGSize(width: 1280, height: 720), frameRate: 30, bitrate: 400000, useInterfaceOrientation: false)
        //view.addSubview(liveSession.previewView)
        //liveSession.previewView.frame = view.bounds
        liveSession.delegate = self
        super.viewDidLoad()
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        view.layer.addSublayer(previewLayer)
        cameraSession.startRunning()

        faceFrame = UIView()
        faceFrame?.layer.borderColor = UIColor.greenColor().CGColor
        faceFrame?.layer.borderWidth = 2
        view.addSubview(faceFrame!)
        view.bringSubviewToFront(faceFrame!)
        view.bringSubviewToFront(controlBar)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    @IBAction func startMovie(sender: AnyObject) {
        if (isRecording) {
            stopRecording()
            movieButton.setBackgroundImage(UIImage(named:"movie")!, forState: .Normal)
        } else {
            startRecording()
            movieButton.setBackgroundImage(UIImage(named:"movie_recording")!, forState: .Normal)
        }
    }

    @IBAction func startPhoto(sender: AnyObject) {
        startTimer()
    }

    @IBAction func goLive(sender: AnyObject) {
        switch liveSession.rtmpSessionState {
        case .None, .PreviewStarted, .Ended, .Error:
            startFBLive()
        default:
            endFBLive()
            break
        }
    }

    func startFBLive() {
        if FBSDKAccessToken.currentAccessToken() != nil {
            FBLiveAPI.shared.startLive(livePrivacy) { result in
                guard let streamUrlString = (result as? NSDictionary)?.valueForKey("stream_url") as? String else {
                    return
                }
                let streamUrl = NSURL(string: streamUrlString)

                guard let lastPathComponent = streamUrl?.lastPathComponent,
                    let query = streamUrl?.query else {
                        return
                }

                self.liveSession.startRtmpSessionWithURL(
                    "rtmp://rtmp-api.facebook.com:80/rtmp/",
                    andStreamKey: "\(lastPathComponent)?\(query)"
                )
            }
        } else {
            fbLogin()
        }
    }

    func endFBLive() {
        if FBSDKAccessToken.currentAccessToken() != nil {
            FBLiveAPI.shared.endLive { _ in
                self.liveSession.endRtmpSession()
            }
        } else {
            fbLogin()
        }
    }

    func fbLogin() {
        let loginManager = FBSDKLoginManager()
        loginManager.logInWithPublishPermissions(["publish_actions"], fromViewController: self) { (result, error) in
            if error != nil {
                print("Error")
            } else if result?.isCancelled == true {
                print("Cancelled")
            } else {
                print("Logged in")
            }
        }
    }

    private func updatePreviewLayer(layer: AVCaptureConnection, orientation: AVCaptureVideoOrientation) {
        layer.videoOrientation = orientation
        previewLayer.frame = self.view.bounds
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        initializeProcessing()

        if let connection =  self.previewLayer.connection  {
            let currentDevice: UIDevice = UIDevice.currentDevice()
            let orientation: UIDeviceOrientation = currentDevice.orientation
            let previewLayerConnection : AVCaptureConnection = connection

            if previewLayerConnection.supportsVideoOrientation {

                switch (orientation) {
                case .Portrait: updatePreviewLayer(previewLayerConnection, orientation: .Portrait)
                case .LandscapeRight: updatePreviewLayer(previewLayerConnection, orientation: .LandscapeLeft)
                case .LandscapeLeft: updatePreviewLayer(previewLayerConnection, orientation: .LandscapeRight)
                //case .PortraitUpsideDown: updatePreviewLayer(previewLayerConnection, orientation: .PortraitUpsideDown)
                default: updatePreviewLayer(previewLayerConnection, orientation: .Portrait)
                    break
                }
            }
        }
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
        captureDevice.activeVideoMinFrameDuration = CMTimeMake(1, fps)
        captureDevice.activeVideoMaxFrameDuration = CMTimeMake(1, fps)
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
            }
            let metaQueue = dispatch_queue_create("metaQueue", DISPATCH_QUEUE_SERIAL)
            dispatch_set_target_queue(metaQueue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0))
            metaOutput.setMetadataObjectsDelegate(self, queue: metaQueue)
//            metaOutput.setMetadataObjectsDelegate(self, queue: dispatch_get_main_queue())
            metaOutput.metadataObjectTypes = [AVMetadataObjectTypeFace]
            if (cameraSession.canAddOutput(audioOutput) == true) {
                cameraSession.addOutput(audioOutput)
            }
            if (cameraSession.canAddOutput(imageOutput) == true) {
                cameraSession.addOutput(imageOutput)
            }
            cameraSession.commitConfiguration()
            let videoQueue = dispatch_queue_create("videoQueue", DISPATCH_QUEUE_SERIAL)
            dataOutput.setSampleBufferDelegate(self, queue: videoQueue)
            audioOutput.setSampleBufferDelegate(self, queue: videoQueue)


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
        isRecording = true
    }

    func stopRecording() {
        /*
         Finished video recording and export to photo roll.
         */
        isRecording = false
        videoWriter.finishWritingWithCompletionHandler({})
        UISaveVideoAtPathToSavedPhotosAlbum(videoOutputURL.path!, nil, nil, nil)
    }

    func startTimer() {
        var label = UILabel(frame: CGRectMake(0, outputSize.height / 2, outputSize.width, 50))
        label.center = CGPointMake(100, 100)
        label.textAlignment = NSTextAlignment.Center
        label.text = "3"
        label.backgroundColor = UIColor.blackColor()
        label.textColor = UIColor.whiteColor()
//        self.view.addSubview(label)
        var timer = NSTimer.scheduledTimerWithTimeInterval(0, target: self, selector: #selector(CameraViewController.takePhoto), userInfo: nil, repeats: false)
    }

    func takePhoto() {
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
    
    func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        
        timeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

        if firstRun {
            if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags.ReadOnly)
                let bufferWidth = UInt32(CVPixelBufferGetWidth(pixelBuffer))
                let bufferHeight = UInt32(CVPixelBufferGetHeight(pixelBuffer))
                outputSize = CGSizeMake(CGFloat(bufferWidth), CGFloat(bufferHeight))
                CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags.ReadOnly)
                firstRun = false
            }
        }

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
    }

    func captureOutput(captureOutput: AVCaptureOutput!, didDropSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        // Here you can count how many frames are dopped
    }

    func captureOutput(captureOutput: AVCaptureOutput!, didOutputMetadataObjects metadataObjects: [AnyObject]!, fromConnection connection: AVCaptureConnection!) {

        let currentTime = CFAbsoluteTimeGetCurrent()
        let dt = currentTime - lastMovementTime

        if (firstRunMeta) {
            // Initialization code here.
            lastMovementTime = currentTime
            firstRunMeta = false
            return
        }

        var facePos: Point? = nil

        for candidate in metadataObjects {
            if candidate.type == AVMetadataObjectTypeFace {
                let curPos = Point(x: Float(candidate.bounds.midX), y: Float(candidate.bounds.midY))
                if(facePos == nil) {
                    facePos = curPos
                } else {
                    facePos = (curPos + facePos!) / 2
                }
            }
        }
        
        if let facePos = facePos {
            let unitPos = toUnitSpace.convert(toCorrectOrientation.convert(facePos))
            let unitTarget = toUnitSpace.convert(toCorrectOrientation.convert(controlTarget))
            let angle = toAngle.convert(unitPos) - toAngle.convert(unitTarget)
            
            // Control moves to 0, 0
            let steering = controlLogic.push(angle)
            let steps = toSteps.convert(steering)
            
            var speed = abs(steps / Float(dt))
            speed = Point(x: speed.x * speedFactorX, y: speed.y * speedFactorY)
            
            print("X: \(Int(steps.x)), Y: \(Int(steps.y)), SX: \(Int(speed.x)), SY: \(Int(speed.y))")
            
            speed = min(speed, b: Point(x: 1000, y: 1000))
            speed = max(speed, b: Point(x: 250, y: 250))
            
            
            
//            print("X: \(Int(steps.x)), Y: \(Int(steps.y)), SX: \(Int(speed.x)), SY: \(Int(speed.y))")
            
            if(abs(steps.x) > Float(xThresh) || abs(steps.y) > Float(yThresh)) {
                //self.service.moveXandY(Int32(steps.x), speedX: Int32(speed.x), stepsY: Int32(steps.y), speedY: Int32(speed.y))
            }
        }
        
        lastMovementTime = currentTime
    }

    func captureStillImageAsynchronously(from connection: AVCaptureConnection!, completionHandler handler: ((CMSampleBuffer?, NSError?) -> Void)!) {
    }

    // MARK: VCSessionDelegate

    func connectionStatusChanged(sessionState: VCSessionState) {
        switch liveSession.rtmpSessionState {
        case .Starting:
            liveButton.setTitle("Connecting", forState: .Normal)
            //liveButton.backgroundColor = UIColor.orangeColor()
        case .Started:
            liveButton.setTitle("Disconnect", forState: .Normal)
            //liveButton.backgroundColor = UIColor.redColor()
        default:
            liveButton.setTitle("Go Live", forState: .Normal)
            //liveButton.backgroundColor = UIColor.greenColor()
        }
    }

}
