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
let BLEServiceUUID = CBUUID(string: "1000")
let BLECharacteristicUUID = CBUUID(string: "1001")

class BTService: NSObject, CBPeripheralDelegate {
    var peripheral: CBPeripheral?
    var characteristic: CBCharacteristic?
    
    init(initWithPeripheral peripheral: CBPeripheral) {
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
            }
        }
    }
    
    func sendCommand(service: CBService) {
        let command : [UInt8] = [0xFE, 0x07, 0x01, 0x00, 0x00, 0xFF, 0xFF, 0x00, 0xFF, 0x00, 0x03]
        let Data = NSMutableData(bytes: command, length: command.count)
        for characteristic in service.characteristics! {
            let thisCharacteristic = characteristic as CBCharacteristic
            // check for data characteristic
            if thisCharacteristic.UUID == BLECharacteristicUUID {
                self.peripheral!.writeValue(Data, forCharacteristic: thisCharacteristic, type: CBCharacteristicWriteType.WithoutResponse)
            }
        }
    }
    
}