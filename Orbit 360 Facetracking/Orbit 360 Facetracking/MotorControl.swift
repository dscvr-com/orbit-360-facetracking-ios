//
//  MotorControl.swift
//  Orbit 360 Facetracking
//
//  Created by Philipp Meyer on 24.10.16.
//  Copyright © 2016 Philipp Meyer. All rights reserved.
//

import Foundation
import CoreBluetooth

class MotorControl: NSObject {
    var service : CBService
    var peripheral : CBPeripheral
    
    init(s: CBService, p: CBPeripheral) {
        service = s
        peripheral = p
        super.init()
    }
    
    func sendCommand(opCode: UInt8, data: [UInt8]) {
        var command : [UInt8] = [0xFE]
        let lengthOfData = UInt8(data.count)
        command.append(lengthOfData)
        command.append(opCode)
        command.appendContentsOf(data)
        
        var checksum = UInt32(0)
        for c in command {
            checksum += UInt32(c)
        }
        
        let crc = UInt8(checksum & 0xFF)
        command.append(crc)
        
        let Data = NSMutableData(bytes: command, length: command.count)
        for characteristic in service.characteristics! {
            let thisCharacteristic = characteristic as CBCharacteristic
            // check for data characteristic
            if thisCharacteristic.UUID == BLECharacteristicUUID {
                self.peripheral.writeValue(Data, forCharacteristic: thisCharacteristic, type: CBCharacteristicWriteType.WithoutResponse)
            }
        }
    }
    
    func moveX(steps: Int32) {
        var command = toByteArray(steps)
        command = command.reverse()
        command.append(0x00)
        command.append(0xFF)
        command.append(0x00)
        sendCommand(0x01, data: command)
    }
    
    func sendStop() {
        sendCommand(0x04, data: [])
    }
    
    func toByteArray<T>(var value: T) -> [UInt8] {
        return withUnsafePointer(&value) {
            Array(UnsafeBufferPointer(start: UnsafePointer<UInt8>($0), count: sizeof(T)))
        }
    }


}