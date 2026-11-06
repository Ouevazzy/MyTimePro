import SwiftUI
import TipKit

struct CalendarAddWorkDayTip: Tip {
    var title: Text {
        Text("tips.calendar.add.title")
    }

    var message: Text? {
        Text("tips.calendar.add.message")
    }

    var image: Image? {
        Image(systemName: "calendar.badge.plus")
    }
}
