//
//  BLEService.swift
//  Orbit 360 Facetracking
//
//  Created by Philipp Meyer on 17.10.16.
//  Copyright © 2016 Philipp Meyer. All rights reserved.
//

import Foundation
import CoreBluetooth

// Services & Characteristics UUIDs
// TODO EJ - pass from outside via constructor 
let BLEServiceUUID = CBUUID(string: "1000")
let BLECharacteristicUUID = CBUUID(string: "1001")

class BTService: NSObject, CBPeripheralDelegate {
    var peripheral: CBPeripheral?
    var characteristic: CBCharacteristic?
    var onServiceConnected: (CBService) -> Void
    
    init(initWithPeripheral peripheral: CBPeripheral, onServiceConnected: (CBService) -> Void) {
        self.onServiceConnected = onServiceConnected
        
        super.init()
        
        self.peripheral = peripheral
        self.peripheral?.delegate = self
    }
    
    deinit {
        self.reset()
    }
    
    func startDiscoveringServices() {
        self.peripheral?.discoverServices([BLEServiceUUID])
    }
    
    func reset() {
        if peripheral != nil {
            peripheral = nil
        }
    }

    func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
        let uuidsForBTService: [CBUUID] = [BLECharacteristicUUID]
        
        if (peripheral != self.peripheral) {
            // Wrong Peripheral
            return
        }
        
        if (error != nil) {
            return
        }
        
        if ((peripheral.services == nil) || (peripheral.services!.count == 0)) {
            // No Services
            return
        }
        
        for service in peripheral.services! {
            if service.UUID == BLEServiceUUID {
                peripheral.discoverCharacteristics(uuidsForBTService, forService: service as CBService)
            }
        }
    }
    
    func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {
        if (peripheral != self.peripheral) {
            // Wrong Peripheral
            return
        }
        
        if (error != nil) {
            return
        }
        
        for characteristic in service.characteristics! {
            //println(characteristic)
            if characteristic.UUID == BLECharacteristicUUID {
                self.characteristic = (characteristic as CBCharacteristic)
                peripheral.setNotifyValue(true, forCharacteristic: characteristic as CBCharacteristic)
                
                onServiceConnected(service)
            }
        }
    }
    
}