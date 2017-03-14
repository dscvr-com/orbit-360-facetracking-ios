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
let BLEServiceUUID = CBUUID(string: "69400001-B5A3-F393-E0A9-E50E24DCCA99")
let BLECharacteristicUUID = CBUUID(string: "69400002-B5A3-F393-E0A9-E50E24DCCA99")
let BLECharacteristicResponseUUID = CBUUID(string: "69400003-B5A3-F393-E0A9-E50E24DCCA99")
var yMotorPosition = 0


class BTService: NSObject, CBPeripheralDelegate {
    var peripheral: CBPeripheral?
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
        let uuidsForBTService: [CBUUID] = [BLECharacteristicUUID, BLECharacteristicResponseUUID]
        
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
            if characteristic.UUID == BLECharacteristicResponseUUID {
                peripheral.setNotifyValue(true, forCharacteristic: characteristic as CBCharacteristic)
            }
        }
        for characteristic in service.characteristics! {
            if characteristic.UUID == BLECharacteristicUUID {
                onServiceConnected(service)
            }
        }
    }

    func peripheral(peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        if characteristic.UUID.isEqual(BLECharacteristicResponseUUID) {
            let data = characteristic.value
            let numberOfBytes = data?.length
            if (numberOfBytes != 20) {
                return
            }
            var byteArray = [UInt8](count: numberOfBytes!, repeatedValue: 0)
            data?.getBytes(&byteArray, length: numberOfBytes!)
            let resultArray = [byteArray[10], byteArray[9], byteArray[8], byteArray[7]]
            let result = fromByteArray(resultArray, Int.self)
            print(resultArray)
            print(result)
            yMotorPosition = result
        }
    }

    func fromByteArray<T>(value: [UInt8], _: T.Type) -> T {
        return value.withUnsafeBufferPointer {
            return UnsafePointer<T>($0.baseAddress).memory
        }
    }

    
}
