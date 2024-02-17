// Importation des packages Flutter
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'firebase_options.dart';

// Classe représentant une tâche
class Task {
  final String id;
  final String titre;
  final String description;
  final Timestamp date;
  bool completed;

  Task({
    required this.id,
    required this.titre,
    required this.description,
    required this.date,
    this.completed = false, // Par défaut, la tâche n'est pas complétée
  });
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'titre': titre,
      'description': description,
      'date': date,
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'],
      titre: map['titre'],
      description: map['description'],
      date: (map['date']),
    );
  }
  // Ajoutez la méthode copyWith
  Task copyWith({
    String? id,
    String? titre,
    String? description,
    Timestamp? date,
  }) {
    return Task(
      id: id ?? this.id,
      titre: titre ?? this.titre,
      description: description ?? this.description,
      date: date ?? this.date,
    );
  }
}

// Fonction principale pour exécuter l'application Flutter

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

// Classe principale de l'application
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        colorScheme:
            ColorScheme.fromSeed(seedColor: Color.fromARGB(247, 243, 91, 235)),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Daily Task'),
    );
  }
}

// Classe représentant la page principale de l'application
class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

// Classe représentant l'état de la page principale
class _MyHomePageState extends State<MyHomePage> {
  List<Task> _tasks = [];
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late DateTime _dueDate;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
    _dueDate = DateTime.now();

