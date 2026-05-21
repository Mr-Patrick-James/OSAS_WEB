<?php
/**
 * Web App Manifest — paths adapt to subfolder (local WAMP) or root (AWS).
 * AWS root:  start_url=/index.php  scope=/
 * Local:     start_url=/OSAS_WEB/index.php  scope=/OSAS_WEB/
 */
header('Content-Type: application/manifest+json; charset=utf-8');
header('Cache-Control: no-cache');

require_once __DIR__ . '/app/core/View.php';
View::init();

/** Prefix: '' at AWS root, '/OSAS_WEB' in local subfolder */
function manifestPrefix(): string {
    $appDirs = ['app', 'api', 'includes', 'assets', 'public', 'index.php', 'manifest.php', 'manifest.json', 'service-worker.js'];
    $script  = $_SERVER['SCRIPT_NAME'] ?? '';
    if ($script && $script !== '/') {
        $parts = explode('/', trim($script, '/'));
        if (!empty($parts[0]) && !in_array($parts[0], $appDirs, true)) {
            return '/' . $parts[0];
        }
    }
    return '';
}

$prefix = manifestPrefix();
$scope  = $prefix === '' ? '/' : $prefix . '/';
$start  = ($prefix === '' ? '' : $prefix) . '/index.php';
$id     = $scope;
$icon   = ($prefix === '' ? '' : $prefix) . '/app/assets/img/default.png';

echo json_encode([
    'name'             => 'E-OSAS — Student Affairs System',
    'short_name'       => 'E-OSAS',
    'description'      => 'Office of Student Affairs and Services — Colegio de Naujan',
    'id'               => $id,
    'start_url'        => $start,
    'scope'            => $scope,
    'display'          => 'standalone',
    'display_override' => ['standalone', 'browser'],
    'orientation'      => 'portrait-primary',
    'background_color' => '#0f0f0f',
    'theme_color'      => '#D4AF37',
    'categories'       => ['education', 'productivity'],
    'icons'            => [
        [
            'src'     => $icon,
            'sizes'   => '192x192',
            'type'    => 'image/png',
            'purpose' => 'any maskable',
        ],
        [
            'src'     => $icon,
            'sizes'   => '512x512',
            'type'    => 'image/png',
            'purpose' => 'any maskable',
        ],
    ],
], JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
