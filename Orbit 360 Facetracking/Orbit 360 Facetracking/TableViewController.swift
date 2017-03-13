//
//  BLETableViewController.swift
//  Orbit 360 Facetracking
//
//  Created by Philipp Meyer on 19.10.16.
//  Copyright © 2016 Philipp Meyer. All rights reserved.
//

import UIKit
import CoreBluetooth

class BLETableViewController: UITableViewController {

    private var bt: BTDiscovery!
    var btDevicesName = [String]()
    var btDevices = [CBPeripheral]()
    var btService : BTService?
    var btMotorControl : MotorControl?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        bt = BTDiscovery(onDeviceFound: onDeviceFound, onDeviceConnected: onDeviceConnected)
        tableView.estimatedRowHeight = 50
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func prefersStatusBarHidden() -> Bool {
        return true
    }

    func onDeviceFound(device: CBPeripheral, name: NSString) {
        dispatch_async(dispatch_get_main_queue(), {
            print(name)
            self.btDevicesName = self.btDevicesName + [String(name)]
            self.tableView.reloadData()
        })
        self.btDevices = self.btDevices + [device]
    }
    
    func onDeviceConnected(device: CBPeripheral) {
        // Switch to video
        btService = BTService(initWithPeripheral: device, onServiceConnected: onServiceConnected)
        btService?.startDiscoveringServices()
    }
    
    func onServiceConnected(service: CBService) {
        btMotorControl = MotorControl(s: service, p: btService!.peripheral!)
        self.performSegueWithIdentifier("cameraSegue", sender: self)
    }

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject!) {
        if (segue.identifier == "cameraSegue") {
            let secondViewController = segue.destinationViewController as! CameraViewController
            secondViewController.service = btMotorControl
        }
    }
    
    // MARK: - Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return btDevicesName.count
    }

    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("TextCell", forIndexPath: indexPath) as! BLETableViewCell
        cell.textLabel?.text = "Test"
        let row = indexPath.row
        cell.cellLabel.font = UIFont.preferredFontForTextStyle(UIFontTextStyleHeadline)
        cell.cellLabel.text = btDevicesName[row]
        return cell
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        print(btDevices[indexPath.row])
        bt.connectPeripheral(btDevices[indexPath.row])
        print(btDevices[indexPath.row])
    }
}
