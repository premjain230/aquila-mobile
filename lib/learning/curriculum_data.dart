const curriculumConcepts = [
  {"conceptId":"math.rational_numbers","subject":"Mathematics","topic":"Number System","name":"Rational Numbers","difficulty":0.3,"prerequisites":[],"relatedConcepts":["math.irrational_numbers"]},
  {"conceptId":"math.irrational_numbers","subject":"Mathematics","topic":"Number System","name":"Irrational Numbers","difficulty":0.4,"prerequisites":["math.rational_numbers"],"relatedConcepts":["math.real_numbers"]},
  {"conceptId":"math.real_numbers","subject":"Mathematics","topic":"Number System","name":"Real Numbers","difficulty":0.4,"prerequisites":["math.rational_numbers","math.irrational_numbers"],"relatedConcepts":[]},
  {"conceptId":"math.sets","subject":"Mathematics","topic":"Sets","name":"Sets","difficulty":0.3,"prerequisites":[],"relatedConcepts":[]},
  {"conceptId":"math.algebraic_expressions","subject":"Mathematics","topic":"Algebra","name":"Algebraic Expressions","difficulty":0.4,"prerequisites":["math.rational_numbers"],"relatedConcepts":["math.linear_equations"]},
  {"conceptId":"math.linear_equations","subject":"Mathematics","topic":"Algebra","name":"Linear Equations","difficulty":0.5,"prerequisites":["math.rational_numbers","math.algebraic_expressions"],"relatedConcepts":["math.polynomials"]},
  {"conceptId":"math.polynomials","subject":"Mathematics","topic":"Algebra","name":"Polynomials","difficulty":0.6,"prerequisites":["math.algebraic_expressions"],"relatedConcepts":[]},
  {"conceptId":"science.physics.motion","subject":"Science","topic":"Physics","name":"Motion","difficulty":0.4,"prerequisites":[],"relatedConcepts":["science.physics.force"]},
  {"conceptId":"science.physics.force","subject":"Science","topic":"Physics","name":"Force","difficulty":0.5,"prerequisites":["science.physics.motion"],"relatedConcepts":[]},
  {"conceptId":"science.chemistry.matter","subject":"Science","topic":"Chemistry","name":"Matter","difficulty":0.3,"prerequisites":[],"relatedConcepts":["science.chemistry.atoms"]},
  {"conceptId":"science.chemistry.atoms","subject":"Science","topic":"Chemistry","name":"Atoms","difficulty":0.5,"prerequisites":["science.chemistry.matter"],"relatedConcepts":[]},
  {"conceptId":"science.biology.cell","subject":"Science","topic":"Biology","name":"Cell","difficulty":0.4,"prerequisites":[],"relatedConcepts":["science.biology.tissues"]},
  {"conceptId":"science.biology.tissues","subject":"Science","topic":"Biology","name":"Tissues","difficulty":0.5,"prerequisites":["science.biology.cell"],"relatedConcepts":[]},
];
const conceptAliases = {
  "mathematics_algebra":"math.algebraic_expressions",
  "physics_kinematics":"science.physics.motion",
};
String resolveConceptId(String id)=> conceptAliases[id] ?? id;
