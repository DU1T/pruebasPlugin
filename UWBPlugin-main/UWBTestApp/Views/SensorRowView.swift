//
//  SensorRowView.swift
//  UWBTestApp
//
import SwiftUI

struct SensorRowView: View {
    let sensorId: String
    let rssi: Double?
    let distance: Double?
    let isConnected: Bool
    let isOutOfRange: Bool

    private var status: SensorStatus {
        if isConnected && isOutOfRange { return .outOfRange }
        if isConnected { return .connected }
        if rssi != nil { return .discovered }
        return .notSeen
    }

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(status.color)
                .frame(width: 10, height: 10)
                .animation(.easeInOut(duration: 0.3), value: status)

            VStack(alignment: .leading, spacing: 2) {
                Text("…\(shortId)")
                    .font(.system(.body, design: .monospaced))
                Text(status.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                if let distance {
                    Text(String(format: "%.2f m", distance))
                        .font(.system(.callout, design: .monospaced))
                        .bold()
                        .foregroundStyle(isOutOfRange ? .orange : .primary)
                    Text(isOutOfRange ? "fuera de rango" : "distancia")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else if let rssi {
                    Text("\(Int(rssi)) dBm")
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text("RSSI")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var shortId: String {
        String(sensorId.suffix(12))
    }

    private enum SensorStatus: Equatable {
        case notSeen, discovered, outOfRange, connected

        var label: String {
            switch self {
            case .notSeen:    return "No detectado"
            case .discovered: return "Descubierto"
            case .outOfRange: return "Fuera de rango"
            case .connected:  return "Conectado"
            }
        }

        var color: Color {
            switch self {
            case .notSeen:    return .gray.opacity(0.35)
            case .discovered: return .yellow
            case .outOfRange: return .orange
            case .connected:  return .green
            }
        }
    }
}
