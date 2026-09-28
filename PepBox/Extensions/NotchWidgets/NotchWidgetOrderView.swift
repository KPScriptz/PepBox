//
//  NotchWidgetOrderView.swift
//  PepBox
//
//  Drag to reorder the widget buttons under the expanded shelf.
//

import SwiftUI

struct NotchWidgetOrderView: View {
    @State private var widgets: [NotchWidgetKind] = []

    var body: some View {
        Group {
            if widgets.isEmpty {
                Text("Install widgets like Pomodoro or Emoji Picker from Extensions to arrange their buttons here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                List {
                    ForEach(widgets) { widget in
                        HStack(spacing: 10) {
                            Image(systemName: "line.3.horizontal")
                                .foregroundStyle(.tertiary)
                            Image(systemName: widget.icon)
                                .foregroundStyle(widget.tint)
                                .frame(width: 20)
                            Text(widget.title)
                        }
                    }
                    .onMove { from, to in
                        widgets.move(fromOffsets: from, toOffset: to)
                        NotchWidgetKind.saveOrder(widgets)
                    }
                }
                .frame(height: CGFloat(widgets.count) * 30 + 12)
                .scrollDisabled(true)
            }
        }
        .onAppear { widgets = NotchWidgetKind.available }
    }
}
