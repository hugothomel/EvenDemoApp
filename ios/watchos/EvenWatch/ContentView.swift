import SwiftUI

struct ContentView: View {
    @StateObject private var bluetoothManager = WatchBluetoothManager()
    
    var body: some View {
        VStack {
            if bluetoothManager.isScanning {
                Text("Scanning...")
            } else {
                Button("Scan") {
                    bluetoothManager.startScan()
                }
            }
            if let device = bluetoothManager.discoveredDevice {
                Button("Connect to \(device)") {
                    bluetoothManager.connectToDevice(deviceName: device)
                }
            }
            if bluetoothManager.isConnected {
                Button("Disconnect") {
                    bluetoothManager.disconnect()
                }
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
