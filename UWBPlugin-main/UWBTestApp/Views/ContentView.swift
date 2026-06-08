//
//  ContentView.swift
//  UWBTestApp
//
import SwiftUI

struct ContentView: View {
    @Environment(ViewModel.self) private var viewModel

    var body: some View {
        NavigationStack {
            List {
                mapSection
                sensorsSection
                positionSection
            }
            .navigationTitle("UWB Monitor")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Sections

    private var mapSection: some View {
        Section("Mapa de anchors") {
            Picker(
                "Mapa",
                selection: Binding(
                    get: { viewModel.selectedMap },
                    set: { viewModel.changeMap($0) }
                )
            ) {
                ForEach(viewModel.availableMaps, id: \.self) { map in
                    Text(map).tag(map)
                }
            }
            .pickerStyle(.menu)
        }
    }

    private var sensorsSection: some View {
        Section {
            if viewModel.state.mapSensors.isEmpty {
                HStack {
                    ProgressView()
                        .padding(.trailing, 4)
                    Text("Cargando sensores...")
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(viewModel.state.mapSensors, id: \.self) { sensorId in
                    SensorRowView(
                        sensorId: sensorId,
                        rssi: viewModel.state.discoveredDevices[sensorId],
                        distance: viewModel.state.distances[sensorId],
                        isConnected: viewModel.state.connectedDevices.contains(sensorId)
                    )
                }
            }
        } header: {
            HStack {
                Text("Sensores")
                Spacer()
                let connected = viewModel.state.connectedDevices.count
                let total = viewModel.state.mapSensors.count
                Text("\(connected)/\(total) conectados")
                    .font(.caption)
                    .foregroundStyle(connected > 0 ? .green : .secondary)
            }
        }
    }

    private var positionSection: some View {
        Section("Posicion calculada") {
            PositionCardView(
                position: viewModel.state.filteredPos,
                activeSensors: viewModel.state.connectedDevices.count
            )
        }
    }
}
