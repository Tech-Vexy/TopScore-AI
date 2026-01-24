import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/colors.dart';

class PeriodicTableScreen extends StatefulWidget {
  const PeriodicTableScreen({super.key});

  @override
  State<PeriodicTableScreen> createState() => _PeriodicTableScreenState();
}

class _PeriodicTableScreenState extends State<PeriodicTableScreen> {
  String _searchQuery = '';
  String? _selectedCategory;
  final Map<int, Map<int, ChemicalElement>> _elementGrid = {};

  final List<String> _categories = [
    'All',
    'Alkali Metal',
    'Alkaline Earth Metal',
    'Transition Metal',
    'Post-transition Metal',
    'Metalloid',
    'Nonmetal',
    'Halogen',
    'Noble Gas',
    'Lanthanide',
    'Actinide',
    'Unknown',
  ];

  List<ChemicalElement> get _filteredElements {
    return periodicTableData.where((element) {
      final matchesSearch = _searchQuery.isEmpty ||
          element.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          element.symbol.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          element.atomicNumber.toString().contains(_searchQuery);

      final matchesCategory = _selectedCategory == null ||
          _selectedCategory == 'All' ||
          element.category == _selectedCategory;

      return matchesSearch && matchesCategory;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _initializeGrid();
  }

  void _initializeGrid() {
    for (var element in periodicTableData) {
      if (!_elementGrid.containsKey(element.period)) {
        _elementGrid[element.period] = {};
      }
      _elementGrid[element.period]![element.group] = element;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Periodic Table',
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showInfoDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by name, symbol, or atomic number...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: theme.cardColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                  },
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final category = _categories[index];
                      final isSelected = _selectedCategory == category ||
                          (_selectedCategory == null && category == 'All');
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(category),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              _selectedCategory =
                                  selected ? category : 'All';
                            });
                          },
                          selectedColor: AppColors.primaryPurple.withValues(alpha: 0.2),
                          checkmarkColor: AppColors.primaryPurple,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Element Grid
          Expanded(
            child: _searchQuery.isNotEmpty || _selectedCategory != null && _selectedCategory != 'All'
                ? _buildElementList(theme)
                : _buildPeriodicTableGrid(theme, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildElementList(ThemeData theme) {
    final elements = _filteredElements;

    if (elements.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No elements found',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: elements.length,
      itemBuilder: (context, index) {
        final element = elements[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: _getCategoryColor(element.category).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  element.symbol,
                  style: GoogleFonts.roboto(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: _getCategoryColor(element.category),
                  ),
                ),
              ),
            ),
            title: Text(
              element.name,
              style: GoogleFonts.nunito(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${element.atomicNumber} • ${element.category}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showElementDetails(context, element),
          ),
        );
      },
    );
  }

