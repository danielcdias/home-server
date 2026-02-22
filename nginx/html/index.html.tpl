<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Home Server Project</title>
    <link rel="icon" href="img/favicon.ico" type="image/x-icon">
    <link rel="shortcut icon" href="img/favicon.ico" type="image/x-icon">
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Poppins:wght@400;500;600&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="css/style.css">
</head>
<body>

    <header>
        <h1>Home Server Project</h1>
        <button id="theme-toggle" class="theme-toggle-button">
            <img src="img/moon.svg" id="theme-toggle-icon" alt="Mudar tema">
        </button>
    </header>

    <div class="content-wrapper">
        <img src="img/logo-light.png" alt="Home Server Logo" class="logo logo-light">
        <img src="img/logo-dark.png" alt="Home Server Logo" class="logo logo-dark">

        <main class="container">
            <ul>
                <li><a class="service-link" href="https://services.{{SERVER_HOSTNAME}}" target="_blank">Services</a></li>
                <li><a class="service-link" href="https://pihole.{{SERVER_HOSTNAME}}/admin/" target="_blank">Pi-hole</a></li>
                <li><a class="service-link" href="https://ha.{{SERVER_HOSTNAME}}" target="_blank">Home Assistant</a></li>
                <li><a class="service-link" href="https://komodo.{{SERVER_HOSTNAME}}" target="_blank">Komodo</a></li>
                <li><a class="service-link" href="https://webmin.{{SERVER_HOSTNAME}}" target="_blank">Webmin</a></li>
            </ul>
        </main>
    </div>

    <footer>
        <a class="footer-link" href="https://github.com/danielcdias/home-server" target="_blank">
            Projeto no GitHub
        </a>
    </footer>

    <script src="js/script.js"></script>
</body>
</html>
