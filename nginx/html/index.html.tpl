<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <title>Home Server Dashboard</title>
    <link rel="icon" href="/favicon.ico" type="image/x-icon">
    <link rel="shortcut icon" href="/favicon.ico" type="image/x-icon">
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            background-color: #121212; /* Fundo principal bem escuro */
            color: #E0E0E0; /* Cor de texto principal clara */
            margin: 40px;
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: calc(100vh - 80px);
        }
        .container {
            max-width: 600px;
            width: 100%;
            margin: auto;
            background: #1E1E1E; /* Fundo do "card" um pouco mais claro */
            padding: 30px;
            border-radius: 8px;
            border: 1px solid #333; /* Borda sutil para definir o container */
        }
        h1 {
            color: #FFFFFF; /* Título em branco puro para destaque */
            text-align: center;
            margin-bottom: 30px;
        }
        ul {
            list-style: none;
            padding: 0;
        }
        li {
            margin-bottom: 15px;
        }
        a {
            display: block;
            padding: 15px;
            border-radius: 6px;
            background-color: #2a2a2a;
            text-decoration: none;
            color: #64B5F6; /* Cor do link em azul claro para boa legibilidade */
            font-size: 1.2em;
            font-weight: 500;
            transition: background-color 0.3s, transform 0.2s;
        }
        a:hover {
            background-color: #333333; /* Fundo do link mais claro ao passar o mouse */
            transform: translateY(-2px); /* Efeito de elevação sutil */
            color: #90CAF9;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Serviços Disponíveis</h1>
        <ul>
            <li><a href="https://pihole.{{SERVER_HOSTNAME}}/admin/" target="_blank">Pi-hole</a></li>
            <li><a href="https://ha.{{SERVER_HOSTNAME}}" target="_blank">Home Assistant</a></li>
            <li><a href="https://komodo.{{SERVER_HOSTNAME}}" target="_blank">Komodo</a></li>
            <li><a href="https://webmin.{{SERVER_HOSTNAME}}" target="_blank">Webmin</a></li>
        </ul>
    </div>
</body>
</html>
