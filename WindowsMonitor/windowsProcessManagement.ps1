$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:8080/")
$listener.Start()

Write-Host "El servidor se inicio en http://localhost:8080/"

# Procesar las solicitudes HTTP
while ($true) {

    # Se crea el context para recibir las solicitudes que se puedan enviar
    $context = $listener.GetContext()
    $request = $context.Request
    $response = $context.Response

    # Se inicializa la variable de processId con el objetivo de verificar si está el id en la URL
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

    # Si el id del proceso se encuentra y está presente, se procede a detener el proceso
    if ($processId) {
        Try {
            # Intentar obtener el proceso por ID
            $process = Get-Process -Id $processId -ErrorAction SilentlyContinue
            if ($process) {
                # Detener el proceso
                Stop-Process -Id $processId -Force
                $response.StatusCode = 200

                # Redirigir a la pagina luego de cerrar el proceso
                $response.Redirect("http://localhost:8080/")
            } else {
                # Si el proceso no existe, devolver un error 404
                $response.StatusCode = 404
            }
        } Catch {
            # Si ocurre cualquier otro error, devolver un error 400
            $response.StatusCode = 400
        }
    } else {
        # Si no se proporciona un ID de proceso, mostrar los procesos activos
        $htmlContent = "<html><body><h2>Procesos Activos:</h2><table border='1'>"
        $procesos = Get-Process | Select-Object Id, ProcessName, CPU, WorkingSet
        foreach ($proceso in $procesos) {
            $htmlContent += "<tr><td>$($proceso.Id)</td><td>$($proceso.ProcessName)</td><td>$($proceso.CPU)</td><td>$($proceso.WorkingSet)</td><td><a href='?id=$($proceso.Id)'>Terminar</a></td></tr>"
        }
        $htmlContent += "</table></body></html>"

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
