<?php
// Publish release.json only AFTER app-release.apk has been fully uploaded.
$release = json_decode(file_get_contents(__DIR__ . '/release.json'), true);
header('Cache-Control: no-store');
if (!is_array($release) || !isset($release['version'], $release['build']) ||
    !preg_match('/^\d+\.\d+\.\d+$/', $release['version']) ||
    !is_int($release['build']) || $release['build'] < 1) {
    http_response_code(503);
    exit;
}
if (($_GET['format'] ?? '') === 'json') {
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode($release);
} else {
    // Older installed apps still expect a plain version string.
    header('Content-Type: text/plain; charset=utf-8');
    echo $release['version'];
}
