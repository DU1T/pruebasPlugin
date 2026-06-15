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
                filterSection
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

    private var filterSection: some View {
        Section {
            Toggle(
                "Filtrar por distancia",
                isOn: Binding(
                    get: { viewModel.state.distanceFilterEnabled },
                    set: { viewModel.state.distanceFilterEnabled = $0 }
                )
            )

            if viewModel.state.distanceFilterEnabled {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Distancia máxima")
                        Spacer()
                        Text(String(format: "%.1f m", viewModel.state.maxConnectionDistance))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(
                        value: Binding(
                            get: { viewModel.state.maxConnectionDistance },
                            set: { viewModel.state.maxConnectionDistance = $0 }
                        ),
                        in: 0.5...20.0,
                        step: 0.5
                    )
                }
            }
        } header: {
            Text("Filtro de distancia")
        } footer: {
            if viewModel.state.distanceFilterEnabled {
                Text("Sensores a más de \(String(format: "%.1f", viewModel.state.maxConnectionDistance))m se excluyen del cálculo de posición (naranja). Se re-incluyen automáticamente al volver al rango.")
                    .font(.caption)
            }
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
                        isConnected: viewModel.state.connectedDevices.contains(sensorId),
                        isOutOfRange: viewModel.state.outOfRangeDevices.contains(sensorId)
                    )
                }
            }
        } header: {
            HStack {
                Text("Sensores")
                Spacer()
                let inRange = viewModel.state.inRangeSensorCount
                let total = viewModel.state.mapSensors.count
                Text("\(inRange)/\(total) en rango")
                    .font(.caption)
                    .foregroundStyle(inRange > 0 ? .green : .secondary)
            }
        }
    }

    private var positionSection: some View {
        Section("Posicion calculada") {
            PositionCardView(
                position: viewModel.state.filteredPos,
                activeSensors: viewModel.state.inRangeSensorCount
            )
        }
    }
}
