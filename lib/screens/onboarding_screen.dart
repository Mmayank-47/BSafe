import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:safe/screens/main_navigation_shell.dart';

// ─────────────────────────────────────────────────────────────────
// DATA MODELS
// ─────────────────────────────────────────────────────────────────
class SafetyProfile {
  String fullName;
  String age;
  String homeAddress;

  SafetyProfile({
    this.fullName = '',
    this.age = '',
    this.homeAddress = '',
  });
}

class TrustedContact {
  String name;
  String phone;
  String relationship;

  TrustedContact({
    this.name = '',
    this.phone = '',
    this.relationship = 'Parent',
  });

  bool get isValid =>
      name.trim().isNotEmpty &&
      phone.trim().isNotEmpty &&
      RegExp(r'^\+?[0-9]{7,15}$').hasMatch(phone.trim());
}

// ─────────────────────────────────────────────────────────────────
// ONBOARDING SHELL
// ─────────────────────────────────────────────────────────────────
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  int _currentStep = 0;
  final SafetyProfile _profile = SafetyProfile();
  final List<TrustedContact> _contacts = [TrustedContact()];

  late AnimationController _slideController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _goToStep2() {
    setState(() {
      _currentStep = 1;
      _slideController.reset();
      _slideController.forward();
    });
  }

  void _goToStep1() {
    setState(() {
      _currentStep = 0;
      _slideController.reset();
      _slideController.forward();
    });
  }

  void _finishSetup() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const MainNavigationShell(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFF0F5), // warm blush
              Color(0xFFF3E8FF), // soft lavender
              Color(0xFFE8F4FD), // sky mist
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── Progress Header ──
              _buildProgressHeader(),

              // ── Step Content ──
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  transitionBuilder: (child, animation) {
                    final offsetAnimation = Tween<Offset>(
                      begin: const Offset(0.35, 0),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ));
                    return SlideTransition(
                        position: offsetAnimation,
                        child: FadeTransition(opacity: animation, child: child));
                  },
                  child: _currentStep == 0
                      ? Step1PersonalDetails(
                          key: const ValueKey('step1'),
                          profile: _profile,
                          onNext: _goToStep2,
                          pulseController: _pulseController,
                        )
                      : Step2TrustedContacts(
                          key: const ValueKey('step2'),
                          contacts: _contacts,
                          onBack: _goToStep1,
                          onFinish: _finishSetup,
                          pulseController: _pulseController,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Column(
        children: [
          // Logo + Brand
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.shield_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                'bSafe',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1E1B4B),
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.2)),
                ),
                child: Text(
                  'Step ${_currentStep + 1} of 2',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF8B5CF6),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              children: [
                Container(
                  height: 6,
                  width: double.infinity,
                  color: const Color(0xFFE9D5FF),
                ),
                AnimatedFractionallySizedBox(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                  widthFactor: _currentStep == 0 ? 0.5 : 1.0,
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _progressLabel('Safety Profile', _currentStep >= 0),
              _progressLabel('Trusted Contacts', _currentStep >= 1),
            ],
          ),
        ],
      ),
    );
  }

  Widget _progressLabel(String text, bool active) {
    return Text(
      text,
      style: GoogleFonts.outfit(
        fontSize: 10.5,
        fontWeight: active ? FontWeight.w700 : FontWeight.w400,
        color: active ? const Color(0xFF8B5CF6) : const Color(0xFF94A3B8),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// STEP 1 — PERSONAL DETAILS
// ─────────────────────────────────────────────────────────────────
class Step1PersonalDetails extends StatefulWidget {
  final SafetyProfile profile;
  final VoidCallback onNext;
  final AnimationController pulseController;

  const Step1PersonalDetails({
    super.key,
    required this.profile,
    required this.onNext,
    required this.pulseController,
  });

  @override
  State<Step1PersonalDetails> createState() => _Step1PersonalDetailsState();
}

class _Step1PersonalDetailsState extends State<Step1PersonalDetails> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _ageCtrl;
  late TextEditingController _addressCtrl;
  bool _isLocating = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.profile.fullName);
    _ageCtrl = TextEditingController(text: widget.profile.age);
    _addressCtrl = TextEditingController(text: widget.profile.homeAddress);

    _nameCtrl.addListener(_sync);
    _ageCtrl.addListener(_sync);
    _addressCtrl.addListener(_sync);
  }

  void _sync() {
    widget.profile.fullName = _nameCtrl.text;
    widget.profile.age = _ageCtrl.text;
    widget.profile.homeAddress = _addressCtrl.text;
    setState(() {});
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  bool get _isFormValid {
    final name = _nameCtrl.text.trim();
    final age = int.tryParse(_ageCtrl.text.trim()) ?? 0;
    final address = _addressCtrl.text.trim();
    return name.isNotEmpty && age >= 13 && address.isNotEmpty;
  }

  Future<void> _autofillLocation() async {
    setState(() => _isLocating = true);
    await Future.delayed(const Duration(milliseconds: 1200));
    if (mounted) {
      _addressCtrl.text = 'Civil Lines, Nagpur, Maharashtra 440001';
      setState(() => _isLocating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        children: [
          // Illustration / Icon cluster
          Center(
            child: AnimatedBuilder(
              animation: widget.pulseController,
              builder: (context, child) {
                final scale =
                    1.0 + widget.pulseController.value * 0.04;
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF9A8D4), Color(0xFFC084FC)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFC084FC).withValues(alpha: 0.35),
                          blurRadius: 20,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.person_rounded,
                        size: 42, color: Colors.white),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 20),

          // Title
          Text(
            "Let's set up your\nsafety profile",
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1E1B4B),
              height: 1.25,
            ),
          ),

          const SizedBox(height: 8),

          // Subtext
          Center(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline_rounded,
                      size: 13, color: Color(0xFF8B5CF6)),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      'Your information is private and only used to keep you safe.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: const Color(0xFF7C3AED),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 28),

          // ── FORM CARD ──
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.9), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Full Name
                _fieldLabel('Full Name', isRequired: true),
                const SizedBox(height: 6),
                _buildTextField(
                  controller: _nameCtrl,
                  hint: 'e.g. Priya Sharma',
                  icon: Icons.badge_outlined,
                  inputType: TextInputType.name,
                  textCapitalization: TextCapitalization.words,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                  semanticsLabel: 'Full Name input',
                ),

                const SizedBox(height: 18),

                // Age
                _fieldLabel('Age', isRequired: true),
                const SizedBox(height: 6),
                _buildTextField(
                  controller: _ageCtrl,
                  hint: 'Must be 13 or older',
                  icon: Icons.cake_outlined,
                  inputType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    if (n == null) return 'Enter a valid age';
                    if (n < 13) return 'Must be 13 or older';
                    if (n > 120) return 'Enter a valid age';
                    return null;
                  },
                  semanticsLabel: 'Age input',
                ),
                if (_ageCtrl.text.isNotEmpty &&
                    (int.tryParse(_ageCtrl.text) ?? 0) < 13)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 2),
                    child: Text(
                      '⚠ Must be 13 years or older to use bSafe.',
                      style: GoogleFonts.outfit(
                          fontSize: 11, color: const Color(0xFFEF4444)),
                    ),
                  ),

                const SizedBox(height: 18),

                // Home Address
                _fieldLabel('Home Address', isRequired: true),
                const SizedBox(height: 6),
                _buildTextField(
                  controller: _addressCtrl,
                  hint: 'Your home or safe location',
                  icon: Icons.home_outlined,
                  inputType: TextInputType.streetAddress,
                  maxLines: 2,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Address is required' : null,
                  semanticsLabel: 'Home address input',
                ),

                const SizedBox(height: 10),

                // Auto-fill location button
                GestureDetector(
                  onTap: _isLocating ? null : _autofillLocation,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0EA5E9).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: const Color(0xFF0EA5E9).withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _isLocating
                            ? const SizedBox(
                                width: 13,
                                height: 13,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF0EA5E9)),
                              )
                            : const Icon(Icons.my_location_rounded,
                                size: 14, color: Color(0xFF0EA5E9)),
                        const SizedBox(width: 6),
                        Text(
                          _isLocating
                              ? 'Locating…'
                              : 'Use current location',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF0EA5E9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Privacy micro-copy
          Center(
            child: Text(
              '🔒  Only shared with trusted contacts during an SOS alert.',
              style: GoogleFonts.outfit(
                  fontSize: 11,
                  color: const Color(0xFF94A3B8),
                  fontWeight: FontWeight.w500),
            ),
          ),

          const SizedBox(height: 24),

          // Next Button
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: _isFormValid
                  ? const LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    )
                  : null,
              color: _isFormValid ? null : const Color(0xFFE2E8F0),
              boxShadow: _isFormValid
                  ? [
                      BoxShadow(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: _isFormValid
                    ? () {
                        if (_formKey.currentState?.validate() ?? false) {
                          widget.onNext();
                        }
                      }
                    : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Next',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _isFormValid
                              ? Colors.white
                              : const Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded,
                          size: 18,
                          color: _isFormValid
                              ? Colors.white
                              : const Color(0xFF94A3B8)),
                    ],
                  ),
                ),
              ),
            ),
          ),

          if (!_isFormValid)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Center(
                child: Text(
                  'Please fill in all required fields to continue.',
                  style: GoogleFonts.outfit(
                      fontSize: 11.5, color: const Color(0xFFFF6B8A)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// STEP 2 — TRUSTED CONTACTS
// ─────────────────────────────────────────────────────────────────
class Step2TrustedContacts extends StatefulWidget {
  final List<TrustedContact> contacts;
  final VoidCallback onBack;
  final VoidCallback onFinish;
  final AnimationController pulseController;

  const Step2TrustedContacts({
    super.key,
    required this.contacts,
    required this.onBack,
    required this.onFinish,
    required this.pulseController,
  });

  @override
  State<Step2TrustedContacts> createState() => _Step2TrustedContactsState();
}

class _Step2TrustedContactsState extends State<Step2TrustedContacts> {
  final List<TextEditingController> _nameCtls = [];
  final List<TextEditingController> _phoneCtls = [];
  final List<String> _relationships = [];

  final List<String> _relationshipOptions = [
    'Parent',
    'Sibling',
    'Spouse/Partner',
    'Friend',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    for (final c in widget.contacts) {
      _nameCtls.add(TextEditingController(text: c.name));
      _phoneCtls.add(TextEditingController(text: c.phone));
      _relationships.add(c.relationship);
    }
    _syncListeners();
  }

  void _syncListeners() {
    for (int i = 0; i < _nameCtls.length; i++) {
      final idx = i;
      _nameCtls[idx].addListener(() {
        widget.contacts[idx].name = _nameCtls[idx].text;
        setState(() {});
      });
      _phoneCtls[idx].addListener(() {
        widget.contacts[idx].phone = _phoneCtls[idx].text;
        setState(() {});
      });
    }
  }

  void _addContact() {
    if (widget.contacts.length >= 5) return;
    widget.contacts.add(TrustedContact());
    _nameCtls.add(TextEditingController());
    _phoneCtls.add(TextEditingController());
    _relationships.add('Parent');
    setState(() {});
    _syncListeners();
  }

  void _removeContact(int index) {
    if (widget.contacts.length <= 1) return;
    widget.contacts.removeAt(index);
    _nameCtls[index].dispose();
    _phoneCtls[index].dispose();
    _nameCtls.removeAt(index);
    _phoneCtls.removeAt(index);
    _relationships.removeAt(index);
    setState(() {});
  }

  @override
  void dispose() {
    for (final c in _nameCtls) {
      c.dispose();
    }
    for (final c in _phoneCtls) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _atLeastOneValid =>
      widget.contacts.any((c) => c.isValid);

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      children: [
        // Icon
        Center(
          child: AnimatedBuilder(
            animation: widget.pulseController,
            builder: (context, child) {
              final scale = 1.0 + widget.pulseController.value * 0.04;
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF34D399), Color(0xFF0EA5E9)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF34D399).withValues(alpha: 0.35),
                        blurRadius: 20,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.people_rounded,
                      size: 42, color: Colors.white),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 20),

        Text(
          'Add your trusted\ncontacts',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1E1B4B),
            height: 1.25,
          ),
        ),

        const SizedBox(height: 8),

        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF34D399).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.shield_outlined,
                    size: 13, color: Color(0xFF059669)),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    'Add at least one person we can alert in an emergency. Up to 5.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: const Color(0xFF047857),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Contact Cards
        ...List.generate(widget.contacts.length, (i) {
          return _ContactCard(
            index: i,
            total: widget.contacts.length,
            nameCtrl: _nameCtls[i],
            phoneCtrl: _phoneCtls[i],
            relationship: _relationships[i],
            relationshipOptions: _relationshipOptions,
            onRelationshipChanged: (val) {
              setState(() {
                _relationships[i] = val;
                widget.contacts[i].relationship = val;
              });
            },
            onRemove: widget.contacts.length > 1
                ? () => _removeContact(i)
                : null,
          );
        }),

        const SizedBox(height: 12),

        // Add contact button
        if (widget.contacts.length < 5)
          Semantics(
            label: 'Add another contact',
            button: true,
            child: GestureDetector(
              onTap: _addContact,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                        ),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: const Icon(Icons.add_rounded,
                          size: 16, color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '+ Add another contact (${widget.contacts.length}/5)',
                      style: GoogleFonts.outfit(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF8B5CF6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        const SizedBox(height: 16),

        // Privacy micro-copy
        Center(
          child: Text(
            '🔒  Contacts are only notified during an active SOS alert.',
            style: GoogleFonts.outfit(
                fontSize: 11,
                color: const Color(0xFF94A3B8),
                fontWeight: FontWeight.w500),
          ),
        ),

        const SizedBox(height: 24),

        // Finish Setup Button
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: _atLeastOneValid
                ? const LinearGradient(
                    colors: [Color(0xFF34D399), Color(0xFF0EA5E9)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                : null,
            color: _atLeastOneValid ? null : const Color(0xFFE2E8F0),
            boxShadow: _atLeastOneValid
                ? [
                    BoxShadow(
                      color: const Color(0xFF34D399).withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: _atLeastOneValid ? widget.onFinish : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_outline_rounded,
                        size: 18,
                        color: _atLeastOneValid
                            ? Colors.white
                            : const Color(0xFF94A3B8)),
                    const SizedBox(width: 8),
                    Text(
                      'Finish Setup',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _atLeastOneValid
                            ? Colors.white
                            : const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        if (!_atLeastOneValid)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Center(
              child: Text(
                'Add at least one valid contact to continue.',
                style: GoogleFonts.outfit(
                    fontSize: 11.5, color: const Color(0xFFFF6B8A)),
              ),
            ),
          ),

        const SizedBox(height: 16),

        // Back link
        Center(
          child: Semantics(
            label: 'Go back to Step 1 Personal Details',
            button: true,
            child: TextButton.icon(
              onPressed: widget.onBack,
              icon: const Icon(Icons.arrow_back_rounded,
                  size: 16, color: Color(0xFF8B5CF6)),
              label: Text(
                'Back to personal details',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF8B5CF6),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// CONTACT CARD WIDGET
// ─────────────────────────────────────────────────────────────────
class _ContactCard extends StatelessWidget {
  final int index;
  final int total;
  final TextEditingController nameCtrl;
  final TextEditingController phoneCtrl;
  final String relationship;
  final List<String> relationshipOptions;
  final ValueChanged<String> onRelationshipChanged;
  final VoidCallback? onRemove;

  const _ContactCard({
    required this.index,
    required this.total,
    required this.nameCtrl,
    required this.phoneCtrl,
    required this.relationship,
    required this.relationshipOptions,
    required this.onRelationshipChanged,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final bool isValid = nameCtrl.text.trim().isNotEmpty &&
        phoneCtrl.text.trim().isNotEmpty &&
        RegExp(r'^\+?[0-9]{7,15}$').hasMatch(phoneCtrl.text.trim());

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isValid
              ? const Color(0xFF34D399).withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.9),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                      ),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    index == 0 ? 'Primary Contact' : 'Contact ${index + 1}',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: const Color(0xFF1E1B4B),
                    ),
                  ),
                  if (isValid) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.check_circle_rounded,
                        color: Color(0xFF34D399), size: 16),
                  ],
                ],
              ),
              if (onRemove != null)
                Semantics(
                  label: 'Remove contact ${index + 1}',
                  button: true,
                  child: GestureDetector(
                    onTap: onRemove,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.close_rounded,
                          size: 14, color: Color(0xFFEF4444)),
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 14),

          // Name
          _fieldLabel('Name', isRequired: true),
          const SizedBox(height: 6),
          _buildTextField(
            controller: nameCtrl,
            hint: 'Contact full name',
            icon: Icons.person_outline_rounded,
            inputType: TextInputType.name,
            textCapitalization: TextCapitalization.words,
            semanticsLabel: 'Contact ${index + 1} name input',
          ),

          const SizedBox(height: 14),

          // Phone
          _fieldLabel('Phone Number', isRequired: true),
          const SizedBox(height: 6),
          _buildTextField(
            controller: phoneCtrl,
            hint: '+91 9876543210',
            icon: Icons.phone_outlined,
            inputType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d\+\-\s]'))
            ],
            semanticsLabel: 'Contact ${index + 1} phone number input',
          ),
          if (phoneCtrl.text.trim().isNotEmpty &&
              !RegExp(r'^\+?[0-9]{7,15}$').hasMatch(phoneCtrl.text.trim()))
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 2),
              child: Text(
                '⚠ Enter a valid phone number',
                style: GoogleFonts.outfit(
                    fontSize: 11, color: const Color(0xFFEF4444)),
              ),
            ),

          const SizedBox(height: 14),

          // Relationship Dropdown
          _fieldLabel('Relationship', isRequired: false),
          const SizedBox(height: 6),
          Semantics(
            label: 'Relationship type for contact ${index + 1}',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: relationship,
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFF8B5CF6)),
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF1E1B4B),
                  ),
                  items: relationshipOptions.map((r) {
                    return DropdownMenuItem<String>(
                      value: r,
                      child: Text(r),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) onRelationshipChanged(val);
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// SHARED HELPERS
// ─────────────────────────────────────────────────────────────────
Widget _fieldLabel(String label, {bool isRequired = false}) {
  return Semantics(
    label: label,
    child: Row(
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF374151),
          ),
        ),
        if (isRequired) ...[
          const SizedBox(width: 3),
          const Text(
            '*',
            style: TextStyle(
                color: Color(0xFFEC4899),
                fontWeight: FontWeight.bold,
                fontSize: 14),
          ),
        ],
      ],
    ),
  );
}

Widget _buildTextField({
  required TextEditingController controller,
  required String hint,
  required IconData icon,
  TextInputType inputType = TextInputType.text,
  TextCapitalization textCapitalization = TextCapitalization.none,
  List<TextInputFormatter>? inputFormatters,
  String? Function(String?)? validator,
  int maxLines = 1,
  required String semanticsLabel,
}) {
  return Semantics(
    label: semanticsLabel,
    textField: true,
    child: TextFormField(
      controller: controller,
      keyboardType: inputType,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      validator: validator,
      style: GoogleFonts.outfit(
        fontSize: 14.5,
        fontWeight: FontWeight.w500,
        color: const Color(0xFF1E1B4B),
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.outfit(
          fontSize: 13.5,
          color: const Color(0xFF94A3B8),
        ),
        prefixIcon: Icon(icon, color: const Color(0xFF8B5CF6), size: 18),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: Color(0xFF8B5CF6), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
      ),
    ),
  );
}
