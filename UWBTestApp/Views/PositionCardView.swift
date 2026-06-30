//
//  PositionCardView.swift
//  UWBTestApp
//
import SwiftUI

struct PositionCardView: View {
    let position: Vector2D?
    let activeSensors: Int

    var body: some View {
        if let pos = position {
            HStack(spacing: 0) {
                coordinateCell(label: "X", value: pos.x, icon: "arrow.left.and.right")
                Divider()
                    .padding(.vertical, 6)
                coordinateCell(label: "Y", value: pos.y, icon: "arrow.up.and.down")
            }
            .padding(.vertical, 4)
        } else {
            HStack(spacing: 10) {
                Image(systemName: "antenna.radiowaves.left.and.right.slash")
                    .foregroundStyle(.secondary)
                Text(waitingMessage)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 8)
        }
    }

    private func coordinateCell(label: String, value: Double, icon: String) -> some View {
        VStack(alignment: .center, spacing: 4) {
            Label(label, systemImage: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(String(format: "%.3f m", value))
                .font(.system(.title2, design: .monospaced))
                .bold()
        }
        .frame(maxWidth: .infinity)
    }

    private var waitingMessage: String {
        let needed = max(0, 3 - activeSensors)
        if needed == 0 {
            return "Calculando posicion..."
        } else if needed == 1 {
            return "Necesita 1 sensor mas"
        } else {
            return "Necesita \(needed) sensores mas"
        }
    }
}
