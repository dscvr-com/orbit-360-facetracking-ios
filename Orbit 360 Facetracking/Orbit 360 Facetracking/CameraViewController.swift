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

class CameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate, AVCaptureMetadataOutputObjectsDelegate {
    var service: MotorControl!
    var backgroundTask: UIBackgroundTaskIdentifier = UIBackgroundTaskInvalid

    var isInMovieMode = true
    var isRecording = false
    var useFront = true
    var firstRun = true
    var firstRunMeta = true
    var isTracking = true

    @IBOutlet weak var switchCameraButton: UIButton!
    @IBOutlet weak var recordingTimeLabel: UILabel!
    @IBOutlet weak var previewView: UIView!
    @IBOutlet weak var trackingButton: UIButton!
    @IBOutlet weak var pointButton: UIButton!
    @IBOutlet var switchToPhoto: UISwipeGestureRecognizer!
    @IBOutlet var switchToVideo: UISwipeGestureRecognizer!
    @IBOutlet weak var video: UILabel!
    @IBOutlet weak var photo: UILabel!
    @IBOutlet weak var controlBar: UIView!
    @IBOutlet weak var navBar: UIView!
    @IBOutlet weak var startButton: UIButton!
    @IBOutlet weak var settingsButton: UIButton!
    var countdown = UILabel()
    let cancelButton = UIButton()
    var backgroundImageView: UIImageView?
    var updateBackgroundImageTimer: NSTimer!
    var updateBackgroundImagesCounter = 1

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
    var captureDevice = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo) as AVCaptureDevice
    var assetWriterTransform = CGFloat(M_PI * 90 / 180.0)

    let fps: Int32 = 30
    var lastMovementTime = CFAbsoluteTimeGetCurrent()
    var counter = 3
    var interfacePosition: UIInterfaceOrientation = .Portrait
    var recordingTimeCounter = CFAbsoluteTimeGetCurrent()
    var recordTimer: NSTimer!

    var toCorrectOrientation: GenericTransform! = GenericTransform(m11: 0, m12: 1, m21: 1, m22: 0)
    var toUnitSpace: CameraToUnitSpaceCoordinateConversion! = CameraToUnitSpaceCoordinateConversion(cameraWidth: 1, cameraHeight: 1, aspect: aspectPortrait)
    var toAngle: UnitToMotorSpaceCoordinateConversion!
    var toSteps: MotorSpaceToStepsConversion!
    var controlTarget: Point! = Point(x: 0.25, y: 0.5)
    let controlLogic = PControl<Point>(p: 0.5) // Emulate I-control, since motor does integrating
    let speedFactorX: Float = 0.5
    let speedFactorY: Float = 0.5
    let xThresh = 10
    let yThresh = 10

    @IBAction func myUnwindAction(unwindSegue: UIStoryboardSegue) {
    }

    override func prefersStatusBarHidden() -> Bool {
        return true
    }

    override func supportedInterfaceOrientations() -> UIInterfaceOrientationMask {
        return [/*.LandscapeLeft, .LandscapeRight,*/ .Portrait]
    }

    override func preferredInterfaceOrientationForPresentation() -> UIInterfaceOrientation {
        return .Portrait
    }

    func initializeProcessing() {
        switch (UIDevice.currentDevice().orientation) {
            case .LandscapeLeft:
                if (useFront) {
                    toCorrectOrientation = GenericTransform(m11: 1, m12: 0, m21: 0, m22: -1)
                    controlTarget = Point(x: 0.5, y: 0.75) // Target to the upper third.
                } else {
                    toCorrectOrientation = GenericTransform(m11: -1, m12: 0, m21: 0, m22: -1)
                    controlTarget = Point(x: 0.5, y: 0.25) // Target to the upper third.
                }
                toUnitSpace = CameraToUnitSpaceCoordinateConversion(cameraWidth: 1, cameraHeight: 1, aspect: aspectLandscape)
                if interfacePosition == .Portrait && !isInMovieMode {
                    _ = NSTimer.scheduledTimerWithTimeInterval(0.1, target: self, selector: #selector(CameraViewController.moveLeft), userInfo: nil, repeats: false)
                }
                if useFront {
                    assetWriterTransform = CGFloat(M_PI * 180 / 180.0)
                } else {
                    assetWriterTransform = CGFloat(M_PI * 0 / 180.0)
                }
                rotateButtons(M_PI / 2)
                countdown.frame = view.frame
                interfacePosition = .LandscapeLeft
                break
            case .LandscapeRight:
                if (useFront) {
                    toCorrectOrientation = GenericTransform(m11: -1, m12: 0, m21: 0, m22: 1)
                    controlTarget = Point(x: 0.5, y: 0.25) // Target to the upper third.
                } else {
                    toCorrectOrientation = GenericTransform(m11: 1, m12: 0, m21: 0, m22: 1)
                    controlTarget = Point(x: 0.5, y: 0.75) // Target to the upper third.
                }
                toUnitSpace = CameraToUnitSpaceCoordinateConversion(cameraWidth: 1, cameraHeight: 1, aspect: aspectLandscape)
                if interfacePosition == .Portrait && !isInMovieMode {
                    _ = NSTimer.scheduledTimerWithTimeInterval(0.1, target: self, selector: #selector(CameraViewController.moveLeft), userInfo: nil, repeats: false)
                }
                if useFront {
                    assetWriterTransform = CGFloat(M_PI * 0 / 180.0)
                } else {
                    assetWriterTransform = CGFloat(M_PI * 180 / 180.0)
                }
                rotateButtons(-M_PI / 2)
                countdown.frame = view.frame
                interfacePosition = .LandscapeRight
                break
            case .Portrait:
                if (useFront) {
                    toCorrectOrientation = GenericTransform(m11: 0, m12: 1, m21: 1, m22: 0)
                } else {
                    toCorrectOrientation = GenericTransform(m11: 0, m12: 1, m21: -1, m22: 0)
                }
                toUnitSpace = CameraToUnitSpaceCoordinateConversion(cameraWidth: 1, cameraHeight: 1, aspect: aspectPortrait)
                controlTarget = Point(x: 0.25, y: 0.5) // Target to the upper third.
                if interfacePosition != .Portrait && !isInMovieMode {
                    _ = NSTimer.scheduledTimerWithTimeInterval(0.1, target: self, selector: #selector(CameraViewController.moveLeft), userInfo: nil, repeats: false)
                }
                assetWriterTransform = CGFloat(M_PI * 90 / 180.0)
                rotateButtons(0)
                countdown.frame = view.frame
                interfacePosition = .Portrait
                break
            default:
                break
        }
        toAngle = UnitToMotorSpaceCoordinateConversion(unitFocalLength: Float(focalLen))
        toSteps = MotorSpaceToStepsConversion(fullStepsX: Float(motorStepsX), fullStepsY: Float(motorStepsY))
    }

    func rotateButtons(value: Double) {
        trackingButton.transform = CGAffineTransformMakeRotation(CGFloat(value))
        pointButton.transform = CGAffineTransformMakeRotation(CGFloat(value))
        switchCameraButton.transform = CGAffineTransformMakeRotation(CGFloat(value))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        UIApplication.sharedApplication().idleTimerDisabled = true
        initializeProcessing()
        setupCameraSession()
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        previewView.layer.addSublayer(previewLayer)
        cameraSession.startRunning()
        view.bringSubviewToFront(controlBar)
        view.bringSubviewToFront(navBar)
        countdown.frame = view.frame
        countdown.textAlignment = .Center
        countdown.textColor = UIColor.whiteColor()
        countdown.font = countdown.font.fontWithSize(130)
        self.view!.addSubview(countdown)
    }

    @IBAction func switchTracking(sender: AnyObject) {
        if isTracking {
            trackingButton.setBackgroundImage(UIImage(named:"tracking_off")!, forState: .Normal)
            isTracking = false
        } else {
            trackingButton.setBackgroundImage(UIImage(named:"tracking_on")!, forState: .Normal)
            isTracking = true
        }
    }

    @IBAction func showPoints(sender: AnyObject) {
    }

    @IBAction func openSettings(sender: AnyObject) {
        isTracking = false
        trackingButton.setBackgroundImage(UIImage(named:"tracking_off")!, forState: .Normal)
        self.performSegueWithIdentifier("showSettings", sender: self)
    }

    @IBAction func switchToVideoMode(sender: AnyObject) {
        switchToVideo.enabled = false
        switchToPhoto.enabled = true
        isInMovieMode = true
        moveRight()
        recordingTimeLabel.text = "00:00:00"
        startButton.setBackgroundImage(UIImage(named:"start")!, forState: .Normal)
    }

    @IBAction func switchToPhotoMode(sender: AnyObject) {
        switchToVideo.enabled = true
        switchToPhoto.enabled = false
        isInMovieMode = false
        moveLeft()
        recordingTimeLabel.text = ""
        startButton.setBackgroundImage(UIImage(named:"startPhoto")!, forState: .Normal)
    }

    func moveLeft() {
        video.frame = CGRect(x: video.frame.minX - 60, y: video.frame.minY, width: video.frame.width, height: video.frame.height)
        photo.frame = CGRect(x: photo.frame.minX - 60, y: photo.frame.minY, width: photo.frame.width, height: photo.frame.height)
    }

    func moveRight() {
        video.frame = CGRect(x: video.frame.minX + 60, y: video.frame.minY, width: video.frame.width, height: video.frame.height)
        photo.frame = CGRect(x: photo.frame.minX + 60, y: photo.frame.minY, width: photo.frame.width, height: photo.frame.height)
    }

    @IBAction func startButtonclicked(sender: AnyObject) {
        if (isInMovieMode) {
            startMovie()
        } else {
            startTimer()
        }
    }

    @IBAction func toggleCamera(sender: AnyObject) {
        if (useFront == true) {
            useFront = false
            updateBackgroundImageTimer = NSTimer.scheduledTimerWithTimeInterval(1, target: self, selector: #selector(self.updateImages), userInfo: nil, repeats: true)
            cancelButton.setBackgroundImage(UIImage.init(named: "cancel"), forState: .Normal)
            cancelButton.frame = CGRect(x: self.view.frame.size.width - 50, y: 20, width: 30, height: 30)
            cancelButton.addTarget(self, action: #selector(self.cancelFlipView), forControlEvents: .TouchUpInside)
            view.addSubview(cancelButton)
            updateImages()
            cancelButton.hidden = false
            if isTracking {
                switchTracking("backCamSwitch")
            }
            startButton.enabled = false
            pointButton.enabled = false
            switchCameraButton.enabled = false
            trackingButton.enabled = false
            settingsButton.enabled = false
            setupCameraSession()
        } else {
            useFront = true
            setupCameraSession()
        }
        initializeProcessing()
    }

    func cancelFlipView() {
        updateImages()
        updateBackgroundImagesCounter = -1
        startButton.enabled = true
        pointButton.enabled = true
        switchCameraButton.enabled = true
        trackingButton.enabled = true
        settingsButton.enabled = true
    }

    func updateImages() {
        if backgroundImageView != nil {
            backgroundImageView!.removeFromSuperview()
        }
        var image = UIImage.init(named: "bp\(updateBackgroundImagesCounter)")
        switch (UIDevice.currentDevice().orientation) {
        case .LandscapeLeft:
            image = UIImage.init(named: "bl\(updateBackgroundImagesCounter)")
            backgroundImageView = UIImageView(image: image)
            backgroundImageView?.transform = CGAffineTransformMakeRotation(CGFloat(M_PI / 2))
            backgroundImageView!.frame = CGRect(x: 0, y: 0, width: self.view.frame.size.width, height: self.view.frame.size.height)
            cancelButton.frame = CGRect(x: self.view.frame.size.width - 50, y: self.view.frame.size.height - 50, width: 30, height: 30)
            break
        case .LandscapeRight:
            image = UIImage.init(named: "bl\(updateBackgroundImagesCounter)")
            backgroundImageView = UIImageView(image: image)
            backgroundImageView?.transform = CGAffineTransformMakeRotation(CGFloat(-M_PI / 2))
            backgroundImageView!.frame = CGRect(x: 0, y: 0, width: self.view.frame.size.width, height: self.view.frame.size.height)
            cancelButton.frame = CGRect(x: 20, y: 20, width: 30, height: 30)
            break
        default:
            backgroundImageView = UIImageView(image: image)
            backgroundImageView!.frame = CGRect(x: 0, y: 0, width: self.view.frame.size.width, height: self.view.frame.size.height)
            cancelButton.frame = CGRect(x: self.view.frame.size.width - 50, y: 20, width: 30, height: 30)
        }
        if (updateBackgroundImagesCounter == -1) {
            updateBackgroundImageTimer.invalidate()
            cancelButton.hidden = true
            backgroundImageView!.removeFromSuperview()
            updateBackgroundImagesCounter = 1
            return
        }
        view.addSubview(backgroundImageView!)
        view.bringSubviewToFront(cancelButton)
        updateBackgroundImagesCounter += 1
        if (updateBackgroundImagesCounter == 4) {
            updateBackgroundImagesCounter = 1
        }
    }

    //MARK: CameraSession
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

    func getCamera() {
        if (useFront == true) {
            let avaiableCameras = AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo)
            for element in avaiableCameras{
                let element = element as! AVCaptureDevice
                if element.position == AVCaptureDevicePosition.Front {
                    captureDevice = element
                    break
                }
            }
        } else {
            captureDevice = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo)
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
    }

    /* Sets up in and outputs for the camerasession */
    func setupCameraSession() {
        getCamera()
        let audioDevice = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeAudio)
        do {
            let deviceInput = try AVCaptureDeviceInput(device: captureDevice)
            let audioInput = try AVCaptureDeviceInput(device: audioDevice)
            cameraSession.beginConfiguration()

            for ii in cameraSession.inputs {
                cameraSession.removeInput(ii as! AVCaptureInput)
            }

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

    //MARK: take Video
    func startMovie() {
        if (isRecording) {
            stopRecording()
            startButton.setBackgroundImage(UIImage(named:"start")!, forState: .Normal)
        } else {
            startRecording()
            startButton.setBackgroundImage(UIImage(named:"stop")!, forState: .Normal)
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
        videoWriterInput.transform = CGAffineTransformMakeRotation(assetWriterTransform)
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
        recordingTimeCounter = CFAbsoluteTimeGetCurrent()
        recordTimer = NSTimer.scheduledTimerWithTimeInterval(1, target: self, selector: #selector(CameraViewController.updateRecordingTimeCounter), userInfo: nil, repeats: true)

    }

    func stopRecording() {
//        Finished video recording and export to photo roll.
        recordTimer.invalidate()
        recordingTimeLabel.text! = "00:00:00"
        isRecording = false
        videoWriter.finishWritingWithCompletionHandler({})
        UISaveVideoAtPathToSavedPhotosAlbum(videoOutputURL.path!, nil, nil, nil)
    }

    func updateRecordingTimeCounter() {
        let currentTime = CFAbsoluteTimeGetCurrent()
        let hours = Int(floor((currentTime - recordingTimeCounter) / 3600))
        let minutes = Int(floor(((currentTime - recordingTimeCounter) - Double(hours * 3600)) / 60))
        let seconds = Int((currentTime - recordingTimeCounter) - Double(hours * 3600) - Double(minutes * 60))
        recordingTimeLabel.text! = "\(hours.format("02")):\(minutes.format("02")):\(seconds.format("02"))"
    }

    //MARK: take Photo
    func startTimer() {
        _ = NSTimer.scheduledTimerWithTimeInterval(3, target: self, selector: #selector(CameraViewController.takePhoto), userInfo: nil, repeats: false)
        _ = NSTimer.scheduledTimerWithTimeInterval(2, target: self, selector: #selector(CameraViewController.updateCountdown), userInfo: nil, repeats: false)
        _ = NSTimer.scheduledTimerWithTimeInterval(1, target: self, selector: #selector(CameraViewController.updateCountdown), userInfo: nil, repeats: false)
        _ = NSTimer.scheduledTimerWithTimeInterval(0, target: self, selector: #selector(CameraViewController.updateCountdown), userInfo: nil, repeats: false)
    }

    func updateCountdown() {
        switch (counter) {
        case 3:
            countdown.text = "3"
            counter -= 1
            switchTracking("takePoto")
            break
        case 2:
            countdown.text = "2"
            counter -= 1
            break
        case 1:
            countdown.text = "1"
            counter = 3
            break
        default: break
        }
    }

    func takePhoto() {
        countdown.text = ""
        let connection = self.imageOutput.connectionWithMediaType(AVMediaTypeVideo)
        connection.videoOrientation = AVCaptureVideoOrientation(rawValue: UIDevice.currentDevice().orientation.rawValue)!

        self.imageOutput.captureStillImageAsynchronouslyFromConnection(connection) {
            (imageDataSampleBuffer, error) -> Void in
            if error == nil {
                let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(imageDataSampleBuffer)

                if let image = UIImage(data: imageData) {
                    UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                }
            }
            else {
                NSLog("error while capturing still image: \(error)")
            }
        }
        switchTracking("takePoto")
    }

    //MARK: Output Delegates
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
            
//            print("X: \(Int(steps.x)), Y: \(Int(steps.y)), SX: \(Int(speed.x)), SY: \(Int(speed.y))")

            speed = min(speed, b: Point(x: 1000, y: 1000))
            speed = max(speed, b: Point(x: 250, y: 250))

            if(abs(steps.x) > Float(xThresh) || abs(steps.y) > Float(yThresh)) {
                if (isTracking) {
                    self.service.moveXandY(Int32(steps.x), speedX: Int32(speed.x), stepsY: Int32(steps.y), speedY: Int32(speed.y))
                }
            }
        }
        
        lastMovementTime = currentTime
    }

    func captureStillImageAsynchronously(from connection: AVCaptureConnection!, completionHandler handler: ((CMSampleBuffer?, NSError?) -> Void)!) {
    }

    //MARK: Backgroundfunctonality
    func callMoveToVertical(steps: Double) {
        registerBackgroundTask()
        let triggerTime = (Int64(NSEC_PER_SEC) * Int64(steps) / 1000)
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, triggerTime), dispatch_get_main_queue(), { () -> Void in
            self.moveToVertical()
        })
    }

    func moveToVertical() {
        let steps = Float(motorStepsY) * (40 / 360)
        print(steps)
        service.moveY(Int32(-steps), speed: 1000)
        if backgroundTask != UIBackgroundTaskInvalid {
            endBackgroundTask()
        }
    }

    func registerBackgroundTask() {
        backgroundTask = UIApplication.sharedApplication().beginBackgroundTaskWithExpirationHandler { [weak self] in
            self?.endBackgroundTask()
        }
        assert(backgroundTask != UIBackgroundTaskInvalid)
    }

    func endBackgroundTask() {
        print("Background task ended.")
        UIApplication.sharedApplication().endBackgroundTask(backgroundTask)
        backgroundTask = UIBackgroundTaskInvalid
    }

}
