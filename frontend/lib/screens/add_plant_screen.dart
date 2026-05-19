import 'package:flutter/material.dart';
import '../models/plant_model.dart';
import '../theme/app_theme.dart';
import '../widgets/plant_painter.dart';
import '../widgets/shared_widgets.dart';
import '../services/backend_api.dart';

class AddPlantScreen extends StatefulWidget {
  const AddPlantScreen({super.key});

  @override
  State<AddPlantScreen> createState() => _AddPlantScreenState();
}

class _AddPlantScreenState extends State<AddPlantScreen> {
  final BackendApi _api = BackendApi();
  int _step = 1;
  String _name = '';
  String _species = '';
  String _type = 'Indoor';
  String _location = '';
  bool _saving = false;
  bool _loadingSuggestions = true;
  String? _errorMessage;
  BackendPlant? _backendPlant;
  List<BackendPlant> _suggestedPlants = [];

  final _nameCtrl = TextEditingController();
  final _speciesCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _speciesCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_step < 3) {
      if (_step == 1 && _species.trim().isEmpty) {
        setState(() {
          _errorMessage = 'Scientific name is required to continue.';
        });
        return;
      }

      if (_step == 1 && _backendPlant == null) {
        await _resolveBackendPlant();
        if (!mounted) return;
      }
      setState(() {
        _step++;
        _errorMessage = null;
      });
      return;
    }

    if (_saving) {
      return;
    }

    final scientificName = _species.trim();
    if (scientificName.isEmpty) {
      setState(() {
        _errorMessage = 'Enter a scientific name before saving.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    try {
      final created =
          _backendPlant ??
          await _api.createPlantFromScientificName(scientificName);
      _backendPlant = created;
      final saved = await _api.upsertPlant(
        created.copyWith(
          displayName: _name.trim().isEmpty ? null : _name.trim(),
          plantType: _type,
          location: _location.trim().isEmpty ? null : _location.trim(),
        ),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Registered ${saved.label}')));
      Navigator.pop(context, saved);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _loadSuggestions() async {
    try {
      final plants = await _api.fetchPlants();
      if (!mounted) return;
      setState(() {
        _suggestedPlants = plants.take(6).toList();
        _loadingSuggestions = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingSuggestions = false;
      });
    }
  }

  Future<void> _resolveBackendPlant() async {
    final scientificName = _species.trim();
    if (scientificName.isEmpty) {
      return;
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    try {
      final created = await _api.createPlantFromScientificName(scientificName);
      if (!mounted) return;
      setState(() {
        _backendPlant = created;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
      });
      rethrow;
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  void _back() {
    if (_step > 1) {
      setState(() => _step--);
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back
              GestureDetector(
                onTap: _back,
                child: Row(
                  children: const [
                    Icon(
                      Icons.arrow_back_ios_new,
                      size: 14,
                      color: AppTheme.primaryGreen,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Back',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.primaryGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Progress
              Row(
                children: List.generate(3, (i) {
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: i < 2 ? 6 : 0),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: 4,
                        decoration: BoxDecoration(
                          color:
                              i + 1 <= _step
                                  ? AppTheme.primaryGreen
                                  : const Color(0xFFE8F0E4),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  transitionBuilder:
                      (child, anim) => FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.05, 0),
                            end: Offset.zero,
                          ).animate(anim),
                          child: child,
                        ),
                      ),
                  child: KeyedSubtree(
                    key: ValueKey(_step),
                    child:
                        _step == 1
                            ? _Step1(
                              nameCtrl: _nameCtrl,
                              speciesCtrl: _speciesCtrl,
                              loadingSuggestions: _loadingSuggestions,
                              suggestedPlants: _suggestedPlants,
                              onNameChanged: (v) => setState(() => _name = v),
                              onSpeciesChanged: (v) {
                                setState(() {
                                  _species = v;
                                  _backendPlant = null;
                                });
                              },
                              onQuickPick: (n) {
                                _nameCtrl.text = n;
                                _speciesCtrl.text = n;
                                setState(() {
                                  _name = n;
                                  _species = n;
                                  _backendPlant = null;
                                });
                              },
                            )
                            : _step == 2
                            ? _Step2(
                              type: _type,
                              locationCtrl: _locationCtrl,
                              onTypeChanged: (t) => setState(() => _type = t),
                              onLocationChanged:
                                  (l) => setState(() => _location = l),
                            )
                            : _Step3(
                              name: _name,
                              species: _species,
                              type: _type,
                              location: _location,
                              backendPlant: _backendPlant,
                            ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              GreenButton(
                label:
                    _saving
                        ? 'Saving...'
                        : (_step == 3 ? 'Register Plant' : 'Continue'),
                disabled: _saving || (_step == 1 && _species.isEmpty),
                onTap: () {
                  _next();
                },
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 10),
                Text(
                  _errorMessage!,
                  style: const TextStyle(fontSize: 12, color: AppTheme.danger),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Step1 extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController speciesCtrl;
  final bool loadingSuggestions;
  final List<BackendPlant> suggestedPlants;
  final Function(String) onNameChanged;
  final Function(String) onSpeciesChanged;
  final Function(String) onQuickPick;

  const _Step1({
    required this.nameCtrl,
    required this.speciesCtrl,
    required this.loadingSuggestions,
    required this.suggestedPlants,
    required this.onNameChanged,
    required this.onSpeciesChanged,
    required this.onQuickPick,
  });

  @override
  Widget build(BuildContext context) {
    final quickPicks =
        suggestedPlants.isEmpty
            ? const [
              'Monstera deliciosa',
              'Epipremnum aureum',
              'Dracaena trifasciata',
              'Calathea orbifolia',
              'Ficus lyrata',
              'Spathiphyllum wallisii',
            ]
            : suggestedPlants;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Name your plant',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Give it a nickname and the scientific name used by the backend',
            style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 24),
          _Label('Nickname'),
          const SizedBox(height: 6),
          _Input(
            controller: nameCtrl,
            hint: 'e.g. My Monstera',
            onChanged: onNameChanged,
          ),
          const SizedBox(height: 16),
          _Label('Scientific name'),
          const SizedBox(height: 6),
          _Input(
            controller: speciesCtrl,
            hint: 'e.g. Monstera deliciosa',
            italic: true,
            onChanged: onSpeciesChanged,
          ),
          const SizedBox(height: 20),
          const Text(
            'OR CHOOSE FROM COMMON PLANTS',
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          if (loadingSuggestions)
            const LinearProgressIndicator(minHeight: 2)
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  quickPicks.map((item) {
                    final label =
                        item is BackendPlant ? item.label : item as String;
                    final value =
                        item is BackendPlant ? item.species : item as String;
                    return GestureDetector(
                      onTap: () => onQuickPick(value),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color:
                              speciesCtrl.text.trim().toLowerCase() ==
                                      value.trim().toLowerCase()
                                  ? AppTheme.primaryGreen
                                  : AppTheme.mintBg,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color:
                                speciesCtrl.text.trim().toLowerCase() ==
                                        value.trim().toLowerCase()
                                    ? Colors.white
                                    : const Color(0xFF374151),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
            ),
        ],
      ),
    );
  }
}

class _Step2 extends StatelessWidget {
  final String type;
  final TextEditingController locationCtrl;
  final Function(String) onTypeChanged;
  final Function(String) onLocationChanged;

  const _Step2({
    required this.type,
    required this.locationCtrl,
    required this.onTypeChanged,
    required this.onLocationChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Plant type',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Where will this plant live?',
            style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _TypeCard(
                label: 'Indoor',
                desc: 'Inside your home',
                icon: Icons.home_outlined,
                selected: type == 'Indoor',
                onTap: () => onTypeChanged('Indoor'),
              ),
              const SizedBox(width: 12),
              _TypeCard(
                label: 'Outdoor',
                desc: 'On a patio or garden',
                icon: Icons.yard_outlined,
                selected: type == 'Outdoor',
                onTap: () => onTypeChanged('Outdoor'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _Label('Location in greenhouse'),
          const SizedBox(height: 6),
          _Input(
            controller: locationCtrl,
            hint: 'e.g. Zone A, Shelf 2',
            onChanged: onLocationChanged,
          ),
        ],
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  final String label;
  final String desc;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _TypeCard({
    required this.label,
    required this.desc,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: selected ? AppTheme.lightGreen : AppTheme.mintBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? AppTheme.primaryGreen : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color:
                      selected
                          ? AppTheme.primaryGreen
                          : const Color(0xFFE8F0E4),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: selected ? Colors.white : AppTheme.textMuted,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                desc,
                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Step3 extends StatelessWidget {
  final String name;
  final String species;
  final String type;
  final String location;
  final BackendPlant? backendPlant;

  const _Step3({
    required this.name,
    required this.species,
    required this.type,
    required this.location,
    required this.backendPlant,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'All set',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Review and register your plant with Symbiosis',
            style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.mintBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Center(
                  child: PlantWidget(
                    type:
                        backendPlant?.svgType ??
                        BackendPlant.svgTypeFor(
                          name.isNotEmpty ? name : species,
                          species,
                          species.isNotEmpty ? species : name,
                        ),
                    color: AppTheme.primaryGreen,
                    size: 100,
                  ),
                ),
                const SizedBox(height: 16),
                ...[
                  ['Name', name.isEmpty ? 'Unnamed plant' : name],
                  ['Scientific name', species.isEmpty ? 'Unknown' : species],
                  ['Type', type],
                  ['Location', location.isEmpty ? 'Unassigned' : location],
                  [
                    'Backend profile',
                    backendPlant != null
                        ? '${backendPlant!.commonName} · ${backendPlant!.typeLabel}'
                        : 'Will be created when you save',
                  ],
                  [
                    'Target moisture',
                    backendPlant != null
                        ? '${backendPlant!.optimalMoisture.round()}%'
                        : 'Auto from backend',
                  ],
                  [
                    'Target light',
                    backendPlant != null
                        ? backendPlant!.lightValue.toStringAsFixed(1)
                        : 'Auto from backend',
                  ],
                ].asMap().entries.map(
                  (e) => Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              e.value[0],
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.textMuted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              e.value[1],
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (e.key < 6)
                        const Divider(color: Color(0xFFE5E7EB), height: 0),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.lightGreen,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: const [
                Icon(
                  Icons.memory_outlined,
                  color: AppTheme.primaryGreen,
                  size: 20,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'The plant profile will be stored in MongoDB and made available to the UI and allocation cycle',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF1A6B3A),
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        color: AppTheme.textSecondary,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _Input extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool italic;
  final Function(String) onChanged;

  const _Input({
    required this.controller,
    required this.hint,
    this.italic = false,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.mintBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: TextStyle(
          fontSize: 14,
          color: AppTheme.textPrimary,
          fontStyle: italic ? FontStyle.italic : FontStyle.normal,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 14, color: AppTheme.textMuted),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
        ),
      ),
    );
  }
}
