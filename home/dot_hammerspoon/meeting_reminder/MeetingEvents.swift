// Dumps upcoming calendar events as JSON for meeting_reminder.lua.
// Runs as its own .app (launched via `open`) so it owns its Calendar
// permission; Hammerspoon's Info.plist has no calendar usage string.
// Usage: MeetingEvents <outfile> [hoursAhead]
import EventKit
import Foundation

let args = CommandLine.arguments
guard args.count >= 2 else { exit(2) }
let outPath = args[1]
let hours = args.count >= 3 ? Double(args[2]) ?? 12 : 12

func write(_ obj: Any) {
  let data = try! JSONSerialization.data(withJSONObject: obj)
  let tmp = outPath + ".tmp"
  FileManager.default.createFile(atPath: tmp, contents: data)
  _ = try? FileManager.default.replaceItemAt(URL(fileURLWithPath: outPath), withItemAt: URL(fileURLWithPath: tmp))
}

let store = EKEventStore()
let sem = DispatchSemaphore(value: 0)
var granted = false
store.requestFullAccessToEvents { ok, _ in granted = ok; sem.signal() }
sem.wait()
guard granted else { write(["error": "calendar access denied"]); exit(1) }

let now = Date()
let pred = store.predicateForEvents(withStart: now.addingTimeInterval(-600), end: now.addingTimeInterval(hours * 3600), calendars: nil)
let events: [[String: Any]] = store.events(matching: pred).compactMap { e in
  if e.isAllDay || e.status == .canceled { return nil }
  // Skip meetings I've declined.
  if let me = e.attendees?.first(where: { $0.isCurrentUser }), me.participantStatus == .declined { return nil }
  return [
    "id": e.calendarItemExternalIdentifier ?? e.eventIdentifier ?? "",
    "title": e.title ?? "(no title)",
    "start": e.startDate.timeIntervalSince1970,
    "end": e.endDate.timeIntervalSince1970,
    "text": [e.url?.absoluteString, e.location, e.notes].compactMap { $0 }.joined(separator: "\n"),
  ]
}
write(["events": events])
