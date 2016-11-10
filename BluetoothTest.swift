//
//  ViewController.swift
//  Bluetooth Test
//
//  Created by Philipp Meyer on 03.10.16.
//  Copyright © 2016 Philipp Meyer. All rights reserved.
//

import UIKit
import CoreBluetooth

let BLEServiceUUID = CBUUID(string: "1000")
let BLECharacteristicUUID = CBUUID(string: "1001")

class ViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate {

    @IBOutlet weak var testLabel: UILabel!
    // BLE
    var centralManager : CBCentralManager!
    var motorPeripheral : CBPeripheral!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        // Initialize central manager on load
        centralManager = CBCentralManager(delegate: self, queue: dispatch_get_main_queue())
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    // Check status of BLE hardware
    func centralManagerDidUpdateState(central: CBCentralManager) {
        if central.state == CBCentralManagerState.PoweredOn {
            // Scan for peripherals if BLE is turned on
            central.scanForPeripheralsWithServices(nil, options: nil)
            //central.scanForPeripheralsWithServices(nil, options: nil)
            testLabel.text = "Searching for BLE Devices"
        }
        else {
            // Can have different conditions for all states if needed - print generic message for now
            print("Bluetooth switched off or not initialized")
        }
    }

    func centralManager(central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        testLabel.text = "Disconnected"
        central.scanForPeripheralsWithServices(nil, options: nil)
    }
    
    func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : AnyObject], RSSI: NSNumber) {
        
        let deviceName = "BLE#0x44A6E503892F"
        let nameOfDeviceFound = (advertisementData as NSDictionary).objectForKey(CBAdvertisementDataLocalNameKey) as? NSString
        
        if (nameOfDeviceFound == deviceName) {
            // Update Status Label
            testLabel.text = "Motor found"
            // Stop scanning
            self.centralManager.stopScan()
            // Set as the peripheral to use and establish connection
            self.motorPeripheral = peripheral
            self.motorPeripheral.delegate = self
            self.centralManager.connectPeripheral(peripheral, options: nil)
        }
        else {
            testLabel.text = "Motor NOT Found"
        }
    }

    // Discover services of the peripheral
    func centralManager(central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {
        testLabel.text = "Discovering peripheral services"
        peripheral.discoverServices(nil)
    }

    // Check if the service discovered is a valid IR Temperature Service
    func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
        testLabel.text = "Looking at peripheral services"
        for service in peripheral.services! {
            let thisService = service as CBService
            if service.UUID == BLEServiceUUID {
                peripheral.discoverCharacteristics(nil, forService: thisService)
            }
        }
    }
    
    // Enable notification and sensor for each characteristic of valid service
    func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {
        // update status label
        testLabel.text = "Enabling sensors"
        let command : [UInt8] = [0xFE, 0x07, 0x01, 0x00, 0x00, 0xFF, 0xFF, 0x00, 0xFF, 0x00, 0x03]
        let Data = NSMutableData(bytes: command, length: command.count)
        // check the uuid of each characteristic to find config and data characteristics
        for charateristic in service.characteristics! {
            let thisCharacteristic = charateristic as CBCharacteristic
            // check for data characteristic
            if thisCharacteristic.UUID == BLECharacteristicUUID {
                self.motorPeripheral.writeValue(Data, forCharacteristic: thisCharacteristic, type: CBCharacteristicWriteType.WithoutResponse)
            }
        }
    }


}

