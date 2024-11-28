$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:8080/")
$listener.Start()

Write-Host "Servidor iniciado en http://localhost:8080/"

# Procesar las solicitudes HTTP
while ($true) {

    # Se crea el context para recibir las solicitudes que se puedan enviar
    $context = $listener.GetContext()
    $request = $context.Request
    $response = $context.Response

    # Se inicializa la variable de processId con el objetivo de verificar si esta el id en la URL
    $processId = $null
    if ($request.Url.Query) {
        $queryParams = $request.Url.Query.TrimStart('?').Split('&')
        foreach ($param in $queryParams) {
            $key, $value = $param.Split('=')
            if ($key -eq 'id') {
                $processId = [int]$value
            }
        }
    }

    # Si el id del proceso se encuentra y esta presente, se procede a detener el proceso
    if ($processId) {
        Try {
            # Intentar obtener el proceso por ID
            $process = Get-Process -Id $processId -ErrorAction SilentlyContinue
            if ($process) {
                # Se detiene el proceso en base al id del mismo
                Stop-Process -Id $processId -Force
                $response.StatusCode = 200

                # Se redirige la pagina luego de detener el proceso
                $response.Redirect("http://localhost:8080/")
            } else {
                # Si el proceso no existe se devuelve un error 404
                $response.StatusCode = 404
            }
        } Catch {
            # Si ocurre cualquier otro error, devolver un error 400
            $response.StatusCode = 400
        }
    } else {
        # Si no se proporciona un ID de proceso, mostrar los procesos activos
        $htmlContent = @"
<html>
<head>
    <title>Gestion de Procesos</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            background-color: #f4f4f9;
            margin: 0;
            padding: 0;
        }
        h2 {
            color: #333;
            text-align: center;
            margin-top: 20px;
        }
        .container {
            width: 80%;
            margin: 20px auto;
            background-color: #fff;
            padding: 20px;
            box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
            border-radius: 8px;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 20px;
        }
        th, td {
            padding: 10px;
            text-align: left;
            border-bottom: 1px solid #ddd;
        }
        th {
            background-color: #4CAF50;
            color: white;
        }
        tr:nth-child(even) {
            background-color: #f9f9f9;
        }
        tr:hover {
            background-color: #f1f1f1;
        }
        a {
            color: #FF5733;
            text-decoration: none;
        }
        a:hover {
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <div class="container">
        <h2>Tabla de Procesos Activos</h2>
        <table>
            <thead>
                <tr>
                    <th>ID del Proceso</th>
                    <th>Nombre del Proceso</th>
                    <th>CPU</th>
                    <th>Memoria</th>
                    <th>Acciones</th>
                </tr>
            </thead>
            <tbody>
"@
# Se obtienen los procesos del computador
        $procesos = Get-Process | Select-Object Id, ProcessName, CPU, WorkingSet
        foreach ($proceso in $procesos) {
            $htmlContent += "<tr><td>$($proceso.Id)</td><td>$($proceso.ProcessName)</td><td>$($proceso.CPU)</td><td>$([math]::round($proceso.WorkingSet / 1MB, 2)) MB</td><td><a href='?id=$($proceso.Id)'>Terminar</a></td></tr>"
        }

        $htmlContent += @"
            </tbody>
        </table>
    </div>
</body>
</html>
"@

        # Convertir el contenido HTML a bytes de manera explícita
        $byteArray = [System.Text.Encoding]::UTF8.GetBytes($htmlContent)

        # Establecer el tipo de contenido y el código de estado
        $response.ContentType = "text/html"
        $response.StatusCode = 200

        # Escribir los bytes en el OutputStream de la respuesta
        $response.OutputStream.Write($byteArray, 0, $byteArray.Length)
    }

    # Cerrar el flujo de salida
    $response.OutputStream.Close()
}
