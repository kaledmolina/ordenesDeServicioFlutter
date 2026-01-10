import 'package:flutter/material.dart';

class BarrioSearchModal extends StatefulWidget {
  final List<String> barrios;
  final Function(String?) onSelected;

  const BarrioSearchModal({super.key, required this.barrios, required this.onSelected});

  @override
  _BarrioSearchModalState createState() => _BarrioSearchModalState();
}

class _BarrioSearchModalState extends State<BarrioSearchModal> {
  List<String> _filteredBarrios = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filteredBarrios = widget.barrios;
  }

  void _filter(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredBarrios = widget.barrios;
      } else {
        _filteredBarrios = widget.barrios
            .where((b) => b.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Handle
        Container(
          margin: const EdgeInsets.only(top: 8),
          width: 40, height: 4,
          decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
        ),
        
        // Search Bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            onChanged: _filter,
            decoration: InputDecoration(
              hintText: 'Buscar barrio...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ),

        // List
        Expanded(
          child: ListView.separated(
            itemCount: _filteredBarrios.length + 1,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              if (index == 0) {
                return ListTile(
                  title: const Text('Todos los Barrios', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF10447E))),
                  onTap: () => widget.onSelected(null),
                );
              }
              final barrio = _filteredBarrios[index - 1];
              return ListTile(
                title: Text(barrio),
                onTap: () => widget.onSelected(barrio),
              );
            },
          ),
        ),
      ],
    );
  }
}
