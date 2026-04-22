const fs = require('fs');
const path = require('path');

const dir = path.join(__dirname, '../assets/knowledge');
const files = [
    'burns.html', 'cardiac.html', 'choking.html', 'earthquake.html',
    'fire.html', 'flood.html', 'gas_leak.html', 'security.html',
    'wounds.html', 'other.html'
];

let dictionary = {};

files.forEach(file => {
    const filePath = path.join(dir, file);
    if (!fs.existsSync(filePath)) return;
    
    let content = fs.readFileSync(filePath, 'utf-8');
    const baseKey = file.replace('.html', '');
    
    // 1. Extract and replace <h1>
    content = content.replace(/<h1>([^<]+)<\/h1>/g, (match, text) => {
        const key = `${baseKey}_title`;
        dictionary[key] = text.trim();
        return `<h1 data-i18n="${key}">${text}</h1>`;
    });

    // 2. Extract and replace <h2>
    let h2Counter = 1;
    content = content.replace(/<h2>([^<]+)<\/h2>/g, (match, text) => {
        const key = `${baseKey}_h2_${h2Counter++}`;
        dictionary[key] = text.trim();
        return `<h2 data-i18n="${key}">${text}</h2>`;
    });

    // 3. Extract and replace .step-text
    let stepCounter = 1;
    content = content.replace(/<div class="step-text">([^<]+)<\/div>/g, (match, text) => {
        const key = `${baseKey}_step${stepCounter++}`;
        dictionary[key] = text.trim();
        return `<div class="step-text" data-i18n="${key}">${text}</div>`;
    });
    
    // 4. Extract and replace .danger (if exists without data-i18n)
    let dangerCounter = 1;
    content = content.replace(/<div class="danger">([^<]+)<\/div>/g, (match, text) => {
        const key = `${baseKey}_danger${dangerCounter++}`;
        dictionary[key] = text.trim();
        return `<div class="danger" data-i18n="${key}">${text}</div>`;
    });

    fs.writeFileSync(filePath, content);
    console.log(`Processed ${file}`);
});

fs.writeFileSync(path.join(__dirname, 'raw_english_dict.json'), JSON.stringify(dictionary, null, 2));
console.log('Done! Wrote raw_english_dict.json');
