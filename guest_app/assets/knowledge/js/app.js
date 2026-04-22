document.addEventListener('DOMContentLoaded', () => {
    // 1. Determine Language
    const urlParams = new URLSearchParams(window.location.search);
    const lang = window.appLang || urlParams.get('lang') || 'en';

    // 2. Localization Injection
    const ttsBtn = document.getElementById('fab-tts');
    if (ttsBtn) {
        ttsBtn.innerHTML = `<svg viewBox="0 0 24 24"><path d="M3 9v6h4l5 5V4L7 9H3zm13.5 3c0-1.77-1.02-3.29-2.5-4.03v8.05c1.48-.73 2.5-2.25 2.5-4.02zM14 3.23v2.06c2.89.86 5 3.54 5 6.71s-2.11 5.85-5 6.71v2.06c4.01-.91 7-4.49 7-8.77s-2.99-7.86-7-8.77z"/></svg> ${getTranslation(lang, 'btn_play')}`;
    }

    document.querySelectorAll('[data-i18n]').forEach(el => {
        const key = el.getAttribute('data-i18n');
        el.innerText = getTranslation(lang, key);
    });

    // 3. Interactive Checklists
    const listItems = document.querySelectorAll('li');
    listItems.forEach(item => {
        item.addEventListener('click', () => {
            item.classList.toggle('completed');
        });
    });

    // 4. Text-to-Speech (TTS)
    let isSpeaking = false;
    let synth = window.speechSynthesis;

    if (ttsBtn && synth) {
        ttsBtn.addEventListener('click', () => {
            if (isSpeaking) {
                synth.cancel();
                isSpeaking = false;
                ttsBtn.innerHTML = `<svg viewBox="0 0 24 24"><path d="M3 9v6h4l5 5V4L7 9H3zm13.5 3c0-1.77-1.02-3.29-2.5-4.03v8.05c1.48-.73 2.5-2.25 2.5-4.02zM14 3.23v2.06c2.89.86 5 3.54 5 6.71s-2.11 5.85-5 6.71v2.06c4.01-.91 7-4.49 7-8.77s-2.99-7.86-7-8.77z"/></svg> ${getTranslation(lang, 'btn_play')}`;
                return;
            }

            // Gather all text
            let textToRead = document.querySelector('h1').innerText + ". ";
            document.querySelectorAll('h2, li').forEach(el => {
                if(!el.classList.contains('completed')) {
                    textToRead += el.innerText + ". ";
                }
            });

            const utterance = new SpeechSynthesisUtterance(textToRead);
            utterance.lang = lang === 'en' ? 'en-US' : 
                             lang === 'es' ? 'es-ES' : 
                             lang === 'fr' ? 'fr-FR' : 
                             lang === 'hi' ? 'hi-IN' : 
                             lang === 'ta' ? 'ta-IN' : 'en-US';

            utterance.onend = () => {
                isSpeaking = false;
                ttsBtn.innerHTML = `<svg viewBox="0 0 24 24"><path d="M3 9v6h4l5 5V4L7 9H3zm13.5 3c0-1.77-1.02-3.29-2.5-4.03v8.05c1.48-.73 2.5-2.25 2.5-4.02zM14 3.23v2.06c2.89.86 5 3.54 5 6.71s-2.11 5.85-5 6.71v2.06c4.01-.91 7-4.49 7-8.77s-2.99-7.86-7-8.77z"/></svg> ${getTranslation(lang, 'btn_play')}`;
            };

            synth.speak(utterance);
            isSpeaking = true;
            ttsBtn.innerHTML = `🛑 ${getTranslation(lang, 'btn_stop')}`;
        });
    }
});
