const fs = require('fs');
const path = require('path');

const dir = path.join(__dirname, '../assets/knowledge');
const files = [
    { name: 'burns.html', img: 'burns.png' },
    { name: 'cardiac.html', img: 'cardiac.png' },
    { name: 'choking.html', img: 'choking.png' },
    { name: 'earthquake.html', img: 'earthquake.png' },
    { name: 'fire.html', img: 'fire.png' },
    { name: 'flood.html', img: 'flood.png' },
    { name: 'gas_leak.html', img: 'gas_leak.png' },
    { name: 'security.html', img: 'security.png' },
    { name: 'wounds.html', img: 'wounds.png' },
    { name: 'other.html', img: 'other.png' }
];

files.forEach(f => {
    const filePath = path.join(dir, f.name);
    if (!fs.existsSync(filePath)) return;
    
    let content = fs.readFileSync(filePath, 'utf-8');
    
    const imgTag = `\n    <div style="text-align: center; margin: 20px 0;">\n        <img src="img/${f.img}" style="width:100%; max-width: 400px; border-radius: 12px; box-shadow: 0 4px 12px rgba(0,0,0,0.15);">\n    </div>\n    `;
    
    // Inject right after the first <h1> tag or danger div if exists
    if (!content.includes(`src="img/${f.img}"`)) {
        if (content.includes('</div>\n    \n    <h2>')) {
             content = content.replace('</div>\n    \n    <h2>', '</div>' + imgTag + '    <h2>');
        } else if (content.includes('</h1>\n    \n    <h2>')) {
             content = content.replace('</h1>\n    \n    <h2>', '</h1>' + imgTag + '    <h2>');
        } else {
             // fallback
             content = content.replace('</h1>', '</h1>' + imgTag);
        }
        
        fs.writeFileSync(filePath, content);
        console.log(`Injected ${f.img} into ${f.name}`);
    }
});
