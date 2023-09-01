import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:pdf/widgets.dart' as pdfWidgets;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:io';
import 'package:intl/intl.dart';

void main() {
  runApp(MyApp());
}

class Entry {
  final DateTime timestamp;
  final bool isEntry;

  Entry(this.timestamp, this.isEntry);

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'isEntry': isEntry,
    };
  }

  factory Entry.fromJson(Map<String, dynamic> json) {
    return Entry(
      DateTime.parse(json['timestamp']),
      json['isEntry'],
    );
  }
}

String formatHoursWithMinutes(double hours) {
  final hoursInt = hours.floor();
  final minutesInt = ((hours - hoursInt) * 60).toInt();
  return '$hoursInt horas $minutesInt minutos';
}

class WorkDay {
  final DateTime date;
  final List<Entry> entries = [];

  WorkDay(this.date);

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'entries': entries.map((entry) => entry.toJson()).toList(),
    };
  }

  factory WorkDay.fromJson(Map<String, dynamic> json) {
    return WorkDay(
      DateTime.parse(json['date']),
    )..entries.addAll(
      (json['entries'] as List).map((entryJson) => Entry.fromJson(entryJson)),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Registro de Horas',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

enum ExportPeriod { Week, Month }

class _HomePageState extends State<HomePage> {
  List<WorkDay> workDays = [];
  double dailyHours = 8.0; // Defina aqui o valor fixo de 8 horas

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Registro de Horas'),
          bottom: TabBar(
            tabs: [
              Tab(text: 'Diário'),
              Tab(text: 'Exportar PDF'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Aba Diário
            _buildDailyTab(),
            // Aba Exportar PDF
            _buildExportTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyTab() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => _addEntry(true),
              child: Text('Registrar Entrada'),
            ),
            SizedBox(width: 10),
            ElevatedButton(
              onPressed: () => _addEntry(false),
              child: Text('Registrar Saída'),
            ),
          ],
        ),
        Expanded(
          child: ListView.builder(
            itemCount: workDays.length,
            itemBuilder: (context, index) {
              final day = workDays[index];
              final hoursWorked = calculateHoursWorked(day);
              final overtime = calculateOvertime(day);

              return ListTile(
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('dd/MM/yyyy').format(day.date),
                    ),
                    Text(
                      'Hora atual: ${DateFormat('HH:mm').format(DateTime.now())}',
                    ),
                  ],
                ),
                subtitle: Text(
                  'Horas trabalhadas: ${formatHoursWithMinutes(hoursWorked)}\nHoras extras: $overtime',
                ),
                trailing: IconButton(
                  icon: Icon(Icons.delete),
                  onPressed: () => _deleteWorkDay(index),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _addEntry(bool isEntry) {
    final now = DateTime.now();
    final currentDay = workDays.firstWhere(
          (day) => _isSameDay(day.date, now),
      orElse: () {
        final newDay = WorkDay(now);
        workDays.add(newDay);
        return newDay;
      },
    );

    if (isEntry) {
      // Verifica se a última entrada é uma saída ou se a lista de entradas está vazia.
      final lastEntryIndex = currentDay.entries.lastIndexWhere((entry) => entry.isEntry);
      if (lastEntryIndex == -1 || !currentDay.entries[lastEntryIndex].isEntry) {
        currentDay.entries.add(Entry(now, true));
      }
    } else {
      final lastEntryIndex = currentDay.entries.lastIndexWhere((entry) => entry.isEntry);
      if (lastEntryIndex != -1) {
        currentDay.entries.add(Entry(now, false));
      }
    }

    _saveWorkDays();
    setState(() {});
  }




  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year && date1.month == date2.month && date1.day == date2.day;
  }


  Widget _buildExportTab() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Escolha o período para exportar em PDF:'),
        SizedBox(height: 20),
        ElevatedButton(
          onPressed: () => _exportToPdf(ExportPeriod.Week),
          child: Text('Exportar Semana'),
        ),
        SizedBox(height: 10),
        ElevatedButton(
          onPressed: () => _exportToPdf(ExportPeriod.Month),
          child: Text('Exportar Mês'),
        ),
      ],
    );
  }

  Future<void> _exportToPdf(ExportPeriod period) async {
    final pdf = pdfWidgets.Document();
    final font = pdfWidgets.Font.ttf(
        await rootBundle.load('assets/Roboto-Regular.ttf'));

    final now = DateTime.now();
    final startDate = (period == ExportPeriod.Week)
        ? now.subtract(Duration(days: now.weekday - 1))
        : DateTime(now.year, now.month, 1);
    final endDate = (period == ExportPeriod.Week)
        ? startDate.add(Duration(days: 6))
        : DateTime(now.year, now.month + 1, 0);

    pdf.addPage(
      pdfWidgets.Page(
        build: (context) => pdfWidgets.Center(
          child: pdfWidgets.Column(
            children: [
              pdfWidgets.Text(
                  'Registros do ${period == ExportPeriod.Week ? "Semana" : "Mês"}',
                  style: pdfWidgets.TextStyle(font: font, fontSize: 24)),
              pdfWidgets.SizedBox(height: 20),
              for (final day in workDays)
                if (day.date.isAfter(startDate) && day.date.isBefore(endDate))
                  pdfWidgets.Column(
                    crossAxisAlignment: pdfWidgets.CrossAxisAlignment.start,
                    children: [
                      pdfWidgets.Text(day.date.toString(),
                          style:
                              pdfWidgets.TextStyle(font: font, fontSize: 18)),
                      for (final entry in day.entries)
                        pdfWidgets.Text(
                            '${entry.timestamp.hour}:${entry.timestamp.minute} - ${entry.isEntry ? "Entrada" : "Saída"}',
                            style:
                                pdfWidgets.TextStyle(font: font, fontSize: 14)),
                      pdfWidgets.SizedBox(height: 10),
                    ],
                  ),
            ],
          ),
        ),
      ),
    );

    final directory = await getApplicationDocumentsDirectory();
    final file = File(
        '${directory.path}/${period == ExportPeriod.Week ? "week" : "month"}_work_hours.pdf');
    await file.writeAsBytes(await pdf.save());
  }

  double calculateHoursWorked(WorkDay day) {
    double totalHours = 0.0;
    bool insideEntry = false; // Variável para rastrear se estamos dentro de uma entrada válida.

    for (int i = 0; i < day.entries.length; i++) {
      final entry = day.entries[i];

      if (entry.isEntry) {
        // Se a entrada atual for uma entrada, registre o momento em que começou.
        insideEntry = true;
        totalHours -= entry.timestamp.minute.toDouble() / 60; // Deduza os minutos da entrada.
      } else {
        // Se a entrada atual for uma saída, registre o momento em que terminou.
        if (insideEntry) {
          totalHours += entry.timestamp.minute.toDouble() / 60; // Adicione os minutos da saída.
        }
        insideEntry = false;
      }
    }

    return totalHours;
  }

  double calculateOvertime(WorkDay day) {
    final hoursWorked = calculateHoursWorked(day);
    final overtime = hoursWorked - dailyHours;
    return overtime > 0 ? overtime : 0.0;
  }

  Future<void> _deleteWorkDay(int index) async {
    setState(() {
      workDays.removeAt(index);
      _saveWorkDays();
    });
  }

  Future<void> _loadWorkDays() async {
    final prefs = await SharedPreferences.getInstance();
    final savedWorkDays = prefs.getString('workdays');
    if (savedWorkDays != null) {
      final List<dynamic> jsonList = json.decode(savedWorkDays);
      workDays = jsonList.map((json) => WorkDay.fromJson(json)).toList();
    }
  }

  Future<void> _saveWorkDays() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = workDays.map((day) => day.toJson()).toList();
    prefs.setString('workdays', json.encode(jsonList));
  }

  @override
  void initState() {
    super.initState();
    _loadWorkDays();
  }
}
