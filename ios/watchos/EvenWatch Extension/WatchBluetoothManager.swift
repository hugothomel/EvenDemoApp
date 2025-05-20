import Foundation
import CoreBluetooth
import Combine

class WatchBluetoothManager: NSObject, ObservableObject {
    static let shared = WatchBluetoothManager()

    @Published var isScanning = false
    @Published var isConnected = false
    @Published var discoveredDevice: String?

    private var centralManager: CBCentralManager!
    private var leftPeripheral: CBPeripheral?
    private var rightPeripheral: CBPeripheral?
    private var leftUUIDStr: String?
    private var rightUUIDStr: String?
    private var leftWChar: CBCharacteristic?
    private var rightWChar: CBCharacteristic?
    private var UARTServiceUUID = CBUUID(string: ServiceIdentifiers.uartServiceUUIDString)
    private var UARTRXCharacteristicUUID = CBUUID(string: ServiceIdentifiers.uartRXCharacteristicUUIDString)
    private var UARTTXCharacteristicUUID = CBUUID(string: ServiceIdentifiers.uartTXCharacteristicUUIDString)
    private var pairedDevices: [String: (CBPeripheral?, CBPeripheral?)] = [:]
    private var currentConnectingDeviceName: String?

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func startScan() {
        guard centralManager.state == .poweredOn else { return }
        isScanning = true
        centralManager.scanForPeripherals(withServices: nil, options: nil)
    }

    func stopScan() {
        centralManager.stopScan()
        isScanning = false
    }

    func connectToDevice(deviceName: String) {
        stopScan()
        guard let pair = pairedDevices[deviceName], let left = pair.0, let right = pair.1 else { return }
        currentConnectingDeviceName = deviceName
        centralManager.connect(left, options: nil)
        centralManager.connect(right, options: nil)
    }

    func disconnect() {
        if let left = leftPeripheral { centralManager.cancelPeripheralConnection(left) }
        if let right = rightPeripheral { centralManager.cancelPeripheralConnection(right) }
        isConnected = false
    }
}

extension WatchBluetoothManager: CBCentralManagerDelegate, CBPeripheralDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {}

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        guard let name = peripheral.name else { return }
        let components = name.components(separatedBy: "_")
        guard components.count > 1, let channelNumber = components[safe: 1] else { return }

        if name.contains("_L_") {
            pairedDevices["Pair_\(channelNumber)", default: (nil, nil)].0 = peripheral
        } else if name.contains("_R_") {
            pairedDevices["Pair_\(channelNumber)", default: (nil, nil)].1 = peripheral
        }

        if pairedDevices["Pair_\(channelNumber)"]?.0 != nil && pairedDevices["Pair_\(channelNumber)"]?.1 != nil {
            discoveredDevice = "Pair_\(channelNumber)"
            stopScan()
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard let deviceName = currentConnectingDeviceName else { return }
        guard let pair = pairedDevices[deviceName] else { return }

        if pair.0 === peripheral {
            leftPeripheral = peripheral
            leftPeripheral?.delegate = self
            leftUUIDStr = peripheral.identifier.uuidString
            peripheral.discoverServices([UARTServiceUUID])
        } else if pair.1 === peripheral {
            rightPeripheral = peripheral
            rightPeripheral?.delegate = self
            rightUUIDStr = peripheral.identifier.uuidString
            peripheral.discoverServices([UARTServiceUUID])
        }

        if leftPeripheral != nil && rightPeripheral != nil {
            isConnected = true
            currentConnectingDeviceName = nil
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services where service.uuid == UARTServiceUUID {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics {
            if characteristic.uuid == UARTRXCharacteristicUUID {
                if peripheral.identifier.uuidString == leftUUIDStr {
                    peripheral.setNotifyValue(true, for: characteristic)
                } else if peripheral.identifier.uuidString == rightUUIDStr {
                    peripheral.setNotifyValue(true, for: characteristic)
                }
            } else if characteristic.uuid == UARTTXCharacteristicUUID {
                if peripheral.identifier.uuidString == leftUUIDStr {
                    leftWChar = characteristic
                } else if peripheral.identifier.uuidString == rightUUIDStr {
                    rightWChar = characteristic
                }
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil, let data = characteristic.value else { return }
        // handle incoming data if needed
        print("Received \(data.count) bytes")
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
