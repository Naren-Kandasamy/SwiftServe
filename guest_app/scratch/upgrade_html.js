const fs = require('fs');
const path = require('path');

const dir = path.join(__dirname, '../assets/knowledge');

const svgIcon = `<div class="step-icon">
    <svg viewBox="0 0 24 24"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z"/></svg>
</div>`;

const files = fs.readdirSync(dir);

files.forEach(file => {
    if (file.endsWith('.html')) {
        const filePath = path.join(dir, file);
        let content = fs.readFileSync(filePath, 'utf-8');

        // 1. Remove old inline style
        content = content.replace(/<style>[\s\S]*?<\/style>/, '');

        // 2. Inject link and scripts into head
        if (!content.includes('<link rel="stylesheet" href="css/style.css">')) {
            content = content.replace('</head>', 
                '    <link rel="stylesheet" href="css/style.css">\n' +
                '    <script src="js/translations.js"></script>\n' +
                '    <script src="js/app.js"></script>\n' +
                '</head>'
            );
        }

        // 3. Inject FAB into body
        if (!content.includes('fab-tts')) {
            content = content.replace('</body>', 
                '    <button id="fab-tts"></button>\n' +
                '</body>'
            );
        }

        // 4. Localize the danger text
        if (content.includes('IF YOU ARE IN IMMEDIATE DANGER')) {
            content = content.replace(
                /<div class="danger">.*?<\/div>/,
                '<div class="danger" data-i18n="danger_prefix">IF YOU ARE IN IMMEDIATE DANGER, LEAVE IMMEDIATELY.</div>'
            );
        }

        // 5. Inject the SVG icon into all <li> elements
        if (!content.includes('step-icon')) {
            content = content.replace(/<li>/g, `<li>\n        ${svgIcon}\n        <div class="step-text">`);
            content = content.replace(/<\/li>/g, `</div>\n    </li>`);
        }

        fs.writeFileSync(filePath, content);
        console.log(`Upgraded ${file}`);
    }
});
