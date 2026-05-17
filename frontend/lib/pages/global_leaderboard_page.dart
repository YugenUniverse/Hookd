import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../constants/api_config.dart';
import '../models/leaderboard_entry.dart';
import '../services/auth_service.dart';
import '../widgets/leaderboard_list.dart';

class GlobalLeaderboardPage extends StatefulWidget {
  const GlobalLeaderboardPage({super.key});

  @override
  State<GlobalLeaderboardPage> createState() => _GlobalLeaderboardPageState();
}

class _GlobalLeaderboardPageState extends State<GlobalLeaderboardPage> {

  List<LeaderboardEntry> _climbers = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchGlobalLeaderboard();
  }

  Future<void> _fetchGlobalLeaderboard() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = AuthService().jwt;

      final response = await http.get(
        Uri.parse('${ApiConfig.apiBaseUrl}/climbers/leaderboard'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        List<dynamic> rawList = [];

        rawList = decoded;

        setState(() {
          _climbers = rawList
              .map((json) => LeaderboardEntry.fromJson(json))
              .toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage =
              'Failed to load global rankings (${response.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error. Please check your connection.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Global Rankings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchGlobalLeaderboard,
        color: Theme.of(context).colorScheme.primary,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return CustomScrollView(
        slivers: [
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Colors.red.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(_errorMessage!),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _fetchGlobalLeaderboard,
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 16.0, left: 4.0),
            child: Text(
              'Top Climbers Worldwide 🌍',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),

          LeaderboardList(
            climbers: _climbers,
            emptyMessage:
                "No global climbers found. Be the first to reach the top!",
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
