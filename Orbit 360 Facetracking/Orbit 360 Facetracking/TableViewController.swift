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

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()
        
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
    /* Swift 3 Syntax for hiding the status bar
    override var prefersStatusBarHidden: Bool {
        return true
    }
    */

    func onDeviceFound(device: CBPeripheral, name: NSString) {
        dispatch_async(dispatch_get_main_queue(), {
            print(name);
            self.btDevicesName = self.btDevicesName + [String(name)]
            self.tableView.reloadData()
        });
        // Show in list.
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

    /*
    // Override to support conditional editing of the table view.
    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == .Delete {
            // Delete the row from the data source
            tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
        } else if editingStyle == .Insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(tableView: UITableView, moveRowAtIndexPath fromIndexPath: NSIndexPath, toIndexPath: NSIndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(tableView: UITableView, canMoveRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

}
