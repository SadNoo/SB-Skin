import SBSkinShared
import SwiftUI

/// “How did it get there”: device → rule → group → node → destination, plus raw metadata.
struct ConnectionDetailPage: View {
    @Environment(SkinStore.self) private var store
    @Environment(\.skinTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    let connectionID: String

    var body: some View {
        Group {
            if let connection = store.connections.first(where: { $0.id == connectionID }) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        header(connection)
                        JourneyView(connection: connection)
                            .skinCard(theme, padding: 18)
                        TrafficSummary(connection: connection)
                        MetadataList(connection: connection)
                    }
                    .padding(16)
                    .frame(maxWidth: 720)
                    .frame(maxWidth: .infinity)
                }
                .toolbar {
                    if connection.isActive {
                        ToolbarItem(placement: .primaryAction) {
                            Button(SkinL("Close"), systemImage: "xmark.circle", role: .destructive) {
                                store.close(connection)
                            }
                        }
                    }
                }
            } else {
                ContentUnavailableView(SkinL("Connection ended"), systemImage: "arrow.left.arrow.right")
            }
        }
        .background(theme.background)
        .navigationTitle(SkinL("Connection"))
        .subscribesToConnections(store)
    }

    private func header(_ connection: SkinConnection) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(connection.hostName)
                .font(theme.font(.largeTitle, weight: .bold))
                .foregroundStyle(theme.text)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
            HStack(spacing: 6) {
                Text(verbatim: [connection.protocolName.uppercased(), connection.network.uppercased()].filter { !$0.isEmpty }.joined(separator: " · "))
                Text(verbatim: "·")
                if connection.isActive {
                    Text(skin: "Open for")
                    Text(connection.createdAt, style: .timer)
                } else {
                    Text(skin: "Closed")
                }
            }
            .font(.subheadline)
            .foregroundStyle(theme.secondaryText)
        }
    }
}

/// Vertical timeline of the route a connection took.
struct JourneyView: View {
    @Environment(\.skinTheme) private var theme
    let connection: SkinConnection
    var compactTitle = false

    struct Step: Identifiable {
        let id = UUID()
        let label: String
        let value: String
        let note: String
        let emphasis: Emphasis
        enum Emphasis { case normal, node, destination }
    }

    var steps: [Step] {
        var steps: [Step] = []
        let origin = connection.processName ?? SkinL("This device")
        steps.append(Step(label: SkinL("From"), value: origin, note: [connection.inbound, connection.source].filter { !$0.isEmpty }.joined(separator: " · "), emphasis: .normal))
        if !connection.rule.isEmpty {
            steps.append(Step(label: SkinL("Matched rule"), value: ruleCondition, note: ruleAction, emphasis: .normal))
        }
        let route = connection.route
        for group in route.dropLast() {
            steps.append(Step(label: SkinL("Handed to group"), value: group, note: "", emphasis: .normal))
        }
        if connection.isDirect {
            steps.append(Step(label: SkinL("Went"), value: SkinL("Direct"), note: SkinL("Not through a proxy"), emphasis: .node))
        } else {
            steps.append(Step(label: SkinL("Via"), value: route.last ?? connection.outbound, note: connection.outboundType, emphasis: .node))
        }
        steps.append(Step(label: SkinL("Arrived at"), value: connection.displayDestination, note: connection.domain.isEmpty ? "" : connection.destination, emphasis: .destination))
        return steps
    }

    private var ruleCondition: String {
        connection.rule.components(separatedBy: "=>").first?.trimmingCharacters(in: .whitespaces) ?? connection.rule
    }

