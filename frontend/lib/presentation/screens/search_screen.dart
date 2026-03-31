import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'history_screen.dart';
import '../../data/auth_service.dart';

class SearchScreen extends StatefulWidget {
  final Function(String, String) onSearch;

  const SearchScreen({super.key, required this.onSearch});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _sourceController = TextEditingController(text: "DMart Nadiad");
  final TextEditingController _destController = TextEditingController(text: "Inox Ahmedabad");

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => HistoryScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.orangeAccent),
            onPressed: () {
              context.read<AuthService>().logout();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              Text(
                "Where are you\ngoing today?",
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 48),
              TextField(
                controller: _sourceController,
                decoration: const InputDecoration(
                  labelText: "Source Point",
                  prefixIcon: Icon(Icons.location_on),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _destController,
                decoration: const InputDecoration(
                  labelText: "Destination Point",
                  prefixIcon: Icon(Icons.location_on, color: Colors.green),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => widget.onSearch(
                    _sourceController.text,
                    _destController.text,
                  ),
                  child: const Text("Find Best Route"),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
