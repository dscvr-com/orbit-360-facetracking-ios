//
//  BLEDiscovery.swift
//  Orbit 360 Facetracking
//
//  Created by Philipp Meyer on 17.10.16.
//  Copyright © 2016 Philipp Meyer. All rights reserved.
//

import Foundation
import CoreBluetooth

class BTDiscovery: NSObject, CBCentralManagerDelegate {

    private var centralManager: CBCentralManager!
    private var onDeviceFound: (CBPeripheral, NSString) -> Void
    private var onDeviceConnected: (CBPeripheral) -> Void
    
    init(onDeviceFound: (CBPeripheral, NSString) -> Void, onDeviceConnected: (CBPeripheral) -> Void) {
        self.onDeviceFound = onDeviceFound
        self.onDeviceConnected = onDeviceConnected
        
        super.init()
        
        self.centralManager = CBCentralManager(delegate: self, queue: dispatch_get_main_queue())
    }
    
    func startScanning() {
        centralManager.scanForPeripheralsWithServices(nil, options: nil)
        print("Searching for BLE Devices")
        
    }
    
    var bleService: BTService? {
        didSet {
            if let service = self.bleService {
                service.startDiscoveringServices()
            }
        }
    }

    
    func centralManagerDidUpdateState(central: CBCentralManager) {
        switch (central.state) {
        case .PoweredOff:
            break;
        case .Unauthorized:
            // Indicate to user that the iOS device does not support BLE.
            break
            
        case .Unknown:
            // Wait for another event
            break
            
        case .PoweredOn:
            self.startScanning()
            
        case .Resetting:
            break;
        case .Unsupported:
            break;
        }
    }
    
    func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : AnyObject], RSSI: NSNumber) {
        let nameOfDeviceFound = (advertisementData as NSDictionary).objectForKey(CBAdvertisementDataLocalNameKey) as? NSString
        
        if let name = nameOfDeviceFound {
            self.onDeviceFound(peripheral, name)
        }
        
    }
    
    func connectPeripheral(peripheral: CBPeripheral) {
        // Connect to peripheral
        centralManager.connectPeripheral(peripheral, options: nil)
    }
    
    func centralManager(central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {
        
        //let bleService = BTService(initWithPeripheral: peripheral)
        self.onDeviceConnected(peripheral)
        print(peripheral)
        // Stop scanning for new devices
        central.stopScan()
    }
    
    func centralManager(central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        
        // Start scanning for new devices
        self.startScanning()
    }

}
