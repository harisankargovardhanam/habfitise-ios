import Foundation

extension Date {
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    func formattedRelativeDay() -> String {
        if Calendar.current.isDateInToday(self) {
            return "Today"
        }
        if Calendar.current.isDateInYesterday(self) {
            return "Yesterday"
        }
        if Calendar.current.isDateInTomorrow(self) {
            return "Tomorrow"
        }
        return formatted(.dateTime.month(.abbreviated).day())
    }

    func formattedTime() -> String {
        formatted(date: .omitted, time: .shortened)
    }

    func formattedShortDate() -> String {
        formatted(.dateTime.month(.abbreviated).day().year())
    }
}
