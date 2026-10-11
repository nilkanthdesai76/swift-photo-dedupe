import SwiftUI
import PhotoHashKit

public struct ThermalGaugeView: View {
    @ObservedObject var viewModel: DedupeViewModel
    
    public init(viewModel: DedupeViewModel) {
        self.viewModel = viewModel
    }
    
    private var statusColor: Color {
        let text = viewModel.thermalStateDescription.lowercased()
        if text.contains("nominal") || text.contains("cold") {
            return .green
        } else if text.contains("fair") || text.contains("warm") {
            return .yellow
        } else {
            return .red
        }
    }
    
    public var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .shadow(color: statusColor.opacity(0.6), radius: 4)
            
            VStack(alignment: .leading, spacing: 1) {
                Text("Device Thermal State")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                
                Text(viewModel.thermalStateDescription)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.primary)
            }
            
            Spacer()
            
            Image(systemName: "snowflake")
                .font(.system(size: 12))
                .foregroundStyle(.blue)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(statusColor.opacity(0.25), lineWidth: 1)
                )
        )
    }
}
