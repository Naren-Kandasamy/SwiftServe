const fs = require('fs');

const content = fs.readFileSync('/home/nkandasamy/Desktop/SwiftServe/guest_app/assets/knowledge/js/translations.js', 'utf8');

// evaluate translations.js
eval(content);

console.log("lang=es, burns_h2_1:", getTranslation('es', 'burns_h2_1'));
console.log("lang=es, burns_step1:", getTranslation('es', 'burns_step1'));
