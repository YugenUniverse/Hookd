import 'package:add_2_calendar/add_2_calendar.dart';

void addClimbToCalendar({
  required String title,
  required DateTime start,
  required String location,
  required String description,
}) {
  Add2Calendar.addEvent2Cal(Event(
    title: title,
    description: description,
    location: location,
    startDate: start,
    endDate: start.add(const Duration(hours: 2)),
  ));
}
