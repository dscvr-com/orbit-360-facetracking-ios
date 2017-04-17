//
//  ConnectViewController.swift
//  Orbit 360 Facetracking
//
//  Created by Philipp Meyer on 11.03.17.
//  Copyright © 2017 Philipp Meyer. All rights reserved.
//

import Foundation
import UIKit
import CoreBluetooth

class ConnectViewController: UIViewController {

    private var bt: BLEDiscovery!
    var btService : BLEService?
    var btMotorControl : MotorControl?
    var btDevices = [CBPeripheral]()
    @IBOutlet weak var signal: UIImageView!
    @IBOutlet weak var status: UIImageView!

    override func viewDidLoad() {
        super.viewDidLoad()
        bt = BLEDiscovery(onDeviceFound: onDeviceFound, onDeviceConnected: onDeviceConnected, services: [MotorControl.BLEServiceUUID])
        _ = NSTimer.scheduledTimerWithTimeInterval(15, target: self, selector: #selector(ConnectViewController.orbitNotFound), userInfo: nil, repeats: false)

    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func prefersStatusBarHidden() -> Bool {
        return true
    }

    override func shouldAutorotate() -> Bool {
        return false
    }

    override func supportedInterfaceOrientations() -> UIInterfaceOrientationMask {
        return .Portrait
    }

    override func preferredInterfaceOrientationForPresentation() -> UIInterfaceOrientation {
        return .Portrait
    }

    func onDeviceFound(device: CBPeripheral, name: NSString) {
        self.btDevices = self.btDevices + [device]
        bt.connectPeripheral(btDevices[0])
    }

    func onDeviceConnected(device: CBPeripheral) {
        btService = BLEService(initWithPeripheral: device, onServiceConnected: onServiceConnected, bleService: MotorControl.BLEServiceUUID, bleCharacteristic: [MotorControl.BLECharacteristicUUID, MotorControl.BLECharacteristicResponseUUID])
        btService?.startDiscoveringServices()
    }

    func onServiceConnected(service: CBService) {
        btMotorControl = MotorControl(s: service, p: service.peripheral, allowCommandInterrupt: true)
        signal.image = UIImage(named:"ORBIT_color")!
        status.image = UIImage(named:"bluetooth_connected")!
        _ = NSTimer.scheduledTimerWithTimeInterval(2, target: self, selector: #selector(ConnectViewController.performSegue), userInfo: nil, repeats: false)
    }

    func orbitNotFound() {
        signal.image = UIImage(named:"ORBIT_black")!
        status.image = UIImage(named:"bluetooth_alert")!
    }

    func performSegue() {
        self.performSegueWithIdentifier("simpleSegue", sender: self)
    }

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject!) {
        if (segue.identifier == "simpleSegue") {
            let secondViewController = segue.destinationViewController as! CameraViewController
            secondViewController.service = btMotorControl
        }
    }

}
