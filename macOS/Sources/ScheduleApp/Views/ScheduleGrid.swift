import SwiftUI
import ScheduleCore

struct CellAddress: Hashable { let row: Int; let column: Int }

private enum AvailabilityPalette {
    static func ink(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.39, green: 0.94, blue: 0.65) : Color(red: 0.03, green: 0.46, blue: 0.25)
    }
    static func fill(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.08, green: 0.31, blue: 0.20) : Color(red: 0.73, green: 0.95, blue: 0.82)
    }
}

// Equality lets SwiftUI skip rebuilding the other 181 cells after a single edit.
private struct ScheduleSlotView: View, Equatable {
    let busy: Bool
    let enabled: Bool
    let sourceDate: String
    let dayLabel: String
    let time: String
    let scheme: ColorScheme
    let action: () -> Void

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.busy == rhs.busy && lhs.enabled == rhs.enabled && lhs.sourceDate == rhs.sourceDate && lhs.dayLabel == rhs.dayLabel
            && lhs.time == rhs.time && lhs.scheme == rhs.scheme
    }
    var body: some View {
        Button(action: action) {
            Image(systemName: busy ? "minus" : "checkmark")
                .font(.system(size: 12, weight: .semibold))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .foregroundStyle(busy ? Color.secondary : AvailabilityPalette.ink(scheme))
                .background(busy ? Color.secondary.opacity(0.09) : AvailabilityPalette.fill(scheme),
                            in: RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain).padding(3).disabled(!enabled)
        .accessibilityLabel("\(dayLabel), \(time), \(busy ? Texts.busy : Texts.free)")
        .help("\(time) · \(busy ? Texts.busy : Texts.free). Нажмите, чтобы изменить.")
    }
}

struct ScheduleGrid: View {
    @ObservedObject var model: ScheduleViewModel
    let schedule: Schedule
    @State private var lastPoint: CGPoint?
    @State private var dragging = false
    @FocusState private var focused: CellAddress?
    @Environment(\.colorScheme) private var colorScheme
    private let rowHeight: CGFloat = 38
    private let timeWidth: CGFloat = 76

    var body: some View {
        if let layout = model.gridLayout {
            let today = TimeZoneService.dateKey(Date(), zone: schedule.timeZone)
            GeometryReader { geometry in
                let columnWidth = max(86, (geometry.size.width - timeWidth) / 7)
                ScrollView([.vertical, .horizontal]) {
                    LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                        Section {
                            VStack(spacing: 0) {
                                ForEach(Array(layout.slotTimes.enumerated()), id: \.offset) { row, time in
                                    HStack(spacing: 0) {
                                        Text(time).font(.system(size: 15, weight: .medium, design: .monospaced))
                                            .foregroundStyle(.secondary).frame(width: timeWidth, height: rowHeight)
                                        ForEach(Array(layout.days.enumerated()), id: \.offset) { column, day in
                                            ScheduleSlotView(busy: schedule.isBusy(date: day.id, time: time),
                                                             enabled: !model.isWorking, sourceDate: day.id, dayLabel: day.accessibilityLabel,
                                                             time: time, scheme: colorScheme) {
                                                if !dragging { model.toggle(date: day.id, time: time) }
                                            }
                                            .equatable()
                                            .focused($focused, equals: CellAddress(row: row, column: column))
                                            .frame(width: columnWidth, height: rowHeight)
                                        }
                                    }
                                }
                            }
                            .coordinateSpace(name: "paint-grid")
                            .highPriorityGesture(DragGesture(minimumDistance: 3, coordinateSpace: .named("paint-grid"))
                                .onChanged { event in
                                    guard !model.isWorking else { return }
                                    if !dragging {
                                        guard let first = address(event.startLocation, columnWidth: columnWidth, rowCount: layout.slotTimes.count) else { return }
                                        dragging = true; lastPoint = event.startLocation
                                        model.beginPaint(date: layout.days[first.column].id, time: layout.slotTimes[first.row])
                                    }
                                    let from = lastPoint ?? event.startLocation
                                    let distance = hypot(event.location.x - from.x, event.location.y - from.y)
                                    let steps = max(1, Int(distance / 8))
                                    var cells = Set<SlotReference>()
                                    for i in 1...steps {
                                        let t = CGFloat(i) / CGFloat(steps)
                                        let point = CGPoint(x: from.x + (event.location.x - from.x) * t,
                                                            y: from.y + (event.location.y - from.y) * t)
                                        if let cell = address(point, columnWidth: columnWidth, rowCount: layout.slotTimes.count) {
                                            cells.insert(SlotReference(date: layout.days[cell.column].id, time: layout.slotTimes[cell.row]))
                                        }
                                    }
                                    // One published update per pointer event, not per interpolated point.
                                    model.paint(cells: Array(cells))
                                    lastPoint = event.location
                                }
                                .onEnded { _ in model.endPaint(); dragging = false; lastPoint = nil })
                        } header: {
                            HStack(spacing: 0) {
                                Text("Время").font(.caption).foregroundStyle(.secondary).frame(width: timeWidth)
                                ForEach(layout.days) { day in
                                    VStack(spacing: 5) {
                                        Text(day.weekday).foregroundStyle(.secondary)
                                        Text(day.shortDate).fontWeight(.semibold)
                                    }
                                    .font(.callout).frame(width: columnWidth, height: 62)
                                    .background(day.id == today ? AvailabilityPalette.fill(colorScheme).opacity(0.5) : .clear)
                                    .contextMenu {
                                        Button("Отметить весь день занятым") { model.setDay(day.id, busy: true) }
                                        Button("Очистить весь день") { model.setDay(day.id, busy: false) }
                                    }
                                    .accessibilityLabel(day.accessibilityLabel)
                                }
                            }.background(.regularMaterial)
                        }
                    }.frame(width: timeWidth + columnWidth * 7)
                }
                .onMoveCommand { direction in
                    var cell = focused ?? CellAddress(row: 0, column: 0)
                    switch direction {
                    case .up: cell = CellAddress(row: max(0, cell.row - 1), column: cell.column)
                    case .down: cell = CellAddress(row: min(layout.slotTimes.count - 1, cell.row + 1), column: cell.column)
                    case .left: cell = CellAddress(row: cell.row, column: max(0, cell.column - 1))
                    case .right: cell = CellAddress(row: cell.row, column: min(6, cell.column + 1))
                    default: break
                    }; focused = cell
                }
                .onDisappear { model.endPaint() }
            }
        }
    }
    private func address(_ point: CGPoint, columnWidth: CGFloat, rowCount: Int) -> CellAddress? {
        guard point.x >= timeWidth, point.y >= 0 else { return nil }
        let row = Int(point.y / rowHeight), column = Int((point.x - timeWidth) / columnWidth)
        guard row < rowCount, column < 7 else { return nil }
        return CellAddress(row: row, column: column)
    }
}
