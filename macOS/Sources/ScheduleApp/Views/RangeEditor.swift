import SwiftUI
import ScheduleCore

struct RangeEditor: View {
    @ObservedObject var model: ScheduleViewModel
    let schedule: Schedule
    @Environment(\.dismiss) private var dismiss
    @State private var date: String
    @State private var start: String
    @State private var end: String
    @State private var busy = true
    init(model: ScheduleViewModel, schedule: Schedule) {
        self.model = model; self.schedule = schedule
        _date = State(initialValue: model.monday); _start = State(initialValue: schedule.dayStart); _end = State(initialValue: schedule.dayEnd)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Изменить диапазон").font(.title2.bold())
            Form {
                Picker("День", selection: $date) { ForEach(model.dates, id: \.self) { Text(TimeZoneService.display($0, format: "EEEE, d MMMM")).tag($0) } }
                Picker("С", selection: $start) { ForEach(schedule.slotTimes, id: \.self) { Text($0).tag($0) } }
                Picker("До", selection: $end) { ForEach(Array(schedule.slotTimes.dropFirst()) + [schedule.dayEnd], id: \.self) { Text($0).tag($0) } }
                Picker("Состояние", selection: $busy) { Text(Texts.busy).tag(true); Text(Texts.free).tag(false) }.pickerStyle(.segmented)
            }
            HStack { Spacer(); Button("Отмена") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Применить") { model.setRange(date: date, start: start, end: end, busy: busy); dismiss() }
                    .keyboardShortcut(.defaultAction).disabled(start >= end)
            }
        }.padding(26).frame(width: 420)
    }
}