    // Récupérer les tâches depuis Firestore et mettre à jour la liste locale
    _fetchTasks();
  }

  // Fonction pour récupérer les tâches depuis Firestore
  void _fetchTasks() async {
    try {
      QuerySnapshot querySnapshot =
          await FirebaseFirestore.instance.collection('tasks').get();

      // Convertir les documents Firestore en objets Task
      List<Task> tasks = querySnapshot.docs
          .map((doc) {
            final data = doc.data();
            return data != null
                ? Task.fromMap({...data as Map<String, dynamic>, 'id': doc.id})
                : null;
          })
          .where((task) => task != null)
          .cast<Task>()
          .toList();

      setState(() {
        _tasks = tasks;
      });
    } catch (e) {
      print('Erreur lors de la récupération des tâches: $e');
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  //ajouter une tache
  void _addTask() async {
    Task newTask = Task(
      id: '',
      titre: _titleController.text,
      description: _descriptionController.text,
      date: Timestamp.fromDate(_dueDate),
    );

    // Ajouter la tâche à Firestore
    DocumentReference docRef = await FirebaseFirestore.instance
        .collection('tasks')
        .add(newTask.toMap());

    // Mettre à jour l'identifiant dans la tâche locale
    newTask = newTask.copyWith(id: docRef.id);
    setState(() {
      _tasks.add(newTask);
    });
    // Efface les champs du formulaire
    _titleController.clear();
    _descriptionController.clear();
    _dueDate = DateTime.now();

    // Mettre à jour la liste des tâches depuis Firestore
    _fetchTasks(); // Appel de la méthode _fetchTasks pour mettre à jour la liste
  }

// Méthode pour sélectionner une date
  Future<DateTime?> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _dueDate) {
      setState(() {
        _dueDate = picked;
      });
    }
    return picked;
  }

  //modifier une tache
  void _editTask(Task task) async {
    // Utilisez directement la tâche passée en paramètre
    Task currentTask = task;

    // Créez des contrôleurs pour les champs de modification
    TextEditingController editTitleController =
        TextEditingController(text: currentTask.titre);
    TextEditingController editDescriptionController =
        TextEditingController(text: currentTask.description);
    DateTime editDueDate =
        currentTask.date.toDate(); // Convertir Timestamp en DateTime

    // Affichez le dialogue de modification de la tâche
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return AlertDialog(
            title: Text('Modifier la tâche'),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Contrôle pour modifier le titre de la tâche
                TextField(
                  controller: editTitleController,
                  decoration: InputDecoration(labelText: 'Titre'),
                ),
                // Contrôle pour modifier la description de la tâche
                TextField(
                  controller: editDescriptionController,
                  decoration: InputDecoration(labelText: 'Description'),
                ),
                // Affiche la date d'échéance actuelle
                Text(
                  'Date d\'échéance actuelle: ${DateFormat('dd/MM/yyyy').format(editDueDate)}',
                ),
                // Bouton pour modifier la date d'échéance
                ElevatedButton(
                  onPressed: () async {
                    DateTime? pickedDate = await _selectDate(context);
                    if (pickedDate != null && pickedDate != editDueDate) {
                      setState(() {
                        editDueDate = pickedDate;
                      });
                    }
                  },
                  child: Text('Modifier la date d\'échéance'),
                ),
              ],
            ),
            actions: [
              // Bouton pour annuler la modification
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Fermer le dialogue
                },
                child: Text('Annuler'),
              ),
              // Bouton pour enregistrer les modifications
              ElevatedButton(
                onPressed: () async {
                  // Mettre à jour les champs de la tâche
                  currentTask = Task(
                    id: currentTask.id, // N'oubliez pas de passer l'ID existant
                    titre: editTitleController.text,
                    description: editDescriptionController.text,
                    date: Timestamp.fromDate(
                        editDueDate), // Convertir DateTime en Timestamp
                  );

                  // Mettre à jour la tâche dans Firestore
                  await FirebaseFirestore.instance
                      .collection('tasks')
                      .doc(currentTask.id)
                      .update(currentTask.toMap());

                  // Mettre à jour la liste locale
                  setState(() {
                    // Recherchez et mettez à jour la tâche dans la liste _tasks
                    final index =
                        _tasks.indexWhere((task) => task.id == currentTask.id);
                    if (index != -1) {
                      _tasks[index] = currentTask;
                    }
                  });

                  Navigator.pop(context); // Fermer le dialogue

                  // Mettre à jour la liste des tâches depuis Firestore
                  _fetchTasks(); // Appel de la méthode _fetchTasks pour mettre à jour la liste
                },
                child: Text('Enregistrer'),
              ),
            ],
          );
        },
      ),
    );
  }

  //supprimer la tache
  void _deleteTask(int i, String taskId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Supprimer'),
        content: Text('Etes-vous sur de supprimer cette tache ?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Ferme le dialogue
            },
            child: Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Supprimer la tâche de Firestore
              await FirebaseFirestore.instance
                  .collection('tasks')
                  .doc(taskId)
                  .delete();

              //Mettre à jour la liste locale
              setState(() {
                _tasks.removeAt(i);
              });
              Navigator.pop(context); // Ferme le dialogue
            },
            child: Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  //gerer le corps de l appli
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Row(children: [
          Expanded(
            child: Text(
              widget.title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 40.0,
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AgendaPage()),
              );
            },
            icon: Icon(Icons.calendar_today),
            tooltip: 'Agenda',
          ),
        ]),
      ),
      body: Container(
        color: Color.fromARGB(255, 248, 213, 239),
        padding: EdgeInsets.only(top: 20.0),
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  'Tâches planifiées',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 15,
                  ),
                ),

                // Afficher la liste des tâches
                Expanded(
                  child: ListView.builder(
                    itemCount: _tasks.length,
                    itemBuilder: (context, i) {
                      Task task = _tasks[i];

                      return Container(
                          child: ListTile(
                        // Case à cocher pour spécifier si la tâche est complétée ou non
                        leading: Checkbox(
                          value: task.completed,
                          onChanged: (value) {
                            setState(() {
                              task.completed = value!;
                            });
                          },
                        ),

                        title: Text(
                          task.titre,
                          style: TextStyle(
                            fontSize: 20.0,
                            color: Color.fromARGB(255, 2, 2, 2),
                            decoration: task.completed
                                ? TextDecoration.lineThrough
                                : null, // Si la tâche est complétée, ajoute un effet de texte barré
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              task.description,
                              style: TextStyle(
                                fontSize: 18.0,
                                decoration: task.completed
                                    ? TextDecoration.lineThrough
                                    : null,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Date Echéance: ${task.date.toDate().day}/${task.date.toDate().month}/${task.date.toDate().year}',
                              style: TextStyle(
                                fontSize: 18.0,
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                decoration: task.completed
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                          ],
                        ),

                        //gestion des icones modifier et supprimer
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit),
                              onPressed: () {
                                // Ajouter la logique de modification ici
                                _editTask(task);
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.delete),
                              onPressed: () {
                                // Ajouter la logique de suppression ici
                                _deleteTask(i, _tasks[i].id);
                              },
                            ),
                          ],
                        ),
                      ));
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      floatingActionButton: Container(
        margin: EdgeInsets.only(
          bottom: 60.0,
        ),
        child: FloatingActionButton(
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => _buildAddTaskDialog(context),
            );
          },
          tooltip: 'Créer une tâche',
          child: const Icon(Icons.add),
          backgroundColor: Color.fromARGB(255, 233, 200, 247),
          heroTag: 'addTask',
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        color: Theme.of(context).colorScheme.inversePrimary,
        child: Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AlarmPage()),
                );
              },
              icon: const Icon(Icons.alarm),
              tooltip: 'Alarme',
            ),
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.schedule),
              tooltip: 'Planification',
            ),
            IconButton(
              onPressed: () {
                // Ajouter la logique pour l'icône compte
              },
              icon: const Icon(Icons.account_circle),
              tooltip: 'Compte',
            ),
          ],
        ),
      ),
    );
  }

  // Fonction pour construire le dialogue d'ajout de tâche
  Widget _buildAddTaskDialog(BuildContext context) {
    return AlertDialog(
      title: Text("Ajout des taches"),
      titleTextStyle: TextStyle(
        color: Colors.black,
        fontSize: 30.0,
        fontWeight: FontWeight.bold,
      ),
      content: Container(
        width: double.maxFinite, // Ajuste la largeur du contenu
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // Ajuste la hauteur du contenu
          children: [
            SizedBox(
                height: 8.0), // Ajoute un espace au-dessus des champs de texte
            TextField(
              controller: _titleController,
              style: TextStyle(fontSize: 18.0),
              decoration: InputDecoration(
                labelText: 'Titre',
                labelStyle: TextStyle(
                  color: Colors.black,
                  fontSize: 20.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(height: 8.0), // Ajoute un espace entre les champs de texte
            TextField(
              controller: _descriptionController,
              style: TextStyle(fontSize: 18.0),
              decoration: InputDecoration(
                labelText: 'Détails de la tâche',
                labelStyle: TextStyle(
                  color: Colors.black,
                  fontSize: 0.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Text(
                  "Date d'échéance: ",
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 20.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    // Affiche le sélecteur de date
                    DateTime? pickedDate = await _selectDate(context);
                    if (pickedDate != null && pickedDate != _dueDate) {
                      setState(() {
                        _dueDate = pickedDate;
                      });
                    }
                  },
                  child: Text(
                    "${DateFormat('dd/MM/yyyy').format(_dueDate)}", // Affiche la date sélectionnée
                    style: TextStyle(
                      fontSize: 18.0,
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context); // Ferme le dialogue
          },
          child: Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: () {
            _addTask();
            Navigator.pop(context); // Ferme le dialogue
          },
          child: Text('Créer une tâche'),
        ),
      ],
    );
  }
}

//agenda
class AgendaPage extends StatefulWidget {
  @override
  _AgendaPageState createState() => _AgendaPageState();
}

class _AgendaPageState extends State<AgendaPage> {
  late CalendarFormat _calendarFormat;
  late DateTime _focusedDay;
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    _calendarFormat = CalendarFormat.month;
    _focusedDay = DateTime.now();
    _selectedDay = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Calendrier'),
        backgroundColor: Color.fromARGB(255, 243, 158, 253),
      ),
      body: Container(
        color: const Color.fromARGB(255, 246, 199, 214),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TableCalendar(
              firstDay: DateTime.utc(2023, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              selectedDayPredicate: (day) {
                return isSameDay(_selectedDay, day);
              },
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              onFormatChanged: (format) {
                setState(() {
                  _calendarFormat = format;
                });
              },
              onPageChanged: (focusedDay) {
                _focusedDay = focusedDay;
              },
            ),
            SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text('Retour'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

//alarme
class AlarmPage extends StatefulWidget {
  @override
  _AlarmPageState createState() => _AlarmPageState();
}

class _AlarmPageState extends State<AlarmPage> {
  late DateTime _currentTime;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _currentTime = DateTime.now(); // Initialize _currentTime in initState
    _updateTime();
  }

  // Met à jour l'heure toutes les secondes
  void _updateTime() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now(); // Update _currentTime
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel(); // Cancel the timer in dispose
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String formattedTime = _currentTime != null
        ? DateFormat.Hms().format(_currentTime) // Formater l'heure actuelle
        : 'Loading...';

    return Scaffold(
      appBar: AppBar(
        title: Text('Alarme'),
      ),
      body: Center(
        child: Text(
          formattedTime, // Utiliser la chaîne de caractères formatée
          style: TextStyle(
              fontSize: 72.0), // Taille de police grande pour l'horloge
        ),
      ),
    );
  }
}