    private var ruleAction: String {
        let parts = connection.rule.components(separatedBy: "=>")
        return parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(skin: "How it got there")
                .font(theme.font(.footnote, weight: .semibold))
                .foregroundStyle(theme.secondaryText)
                .padding(.bottom, 12)
            ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                HStack(alignment: .top, spacing: 14) {
                    VStack(spacing: 0) {
                        Text(verbatim: "\(index + 1)")
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(dotForeground(step))
                            .frame(width: 26, height: 26)
                            .background(dotBackground(step), in: Circle())
                        if index < steps.count - 1 {
                            Rectangle()
                                .fill(theme.accent.opacity(0.25))
                                .frame(width: 2)
                                .frame(minHeight: 18)
                                .frame(maxHeight: .infinity)
                        }
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(step.label)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.secondaryText)
                        Text(step.value)
                            .font(theme.font(.body, weight: .bold))
                            .foregroundStyle(theme.text)
                            .textSelection(.enabled)
                        if !step.note.isEmpty {
                            Text(step.note)
                                .font(.caption)
                                .foregroundStyle(theme.secondaryText)
                                .textSelection(.enabled)
                        }
                    }
                    .padding(.bottom, index < steps.count - 1 ? 14 : 0)
                    Spacer(minLength: 0)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func dotBackground(_ step: Step) -> Color {
        switch step.emphasis {
        case .normal: theme.accent.opacity(0.12)
        case .node: theme.accent
        case .destination: theme.text
        }
    }

    private func dotForeground(_ step: Step) -> Color {
        switch step.emphasis {
        case .normal: theme.accent
        case .node: theme.onAccent
        case .destination: theme.background
        }
    }
}

struct TrafficSummary: View {
    @Environment(\.skinTheme) private var theme
    let connection: SkinConnection

    var body: some View {
        HStack(spacing: 12) {
            cell(SkinL("Received"), SkinFormat.bytes(connection.downlinkTotal), connection.isActive ? SkinL("Now %@", SkinFormat.rate(connection.downlink)) : nil)
            cell(SkinL("Sent"), SkinFormat.bytes(connection.uplinkTotal), connection.isActive ? SkinL("Now %@", SkinFormat.rate(connection.uplink)) : nil)
        }
    }

    private func cell(_ title: String, _ value: String, _ note: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(theme.secondaryText)
            Text(value).font(theme.number(22, weight: .bold)).foregroundStyle(theme.text)
            if let note {
                Text(note).font(.caption.monospacedDigit()).foregroundStyle(theme.accent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .skinCard(theme, padding: 14)
    }
}

struct MetadataList: View {
    @Environment(\.skinTheme) private var theme
    let connection: SkinConnection

    var rows: [(String, String)] {
        var rows: [(String, String)] = [
            (SkinL("Inbound"), "\(connection.inbound) (\(connection.inboundType))"),
            (SkinL("Source"), connection.source),
            (SkinL("Destination"), connection.destination),
        ]
        if !connection.domain.isEmpty { rows.append((SkinL("Domain"), connection.domain)) }
        rows.append((SkinL("Network"), "\(connection.network.uppercased()) · IPv\(connection.ipVersion)"))
        if !connection.protocolName.isEmpty { rows.append((SkinL("Protocol"), connection.protocolName)) }
        if !connection.user.isEmpty { rows.append((SkinL("User"), connection.user)) }
        if !connection.fromOutbound.isEmpty { rows.append((SkinL("From outbound"), connection.fromOutbound)) }
        if !connection.rule.isEmpty { rows.append((SkinL("Rule"), connection.rule)) }
        rows.append((SkinL("Outbound"), "\(connection.outbound) (\(connection.outboundType))"))
        if connection.chain.count > 1 { rows.append((SkinL("Chain"), connection.route.joined(separator: " / "))) }
        if let processPath = connection.processPath, !processPath.isEmpty { rows.append((SkinL("Process"), processPath)) }
        rows.append((SkinL("Created"), connection.createdAt.formatted(date: .abbreviated, time: .standard)))
        if let closedAt = connection.closedAt { rows.append((SkinL("Closed"), closedAt.formatted(date: .abbreviated, time: .standard))) }
        return rows
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(row.0)
                        .font(.footnote)
                        .foregroundStyle(theme.secondaryText)
                        .frame(width: 96, alignment: .leading)
                    Text(row.1)
                        .font(.footnote.monospaced())
                        .foregroundStyle(theme.text)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 9)
                if index < rows.count - 1 {
                    Divider().overlay(theme.separator)
                }
            }
        }
        .skinCard(theme, padding: 14)
    }
}