  Widget _buildPeriodicTableGrid(ThemeData theme, bool isDark) {
    return InteractiveViewer(
      boundaryMargin: const EdgeInsets.all(100),
      minScale: 0.3,
      maxScale: 4.0,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildLegend(theme),
                const SizedBox(height: 20),
                
                // Main Grid (Periods 1-7, Groups 1-18)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(7, (rowIndex) {
                    final period = rowIndex + 1;
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(18, (colIndex) {
                        final group = colIndex + 1;
                        
                        if (group == 3) {
                          if (period == 6) {
                            return _buildPlaceholderTile("57-71", "La-Lu", theme);
                          } else if (period == 7) {
                            return _buildPlaceholderTile("89-103", "Ac-Lr", theme);
                          }
                        }

                        final element = _elementGrid[period]?[group];
                        
                        if (element == null) {
                          return const SizedBox(width: 54, height: 54);
                        }
                        
                        return PeriodicElementTile(
                          element: element,
                          onTap: () => _showElementDetails(context, element),
                        );
                      }),
                    );
                  }),
                ),
                
                const SizedBox(height: 30),
                
                // F-Block (Lanthanides & Actinides)
                _buildFBlockRow(6, "Lanthanides", theme),
                const SizedBox(height: 4),
                _buildFBlockRow(7, "Actinides", theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFBlockRow(int period, String label, ThemeData theme) {
    final elements = _elementGrid[period]?.values
        .where((e) => e.group == 0)
        .toList()
      ?..sort((a, b) => a.atomicNumber.compareTo(b.atomicNumber));

    if (elements == null || elements.isEmpty) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(width: 54 * 2 + 10),
        ...elements.map((e) => PeriodicElementTile(
          element: e, 
          onTap: () => _showElementDetails(context, e)
        )),
      ],
    );
  }

  Widget _buildPlaceholderTile(String numberRange, String symbolRange, ThemeData theme) {
    return Container(
      width: 50,
      height: 50,
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        border: Border.all(color: theme.disabledColor.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(numberRange, style: TextStyle(fontSize: 8, color: theme.disabledColor)),
          Text(symbolRange, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: theme.disabledColor)),
        ],
      ),
    );
  }

  Widget _buildLegend(ThemeData theme) {
    final categories = [
      ('Alkali Metal', Colors.red),
      ('Alkaline Earth Metal', Colors.orange),
      ('Transition Metal', Colors.yellow[700]!),
      ('Post-transition Metal', Colors.green),
      ('Metalloid', Colors.teal),
      ('Nonmetal', Colors.blue),
      ('Halogen', Colors.indigo),
      ('Noble Gas', Colors.purple),
      ('Lanthanide', Colors.pink),
      ('Actinide', Colors.brown),
      ('Unknown', Colors.grey),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: categories.map((cat) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: cat.$2.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: cat.$2, width: 1),
          ),
          child: Text(
            cat.$1,
            style: TextStyle(fontSize: 10, color: cat.$2),
          ),
        );
      }).toList(),
    );
  }



  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Alkali Metal':
        return Colors.red;
      case 'Alkaline Earth Metal':
        return Colors.orange;
      case 'Transition Metal':
        return Colors.yellow[700]!;
      case 'Post-transition Metal':
        return Colors.green;
      case 'Metalloid':
        return Colors.teal;
      case 'Nonmetal':
        return Colors.blue;
      case 'Halogen':
        return Colors.indigo;
      case 'Noble Gas':
        return Colors.purple;
      case 'Lanthanide':
        return Colors.pink;
      case 'Actinide':
        return Colors.brown;
      default:
        return Colors.grey;
    }
  }

  void _showElementDetails(BuildContext context, ChemicalElement element) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ElementDetailsSheet(element: element),
    );
  }

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Periodic Table Guide'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'How to Use:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• Tap any element to view detailed information'),
              Text('• Use search to find elements by name or symbol'),
              Text('• Filter by element category'),
              Text('• Pinch to zoom the periodic table'),
              Text('• Scroll to explore all elements'),
              SizedBox(height: 16),
              Text(
                'Color Legend:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('Each color represents an element category'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

class ElementDetailsSheet extends StatelessWidget {
  final ChemicalElement element;

  const ElementDetailsSheet({super.key, required this.element});

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Alkali Metal':
        return Colors.red;
      case 'Alkaline Earth Metal':
        return Colors.orange;
      case 'Transition Metal':
        return Colors.yellow[700]!;
      case 'Post-transition Metal':
        return Colors.green;
      case 'Metalloid':
        return Colors.teal;
      case 'Nonmetal':
        return Colors.blue;
      case 'Halogen':
        return Colors.indigo;
      case 'Noble Gas':
        return Colors.purple;
      case 'Lanthanide':
        return Colors.pink;
      case 'Actinide':
        return Colors.brown;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _getCategoryColor(element.category);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Element Header
                      Row(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: color, width: 2),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  element.atomicNumber.toString(),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: color,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  element.symbol,
                                  style: GoogleFonts.roboto(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: color,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  element.name,
                                  style: GoogleFonts.nunito(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  element.category,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: color,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Properties Grid
                      _buildPropertyCard('Atomic Mass', '${element.atomicMass} u'),
                      _buildPropertyCard('Period', element.period.toString()),
                      _buildPropertyCard('Group', element.group == 0 ? 'f-block' : element.group.toString()),
                      _buildPropertyCard('State at STP', element.state),
                      
                      const SizedBox(height: 16),
                      
                      // Description
                      if (element.description.isNotEmpty) ...[
                        Text(
                          'About',
                          style: GoogleFonts.nunito(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          element.description,
                          style: const TextStyle(fontSize: 14, height: 1.5),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPropertyCard(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// PeriodicElementTile Widget
class PeriodicElementTile extends StatelessWidget {
  final ChemicalElement element;
  final VoidCallback onTap;

  const PeriodicElementTile({
    super.key,
    required this.element,
    required this.onTap,
  });

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Alkali Metal': return Colors.red;
      case 'Alkaline Earth Metal': return Colors.orange;
      case 'Transition Metal': return Colors.yellow[700]!;
      case 'Post-transition Metal': return Colors.green;
      case 'Metalloid': return Colors.teal;
      case 'Nonmetal': return Colors.blue;
      case 'Halogen': return Colors.indigo;
      case 'Noble Gas': return Colors.purple;
      case 'Lanthanide': return Colors.pink;
      case 'Actinide': return Colors.brown;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getCategoryColor(element.category);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          border: Border.all(color: color, width: 1.5),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              element.atomicNumber.toString(),
              style: TextStyle(
                fontSize: 8,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              element.symbol,
              style: GoogleFonts.roboto(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Element Model
class ChemicalElement {
  final int atomicNumber;
  final String symbol;
  final String name;
  final double atomicMass;
  final String category;
  final int period;
  final int group;
  final String state;
  final String description;

  const ChemicalElement({
    required this.atomicNumber,
    required this.symbol,
    required this.name,
    required this.atomicMass,
    required this.category,
    required this.period,
    required this.group,
    required this.state,
    this.description = '',
  });
}

// Helper to generate the list from compact data
final List<ChemicalElement> periodicTableData = _rawElementData.map((e) {
  return ChemicalElement(
    atomicNumber: e[0] as int,
    symbol: e[1] as String,
    name: e[2] as String,
    atomicMass: (e[3] as num).toDouble(),
    category: e[4] as String,
    period: e[5] as int,
    group: e[6] as int,
    state: e[7] as String,
    description: e.length > 8 ? e[8] as String : '${e[2]} is a chemical element with symbol ${e[1]}.',
  );
}).toList();

// Complete 118-element periodic table data
const List<List<dynamic>> _rawElementData = [
  [1, 'H', 'Hydrogen', 1.008, 'Nonmetal', 1, 1, 'Gas', 'The lightest element.'],
  [2, 'He', 'Helium', 4.0026, 'Noble Gas', 1, 18, 'Gas', 'Inert gas used in balloons.'],
  [3, 'Li', 'Lithium', 6.94, 'Alkali Metal', 2, 1, 'Solid'],
  [4, 'Be', 'Beryllium', 9.0122, 'Alkaline Earth Metal', 2, 2, 'Solid'],
  [5, 'B', 'Boron', 10.81, 'Metalloid', 2, 13, 'Solid'],
  [6, 'C', 'Carbon', 12.011, 'Nonmetal', 2, 14, 'Solid'],
  [7, 'N', 'Nitrogen', 14.007, 'Nonmetal', 2, 15, 'Gas'],
  [8, 'O', 'Oxygen', 15.999, 'Nonmetal', 2, 16, 'Gas'],
  [9, 'F', 'Fluorine', 18.998, 'Halogen', 2, 17, 'Gas'],
  [10, 'Ne', 'Neon', 20.180, 'Noble Gas', 2, 18, 'Gas'],
  [11, 'Na', 'Sodium', 22.990, 'Alkali Metal', 3, 1, 'Solid'],
  [12, 'Mg', 'Magnesium', 24.305, 'Alkaline Earth Metal', 3, 2, 'Solid'],
  [13, 'Al', 'Aluminium', 26.982, 'Post-transition Metal', 3, 13, 'Solid'],
  [14, 'Si', 'Silicon', 28.085, 'Metalloid', 3, 14, 'Solid'],
  [15, 'P', 'Phosphorus', 30.974, 'Nonmetal', 3, 15, 'Solid'],
  [16, 'S', 'Sulfur', 32.06, 'Nonmetal', 3, 16, 'Solid'],
  [17, 'Cl', 'Chlorine', 35.45, 'Halogen', 3, 17, 'Gas'],
  [18, 'Ar', 'Argon', 39.948, 'Noble Gas', 3, 18, 'Gas'],
  [19, 'K', 'Potassium', 39.098, 'Alkali Metal', 4, 1, 'Solid'],
  [20, 'Ca', 'Calcium', 40.078, 'Alkaline Earth Metal', 4, 2, 'Solid'],
  [21, 'Sc', 'Scandium', 44.956, 'Transition Metal', 4, 3, 'Solid'],
  [22, 'Ti', 'Titanium', 47.867, 'Transition Metal', 4, 4, 'Solid'],
  [23, 'V', 'Vanadium', 50.942, 'Transition Metal', 4, 5, 'Solid'],
  [24, 'Cr', 'Chromium', 51.996, 'Transition Metal', 4, 6, 'Solid'],
  [25, 'Mn', 'Manganese', 54.938, 'Transition Metal', 4, 7, 'Solid'],
  [26, 'Fe', 'Iron', 55.845, 'Transition Metal', 4, 8, 'Solid'],
  [27, 'Co', 'Cobalt', 58.933, 'Transition Metal', 4, 9, 'Solid'],
  [28, 'Ni', 'Nickel', 58.693, 'Transition Metal', 4, 10, 'Solid'],
  [29, 'Cu', 'Copper', 63.546, 'Transition Metal', 4, 11, 'Solid'],
  [30, 'Zn', 'Zinc', 65.38, 'Transition Metal', 4, 12, 'Solid'],
  [31, 'Ga', 'Gallium', 69.723, 'Post-transition Metal', 4, 13, 'Solid'],
  [32, 'Ge', 'Germanium', 72.630, 'Metalloid', 4, 14, 'Solid'],
  [33, 'As', 'Arsenic', 74.922, 'Metalloid', 4, 15, 'Solid'],
  [34, 'Se', 'Selenium', 78.971, 'Nonmetal', 4, 16, 'Solid'],
  [35, 'Br', 'Bromine', 79.904, 'Halogen', 4, 17, 'Liquid'],
  [36, 'Kr', 'Krypton', 83.798, 'Noble Gas', 4, 18, 'Gas'],
  [37, 'Rb', 'Rubidium', 85.468, 'Alkali Metal', 5, 1, 'Solid'],
  [38, 'Sr', 'Strontium', 87.62, 'Alkaline Earth Metal', 5, 2, 'Solid'],
  [39, 'Y', 'Yttrium', 88.906, 'Transition Metal', 5, 3, 'Solid'],
  [40, 'Zr', 'Zirconium', 91.224, 'Transition Metal', 5, 4, 'Solid'],
  [41, 'Nb', 'Niobium', 92.906, 'Transition Metal', 5, 5, 'Solid'],
  [42, 'Mo', 'Molybdenum', 95.95, 'Transition Metal', 5, 6, 'Solid'],
  [43, 'Tc', 'Technetium', 98.0, 'Transition Metal', 5, 7, 'Solid'],
  [44, 'Ru', 'Ruthenium', 101.07, 'Transition Metal', 5, 8, 'Solid'],
  [45, 'Rh', 'Rhodium', 102.91, 'Transition Metal', 5, 9, 'Solid'],
  [46, 'Pd', 'Palladium', 106.42, 'Transition Metal', 5, 10, 'Solid'],
  [47, 'Ag', 'Silver', 107.87, 'Transition Metal', 5, 11, 'Solid'],
  [48, 'Cd', 'Cadmium', 112.41, 'Transition Metal', 5, 12, 'Solid'],
  [49, 'In', 'Indium', 114.82, 'Post-transition Metal', 5, 13, 'Solid'],
  [50, 'Sn', 'Tin', 118.71, 'Post-transition Metal', 5, 14, 'Solid'],
  [51, 'Sb', 'Antimony', 121.76, 'Metalloid', 5, 15, 'Solid'],
  [52, 'Te', 'Tellurium', 127.60, 'Metalloid', 5, 16, 'Solid'],
  [53, 'I', 'Iodine', 126.90, 'Halogen', 5, 17, 'Solid'],
  [54, 'Xe', 'Xenon', 131.29, 'Noble Gas', 5, 18, 'Gas'],
  [55, 'Cs', 'Cesium', 132.91, 'Alkali Metal', 6, 1, 'Solid'],
  [56, 'Ba', 'Barium', 137.33, 'Alkaline Earth Metal', 6, 2, 'Solid'],
  [57, 'La', 'Lanthanum', 138.91, 'Lanthanide', 6, 0, 'Solid'],
  [58, 'Ce', 'Cerium', 140.12, 'Lanthanide', 6, 0, 'Solid'],
  [59, 'Pr', 'Praseodymium', 140.91, 'Lanthanide', 6, 0, 'Solid'],
  [60, 'Nd', 'Neodymium', 144.24, 'Lanthanide', 6, 0, 'Solid'],
  [61, 'Pm', 'Promethium', 145.0, 'Lanthanide', 6, 0, 'Solid'],
  [62, 'Sm', 'Samarium', 150.36, 'Lanthanide', 6, 0, 'Solid'],
  [63, 'Eu', 'Europium', 151.96, 'Lanthanide', 6, 0, 'Solid'],
  [64, 'Gd', 'Gadolinium', 157.25, 'Lanthanide', 6, 0, 'Solid'],
  [65, 'Tb', 'Terbium', 158.93, 'Lanthanide', 6, 0, 'Solid'],
  [66, 'Dy', 'Dysprosium', 162.50, 'Lanthanide', 6, 0, 'Solid'],
  [67, 'Ho', 'Holmium', 164.93, 'Lanthanide', 6, 0, 'Solid'],
  [68, 'Er', 'Erbium', 167.26, 'Lanthanide', 6, 0, 'Solid'],
  [69, 'Tm', 'Thulium', 168.93, 'Lanthanide', 6, 0, 'Solid'],
  [70, 'Yb', 'Ytterbium', 173.05, 'Lanthanide', 6, 0, 'Solid'],
  [71, 'Lu', 'Lutetium', 174.97, 'Lanthanide', 6, 0, 'Solid'],
  [72, 'Hf', 'Hafnium', 178.49, 'Transition Metal', 6, 4, 'Solid'],
  [73, 'Ta', 'Tantalum', 180.95, 'Transition Metal', 6, 5, 'Solid'],
  [74, 'W', 'Tungsten', 183.84, 'Transition Metal', 6, 6, 'Solid'],
  [75, 'Re', 'Rhenium', 186.21, 'Transition Metal', 6, 7, 'Solid'],
  [76, 'Os', 'Osmium', 190.23, 'Transition Metal', 6, 8, 'Solid'],
  [77, 'Ir', 'Iridium', 192.22, 'Transition Metal', 6, 9, 'Solid'],
  [78, 'Pt', 'Platinum', 195.08, 'Transition Metal', 6, 10, 'Solid'],
  [79, 'Au', 'Gold', 196.97, 'Transition Metal', 6, 11, 'Solid'],
  [80, 'Hg', 'Mercury', 200.59, 'Transition Metal', 6, 12, 'Liquid'],
  [81, 'Tl', 'Thallium', 204.38, 'Post-transition Metal', 6, 13, 'Solid'],
  [82, 'Pb', 'Lead', 207.2, 'Post-transition Metal', 6, 14, 'Solid'],
  [83, 'Bi', 'Bismuth', 208.98, 'Post-transition Metal', 6, 15, 'Solid'],
  [84, 'Po', 'Polonium', 209.0, 'Metalloid', 6, 16, 'Solid'],
  [85, 'At', 'Astatine', 210.0, 'Halogen', 6, 17, 'Solid'],
  [86, 'Rn', 'Radon', 222.0, 'Noble Gas', 6, 18, 'Gas'],
  [87, 'Fr', 'Francium', 223.0, 'Alkali Metal', 7, 1, 'Solid'],
  [88, 'Ra', 'Radium', 226.0, 'Alkaline Earth Metal', 7, 2, 'Solid'],
  [89, 'Ac', 'Actinium', 227.0, 'Actinide', 7, 0, 'Solid'],
  [90, 'Th', 'Thorium', 232.04, 'Actinide', 7, 0, 'Solid'],
  [91, 'Pa', 'Protactinium', 231.04, 'Actinide', 7, 0, 'Solid'],
  [92, 'U', 'Uranium', 238.03, 'Actinide', 7, 0, 'Solid'],
  [93, 'Np', 'Neptunium', 237.0, 'Actinide', 7, 0, 'Solid'],
  [94, 'Pu', 'Plutonium', 244.0, 'Actinide', 7, 0, 'Solid'],
  [95, 'Am', 'Americium', 243.0, 'Actinide', 7, 0, 'Solid'],
  [96, 'Cm', 'Curium', 247.0, 'Actinide', 7, 0, 'Solid'],
  [97, 'Bk', 'Berkelium', 247.0, 'Actinide', 7, 0, 'Solid'],
  [98, 'Cf', 'Californium', 251.0, 'Actinide', 7, 0, 'Solid'],
  [99, 'Es', 'Einsteinium', 252.0, 'Actinide', 7, 0, 'Solid'],
  [100, 'Fm', 'Fermium', 257.0, 'Actinide', 7, 0, 'Solid'],
  [101, 'Md', 'Mendelevium', 258.0, 'Actinide', 7, 0, 'Solid'],
  [102, 'No', 'Nobelium', 259.0, 'Actinide', 7, 0, 'Solid'],
  [103, 'Lr', 'Lawrencium', 262.0, 'Actinide', 7, 0, 'Solid'],
  [104, 'Rf', 'Rutherfordium', 267.0, 'Transition Metal', 7, 4, 'Unknown'],
  [105, 'Db', 'Dubnium', 268.0, 'Transition Metal', 7, 5, 'Unknown'],
  [106, 'Sg', 'Seaborgium', 271.0, 'Transition Metal', 7, 6, 'Unknown'],
  [107, 'Bh', 'Bohrium', 272.0, 'Transition Metal', 7, 7, 'Unknown'],
  [108, 'Hs', 'Hassium', 270.0, 'Transition Metal', 7, 8, 'Unknown'],
  [109, 'Mt', 'Meitnerium', 276.0, 'Unknown', 7, 9, 'Unknown'],
  [110, 'Ds', 'Darmstadtium', 281.0, 'Unknown', 7, 10, 'Unknown'],
  [111, 'Rg', 'Roentgenium', 280.0, 'Unknown', 7, 11, 'Unknown'],
  [112, 'Cn', 'Copernicium', 285.0, 'Transition Metal', 7, 12, 'Unknown'],
  [113, 'Nh', 'Nihonium', 284.0, 'Unknown', 7, 13, 'Unknown'],
  [114, 'Fl', 'Flerovium', 289.0, 'Unknown', 7, 14, 'Unknown'],
  [115, 'Mc', 'Moscovium', 288.0, 'Unknown', 7, 15, 'Unknown'],
  [116, 'Lv', 'Livermorium', 293.0, 'Unknown', 7, 16, 'Unknown'],
  [117, 'Ts', 'Tennessine', 294.0, 'Halogen', 7, 17, 'Unknown'],
  [118, 'Og', 'Oganesson', 294.0, 'Noble Gas', 7, 18, 'Unknown'],
];
