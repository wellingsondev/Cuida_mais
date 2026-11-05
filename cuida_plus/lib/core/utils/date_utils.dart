import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime? tsToDate(dynamic v) => v is Timestamp ? v.toDate() : null;
String two(int n) => n.toString().padLeft(2, '0');
String fmtDate(DateTime d) => DateFormat('dd/MM/yyyy', 'pt_BR').format(d);
String fmtDateLong(DateTime d) => DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(d);
String fmtTime(DateTime d) => DateFormat('HH:mm', 'pt_BR').format(d);
String fmtDateTime(DateTime d) => '${fmtDate(d)} às ${fmtTime(d)}';
