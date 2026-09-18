import SwiftUI
import ScheduleCore

struct CellAddress: Hashable { let row: Int; let column: Int }

struct ScheduleGrid: View {
    @ObservedObject var model: ScheduleViewModel
    let schedule: Schedule
    @State private var lastPoint: CGPoint?
    @State private var dragging = false
    @FocusState private var focused: CellAddress?
    @Environment(\.colorScheme) private var colorScheme
    private var availabilityColor: Color {
        colorScheme == .dark ? Color(red: 0.48, green: 0.85, blue: 0.69) : Color(red: 0.08, green: 0.36, blue: 0.28)
    }
    private let rowHeight: CGFloat = 38
    private let timeWidth: CGFloat = 68

    var body: some View {
        GeometryReader { geometry in
            let columnWidth = max(86, (geometry.size.width - timeWidth) / 7)
            ScrollView([.vertical, .horizontal]) {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    Section {
                        VStack(spacing: 0) {
                            ForEach(Array(schedule.slotTimes.enumerated()), id: \.offset) { row, time in
                                HStack(spacing: 0) {
                                    Text(time).font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
                                        .frame(width: timeWidth, height: rowHeight)
                                    ForEach(Array(model.dates.enumerated()), id: \.element) { column, date in
                                        slot(date: date, time: time, row: row, column: column)
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
                                    guard let first = address(event.startLocation, columnWidth: columnWidth) else { return }
                                    dragging = true; lastPoint = event.startLocation
                                    model.beginPaint(date: model.dates[first.column], time: schedule.slotTimes[first.row])
                                }
                                let from = lastPoint ?? event.startLocation
                                let distance = hypot(event.location.x - from.x, event.location.y - from.y)
                                let steps = max(1, Int(distance / 8))
                                for i in 1...steps {
                                    let t = CGFloat(i) / CGFloat(steps)
                                    let point = CGPoint(x: from.x + (event.location.x - from.x) * t, y: from.y + (event.location.y - from.y) * t)
                                    if let cell = address(point, columnWidth: columnWidth) { model.paint(date: model.dates[cell.column], time: schedule.slotTimes[cell.row]) }
                                }
                                lastPoint = event.location
                            }
                            .onEnded { _ in model.endPaint(); dragging = false; lastPoint = nil })
                    } header: {
                        HStack(spacing: 0) {
                            Text("Время").font(.caption).foregroundStyle(.secondary).frame(width: timeWidth)
                            ForEach(model.dates, id: \.self) { date in
                                VStack(spacing: 5) {
                                    Text(TimeZoneService.display(date, format: "EEE")).foregroundStyle(.secondary)
                                    Text(TimeZoneService.display(date, format: "dd.MM")).fontWeight(.semibold)
                                }
                                .font(.callout).frame(width: columnWidth, height: 62)
                                .background(date == TimeZoneService.dateKey(Date(), zone: schedule.timeZone) ? availabilityColor.opacity(0.08) : .clear)
                                .contextMenu {
                                    Button("Отметить весь день занятым") { model.setDay(date, busy: true) }
                                    Button("Очистить весь день") { model.setDay(date, busy: false) }
                                }
                                .accessibilityLabel(TimeZoneService.display(date, format: "EEEE, d MMMM"))
                            }
                        }.background(.regularMaterial)
                    }
                }.frame(width: timeWidth + columnWidth * 7)
            }
            .onMoveCommand { direction in
                var cell = focused ?? CellAddress(row: 0, column: 0)
                switch direction {
                case .up: cell = CellAddress(row: max(0, cell.row - 1), column: cell.column)
                case .down: cell = CellAddress(row: min(schedule.slotTimes.count - 1, cell.row + 1), column: cell.column)
                case .left: cell = CellAddress(row: cell.row, column: max(0, cell.column - 1))
                case .right: cell = CellAddress(row: cell.row, column: min(6, cell.column + 1))
                default: break
                }; focused = cell
            }
            .onDisappear { model.endPaint() }
        }
    }
    private func address(_ point: CGPoint, columnWidth: CGFloat) -> CellAddress? {
        guard point.x >= timeWidth, point.y >= 0 else { return nil }
        let row = Int(point.y / rowHeight), column = Int((point.x - timeWidth) / columnWidth)
        guard row < schedule.slotTimes.count, column < 7 else { return nil }
        return CellAddress(row: row, column: column)
    }
    private func slot(date: String, time: String, row: Int, column: Int) -> some View {
        let busy = schedule.isBusy(date: date, time: time)
        return Button { if !dragging { model.toggle(date: date, time: time) } } label: {
            Label(busy ? Texts.busy : Texts.free, systemImage: busy ? "minus" : "checkmark")
                .font(.system(size: 13, weight: .medium)).frame(maxWidth: .infinity, maxHeight: .infinity)
                .foregroundStyle(busy ? Color.secondary : availabilityColor)
                .background(busy ? Color.secondary.opacity(0.09) : availabilityColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain).padding(3)
        .focused($focused, equals: CellAddress(row: row, column: column))
        .disabled(model.isWorking)
        .accessibilityLabel("\(TimeZoneService.display(date, format: "EEEE, d MMMM")), \(time), \(busy ? Texts.busy : Texts.free)")
        .help("\(time) · \(busy ? Texts.busy : Texts.free). Нажмите, чтобы изменить.")
    }
}
