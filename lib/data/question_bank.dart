/// Embedded standard-question bank used for offline-standard quizzes,
/// mirroring the role of the web app's `BANK` (a representative subset —
/// the AI quiz mode covers anything beyond these topics).
class BankQuestion {
  final String subject;
  final String topic;
  final String question;
  final List<String> options;
  final int answer; // index into options
  final String explanation;

  const BankQuestion({
    required this.subject,
    required this.topic,
    required this.question,
    required this.options,
    required this.answer,
    required this.explanation,
  });
}

class QuestionBank {
  QuestionBank._();

  static const List<BankQuestion> _all = [
    // ── Physics ──────────────────────────────────────────────
    BankQuestion(
      subject: 'Physics',
      topic: 'Laws of Motion',
      question: 'A 2 kg mass accelerates at 3 m/s². What net force acts on it?',
      options: ['1.5 N', '3 N', '5 N', '6 N'],
      answer: 3,
      explanation: 'Newton\'s second law: F = ma = 2 × 3 = 6 N.',
    ),
    BankQuestion(
      subject: 'Physics',
      topic: 'Laws of Motion',
      question: 'An object at rest stays at rest unless acted on by an unbalanced force. This is:',
      options: ['Newton\'s First Law', 'Newton\'s Second Law', 'Newton\'s Third Law', 'Law of Gravitation'],
      answer: 0,
      explanation: 'That is the statement of Newton\'s First Law (inertia).',
    ),
    BankQuestion(
      subject: 'Physics',
      topic: 'Electrostatics',
      question: 'Coulomb\'s force between two charges is:',
      options: ['Inversely proportional to distance squared', 'Directly proportional to distance', 'Independent of distance', 'Always attractive'],
      answer: 0,
      explanation: 'F = k·q₁q₂/r² — inverse square law.',
    ),
    BankQuestion(
      subject: 'Physics',
      topic: 'Thermodynamics',
      question: 'Which law states that energy can neither be created nor destroyed?',
      options: ['First Law', 'Second Law', 'Third Law', 'Zeroth Law'],
      answer: 0,
      explanation: 'The First Law of Thermodynamics is a statement of conservation of energy.',
    ),

    // ── Chemistry ────────────────────────────────────────────
    BankQuestion(
      subject: 'Chemistry',
      topic: 'Chemical Bonding',
      question: 'Which bond involves the sharing of electron pairs between atoms?',
      options: ['Ionic', 'Covalent', 'Metallic', 'Hydrogen'],
      answer: 1,
      explanation: 'Covalent bonds form by sharing electron pairs.',
    ),
    BankQuestion(
      subject: 'Chemistry',
      topic: 'Redox Reactions',
      question: 'In a redox reaction, the substance that loses electrons is:',
      options: ['Reduced', 'Oxidized', 'Neutralized', 'Precipitated'],
      answer: 1,
      explanation: 'Oxidation is the loss of electrons (OIL RIG: Oxidation Is Loss).',
    ),
    BankQuestion(
      subject: 'Chemistry',
      topic: 'Organic Chemistry',
      question: 'Which functional group is found in alcohols?',
      options: ['-COOH', '-NH₂', '-OH', '-CHO'],
      answer: 2,
      explanation: 'Alcohols contain the hydroxyl (-OH) group.',
    ),
    BankQuestion(
      subject: 'Chemistry',
      topic: 'Mole Concept',
      question: 'How many atoms are in one mole of a substance?',
      options: ['6.022 × 10²³', '3.14 × 10¹⁰', '9.8 × 10²', '1.6 × 10⁻¹⁹'],
      answer: 0,
      explanation: 'Avogadro\'s number is 6.022 × 10²³.',
    ),

    // ── Maths ────────────────────────────────────────────────
    BankQuestion(
      subject: 'Maths',
      topic: 'Calculus',
      question: 'The derivative of x² with respect to x is:',
      options: ['x', '2x', 'x²/2', '2'],
      answer: 1,
      explanation: 'd/dx (xⁿ) = n·xⁿ⁻¹, so d/dx (x²) = 2x.',
    ),
    BankQuestion(
      subject: 'Maths',
      topic: 'Trigonometry',
      question: 'What is the value of sin(90°)?',
      options: ['0', '0.5', '1', '√2/2'],
      answer: 2,
      explanation: 'sin(90°) = 1 on the unit circle.',
    ),
    BankQuestion(
      subject: 'Maths',
      topic: 'Integration',
      question: '∫ 2x dx equals:',
      options: ['x² + C', '2x² + C', 'x + C', 'x²/2 + C'],
      answer: 0,
      explanation: '∫ 2x dx = 2·(x²/2) + C = x² + C.',
    ),
    BankQuestion(
      subject: 'Maths',
      topic: 'Algebra',
      question: 'Solve: 2x + 4 = 10. x = ?',
      options: ['2', '3', '4', '6'],
      answer: 1,
      explanation: '2x = 6 ⇒ x = 3.',
    ),

    // ── Biology ──────────────────────────────────────────────
    BankQuestion(
      subject: 'Biology',
      topic: 'Cell Biology',
      question: 'Which organelle is the powerhouse of the cell?',
      options: ['Nucleus', 'Ribosome', 'Mitochondria', 'Golgi body'],
      answer: 2,
      explanation: 'Mitochondria generate ATP through cellular respiration.',
    ),
    BankQuestion(
      subject: 'Biology',
      topic: 'Genetics',
      question: 'The basic unit of heredity is the:',
      options: ['Cell', 'Gene', 'Protein', 'Chromosome'],
      answer: 1,
      explanation: 'A gene is the basic unit of heredity.',
    ),
    BankQuestion(
      subject: 'Biology',
      topic: 'Human Physiology',
      question: 'Which organ pumps blood throughout the body?',
      options: ['Lungs', 'Liver', 'Heart', 'Kidney'],
      answer: 2,
      explanation: 'The heart pumps blood through the circulatory system.',
    ),
  ];

  static List<String> subjects() {
    return _all.map((q) => q.subject).toSet().toList();
  }

  static List<String> topicsFor(String subject) {
    return _all.where((q) => q.subject == subject).map((q) => q.topic).toSet().toList();
  }

  static List<BankQuestion> questionsFor(String subject, String topic) {
    return _all.where((q) => q.subject == subject && q.topic == topic).toList();
  }

  static List<BankQuestion> questionsForSubject(String subject) {
    return _all.where((q) => q.subject == subject).toList();
  }
}