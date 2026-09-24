<?php
// Requires PHP with cURL. The key belongs in the environment or a private config.
ini_set('display_errors', '0');
header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');

function gn_error($status, $message)
{
    http_response_code($status);
    echo json_encode(['error' => $message]);
    exit;
}

$endpoint = isset($_GET['endpoint']) ? $_GET['endpoint'] : '';
$methods = ['getuser' => 'GET', 'sql' => 'POST', 'sqltran' => 'POST'];
if (!is_string($endpoint) || !isset($methods[$endpoint])) {
    gn_error(400, 'Unknown endpoint');
}

$method = isset($_SERVER['REQUEST_METHOD']) ? $_SERVER['REQUEST_METHOD'] : '';
if ($method !== $methods[$endpoint]) {
    header('Allow: ' . $methods[$endpoint]);
    gn_error(405, 'Method not allowed');
}

$expectedKey = getenv('GN_API_KEY');
// ECAD's existing nginx rules deny all HTTP access to .config.
// Never deploy this config without equivalent access protection.
if (!is_string($expectedKey) || $expectedKey === '') {
    $configFile = __DIR__ . '/.config/gn-api/config.php';
    if (is_readable($configFile)) {
        $privateConfig = require $configFile;
        $expectedKey = isset($privateConfig['GN_API_KEY']) ? $privateConfig['GN_API_KEY'] : '';
    }
}
if (!is_string($expectedKey) || $expectedKey === '') {
    gn_error(503, 'API key is not configured');
}
$providedKey = isset($_SERVER['HTTP_X_GN_API_KEY']) ? $_SERVER['HTTP_X_GN_API_KEY'] : '';
if (!is_string($providedKey) || !hash_equals($expectedKey, $providedKey)) {
    gn_error(401, 'Unauthorized');
}
if (!extension_loaded('curl')) {
    gn_error(503, 'Proxy is unavailable');
}

// Preserve raw query values, encoding, order and duplicate parameters.
// Only the proxy's endpoint selector is removed.
$query = [];
foreach (explode('&', isset($_SERVER['QUERY_STRING']) ? $_SERVER['QUERY_STRING'] : '') as $part) {
    $name = urldecode(explode('=', $part, 2)[0]);
    if ($part !== '' && $name !== 'endpoint') {
        $query[] = $part;
    }
}
$url = 'http://127.0.0.1:13000/' . $endpoint;
if ($query) {
    $url .= '?' . implode('&', $query);
}

$curl = curl_init($url);
curl_setopt_array($curl, [
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_FOLLOWLOCATION => false,
    CURLOPT_PROXY => '',
    CURLOPT_CONNECTTIMEOUT => 3,
    CURLOPT_TIMEOUT => 10,
    CURLOPT_HTTPHEADER => ['Content-Type: application/json'],
]);
if ($method === 'POST') {
    $body = file_get_contents('php://input');
    if ($body === false) {
        curl_close($curl);
        gn_error(400, 'Cannot read request body');
    }
    curl_setopt($curl, CURLOPT_POST, true);
    curl_setopt($curl, CURLOPT_POSTFIELDS, $body);
}

$response = curl_exec($curl);
$error = curl_errno($curl);
$status = (int) curl_getinfo($curl, CURLINFO_HTTP_CODE);
curl_close($curl);

// Never log request bodies, credentials, response bodies or cURL error details.
if ($response === false) {
    gn_error($error === CURLE_OPERATION_TIMEDOUT ? 504 : 502,
        $error === CURLE_OPERATION_TIMEDOUT ? 'Local server timeout' : 'Local server unavailable');
}
if ($status < 100 || $status > 599) {
    gn_error(502, 'Invalid local server response');
}
http_response_code($status);
echo $response;
