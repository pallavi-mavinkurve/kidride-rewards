import SwiftUI

struct VirtualCarSimulatorView: View {
    @Environment(\.scenePhase) private var scenePhase

    @State private var throttle: Double = 0.25
    @State private var brake: Double = 0.0
    @State private var steering: Double = 0.0
    @State private var speedMph: Double = 0.0
    @State private var batteryPercent: Double = 100
    @State private var lapProgress: Double = 0.0
    @State private var overallSafetyScore: Int = 100
    @State private var isRunning = false
    @State private var appSwitchDistractions = 0
    @State private var inattentionDistractions = 0
    @State private var lastControlInteractionAt = Date()
    @State private var inattentionWindowTriggered = false
    @State private var speedPenaltyValue: Int = 0
    @State private var brakingPenaltyValue: Int = 0
    @State private var steeringPenaltyValue: Int = 0
    @State private var distractionPenaltyValue: Int = 0

    private let tick = Timer.publish(every: 0.12, on: .main, in: .common).autoconnect()
    private let safeSpeedThresholdMph = 16.0
    private let warningSpeedThresholdMph = 20.0
    private let inattentionWindowSeconds = 6.0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    trackCard
                    controlsCard
                    statsCard
                    criteriaCard
                }
                .padding()
            }
            .background(AppTheme.appBackground)
            .navigationTitle("Virtual Car")
            .onReceive(tick) { _ in
                guard isRunning else { return }
                updateSimulationStep()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if isRunning, speedMph > 2, newPhase != .active {
                    appSwitchDistractions += 1
                }
            }
            .onChange(of: throttle) { _, _ in registerControlInteraction() }
            .onChange(of: brake) { _, _ in registerControlInteraction() }
            .onChange(of: steering) { _, _ in registerControlInteraction() }
        }
    }

    private var trackCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Simulator Track")
                .font(.headline)
                .foregroundStyle(AppTheme.navy)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AppTheme.deepNavy.opacity(0.9))
                    Capsule()
                        .fill(.white.opacity(0.15))
                        .frame(height: 10)
                        .padding(.horizontal, 14)

                    Image(systemName: "car.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .rotationEffect(.degrees(steering * 15))
                        .offset(x: 16 + (geo.size.width - 52) * lapProgress, y: 0)
                }
            }
            .frame(height: 90)

            ProgressView(value: lapProgress) {
                Text("Lap progress")
                    .font(.caption)
            }
            .tint(AppTheme.softBlue)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: AppTheme.navy.opacity(0.06), radius: 8, x: 0, y: 3)
    }

    private var controlsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Controls")
                .font(.headline)
                .foregroundStyle(AppTheme.navy)

            sliderRow(title: "Throttle", value: $throttle, color: .green)
            sliderRow(title: "Brake", value: $brake, color: .red)
            sliderRow(title: "Steering", value: $steering, range: -1...1, color: AppTheme.softBlue)

            HStack(spacing: 10) {
                Button(isRunning ? "Pause" : "Start") {
                    isRunning.toggle()
                    if isRunning {
                        registerControlInteraction()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.navy)

                Button("Reset") {
                    isRunning = false
                    speedMph = 0
                    batteryPercent = 100
                    lapProgress = 0
                    overallSafetyScore = 100
                    appSwitchDistractions = 0
                    inattentionDistractions = 0
                    speedPenaltyValue = 0
                    brakingPenaltyValue = 0
                    steeringPenaltyValue = 0
                    distractionPenaltyValue = 0
                    inattentionWindowTriggered = false
                    lastControlInteractionAt = Date()
                    throttle = 0.25
                    brake = 0
                    steering = 0
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var statsCard: some View {
        HStack {
            statPill(title: "Speed", value: "\(Int(speedMph)) mph", icon: "speedometer")
            statPill(title: "Battery", value: "\(Int(batteryPercent))%", icon: "battery.75")
            statPill(title: "Safety", value: "\(overallSafetyScore)/100", icon: "checkmark.shield.fill")
        }
    }

    private var criteriaCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Safety Criteria")
                .font(.headline)
                .foregroundStyle(AppTheme.navy)

            Text("Thresholds: safe speed <= \(Int(safeSpeedThresholdMph)) mph, warning speed <= \(Int(warningSpeedThresholdMph)) mph, inattention > \(Int(inattentionWindowSeconds))s while moving.")
                .font(.caption)
                .foregroundStyle(.secondary)

            criteriaRow("Speed penalty", speedPenaltyValue)
            criteriaRow("Braking penalty", brakingPenaltyValue)
            criteriaRow("Steering penalty", steeringPenaltyValue)
            criteriaRow("Distracted driving penalty", distractionPenaltyValue)

            Text("Distraction events: app switches \(appSwitchDistractions), inattention \(inattentionDistractions)")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func statPill(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .foregroundStyle(AppTheme.navy)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: AppTheme.navy.opacity(0.05), radius: 6, x: 0, y: 2)
    }

    private func sliderRow(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double> = 0...1,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(formattedValue(for: title, value: value.wrappedValue))
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
            Slider(value: value, in: range)
                .tint(color)
        }
    }

    private func criteriaRow(_ title: String, _ value: Int) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(value)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.navy)
        }
    }

    private func formattedValue(for title: String, value: Double) -> String {
        if title == "Steering" {
            return String(format: "%.2f", value)
        }
        return "\(Int(value * 100))%"
    }

    private func updateSimulationStep() {
        let acceleration = max(0, throttle - (brake * 1.15))
        let targetSpeed = acceleration * 42
        speedMph += (targetSpeed - speedMph) * 0.18
        speedMph = max(0, min(48, speedMph))

        lapProgress += (speedMph / 900.0)
        if lapProgress >= 1 {
            lapProgress -= 1
        }

        batteryPercent -= (throttle * 0.22 + abs(steering) * 0.04)
        batteryPercent = max(0, batteryPercent)

        detectInattentionIfNeeded()

        let speedRisk = speedPenalty(for: speedMph)
        let brakingRisk = brakingPenalty(for: brake)
        let steeringRisk = steeringPenalty(for: steering)
        let distractionRisk = distractionPenalty()

        speedPenaltyValue = Int(speedRisk)
        brakingPenaltyValue = Int(brakingRisk)
        steeringPenaltyValue = Int(steeringRisk)
        distractionPenaltyValue = Int(distractionRisk)

        let computedSafety = 100 - Int(speedRisk + brakingRisk + steeringRisk + distractionRisk)
        overallSafetyScore = max(40, min(100, computedSafety))

        if batteryPercent == 0 {
            isRunning = false
            speedMph = 0
        }
    }

    private func registerControlInteraction() {
        lastControlInteractionAt = Date()
        inattentionWindowTriggered = false
    }

    private func detectInattentionIfNeeded() {
        guard speedMph > 8 else {
            inattentionWindowTriggered = false
            return
        }

        let idleSeconds = Date().timeIntervalSince(lastControlInteractionAt)
        if idleSeconds >= inattentionWindowSeconds, !inattentionWindowTriggered {
            inattentionDistractions += 1
            inattentionWindowTriggered = true
        }
    }

    private func speedPenalty(for speed: Double) -> Double {
        if speed <= safeSpeedThresholdMph { return 0 }
        if speed <= warningSpeedThresholdMph {
            return (speed - safeSpeedThresholdMph) * 1.5
        }
        let moderate = (warningSpeedThresholdMph - safeSpeedThresholdMph) * 1.5
        return moderate + (speed - warningSpeedThresholdMph) * 2.5
    }

    private func brakingPenalty(for brakeValue: Double) -> Double {
        if brakeValue <= 0.35 { return 0 }
        if brakeValue <= 0.65 {
            return (brakeValue - 0.35) * 36
        }
        return ((0.65 - 0.35) * 36) + ((brakeValue - 0.65) * 55)
    }

    private func steeringPenalty(for steeringValue: Double) -> Double {
        let absolute = abs(steeringValue)
        if absolute <= 0.45 { return 0 }
        if absolute <= 0.75 {
            return (absolute - 0.45) * 24
        }
        return ((0.75 - 0.45) * 24) + ((absolute - 0.75) * 42)
    }

    private func distractionPenalty() -> Double {
        let appSwitchRisk = Double(appSwitchDistractions * 12)
        let inattentionRisk = Double(inattentionDistractions * 8)
        return appSwitchRisk + inattentionRisk
    }
}
