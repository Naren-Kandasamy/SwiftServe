const fs = require('fs');

let content = fs.readFileSync('/home/nkandasamy/Desktop/SwiftServe/guest_app/assets/knowledge/fire.html', 'utf8');

let count = 1;
content = content.replace(/<div class="step-text"><strong>([^<]+)<\/strong>([^<]+)<\/div>/g, (match, strong, text) => {
    const res = `<div class="step-text"><strong data-i18n="fire_step${count}_strong">${strong}</strong><span data-i18n="fire_step${count}_text">${text}</span></div>`;
    count++;
    return res;
});

fs.writeFileSync('/home/nkandasamy/Desktop/SwiftServe/guest_app/assets/knowledge/fire.html', content);
console.log("Fixed fire.html");
