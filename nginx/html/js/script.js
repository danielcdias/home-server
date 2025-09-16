document.addEventListener('DOMContentLoaded', () => {
    const themeToggleButton = document.getElementById('theme-toggle');
    const themeToggleIcon = document.getElementById('theme-toggle-icon');
    const body = document.body;

    // Função para definir o tema
    const applyTheme = (theme) => {
        if (theme === 'dark') {
            body.classList.add('dark-theme');
            themeToggleIcon.src = 'img/sun.svg';
            themeToggleIcon.alt = 'Mudar para tema claro';
        } else {
            body.classList.remove('dark-theme');
            themeToggleIcon.src = 'img/moon.svg';
            themeToggleIcon.alt = 'Mudar para tema escuro';
        }
    };

    // Botão de troca de tema
    themeToggleButton.addEventListener('click', () => {
        const isDarkMode = body.classList.contains('dark-theme');
        const newTheme = isDarkMode ? 'light' : 'dark';
        applyTheme(newTheme);
        // Salva a preferência no armazenamento local
        localStorage.setItem('theme', newTheme);
    });

    // Verifica a preferência do usuário ou do sistema no carregamento da página
    const savedTheme = localStorage.getItem('theme');
    const prefersDarkScheme = window.matchMedia('(prefers-color-scheme: dark)').matches;

    if (savedTheme) {
        // Usa o tema salvo se existir
        applyTheme(savedTheme);
    } else if (prefersDarkScheme) {
        // Caso contrário, usa a preferência do sistema
        applyTheme('dark');
    } else {
        applyTheme('light');
    }
});
