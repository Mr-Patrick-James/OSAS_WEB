<?php
/**
 * View Helper Class
 * Provides utilities for rendering views, partials, and assets
 */
class View {
    private static $basePath;
    private static $assetPath;
    
    /**
     * Initialize view paths
     */
    public static function init() {
        self::$basePath = dirname(__DIR__) . '/views';
        self::$assetPath = dirname(dirname(__DIR__)) . '/assets';
    }
    
    /**
     * Get asset URL
     * Returns absolute path from document root that works from any context (including AJAX-loaded content)
     */
    public static function asset($path) {
        // Remove 'assets/' or 'app/assets/' from path if present (to avoid duplication)
        $path = ltrim($path, '/');
        if (strpos($path, 'assets/') === 0) {
            $path = substr($path, 7); // Remove 'assets/' prefix
        }
        if (strpos($path, 'app/assets/') === 0) {
            $path = substr($path, 11); // Remove 'app/assets/' prefix
        }
        
        // Extract project root from SCRIPT_NAME
        // This works correctly regardless of which file calls it
        $scriptName = $_SERVER['SCRIPT_NAME'] ?? '';
        $relativePath = '';
        
        if ($scriptName && $scriptName !== '/') {
            // Extract the first directory from the path
            // e.g., /OSAS_WEBSYS/app/views/loader.php -> OSAS_WEBSYS
            // e.g., /OSAS_WEBSYS/includes/dashboard.php -> OSAS_WEBSYS
            $parts = explode('/', trim($scriptName, '/'));
            if (!empty($parts[0])) {
                $relativePath = $parts[0];
            }
        }
        
        // If we couldn't get it from SCRIPT_NAME, try REQUEST_URI
        if (empty($relativePath)) {
            $requestUri = $_SERVER['REQUEST_URI'] ?? '';
            if ($requestUri) {
                $parsed = parse_url($requestUri);
                $uriPath = $parsed['path'] ?? '';
                if ($uriPath) {
                    $parts = explode('/', trim($uriPath, '/'));
                    if (!empty($parts[0])) {
                        $relativePath = $parts[0];
                    }
                }
            }
        }
        
        // Build absolute path from document root
        // Always start with / to make it absolute
        if (!empty($relativePath)) {
            return '/' . $relativePath . '/app/assets/' . $path;
        } else {
            return '/app/assets/' . $path;
        }
    }
    
    /**
     * Get absolute URL
     * Returns absolute path from document root
     */
    public static function url($path) {
        $path = ltrim($path, '/');
        
        $scriptName = $_SERVER['SCRIPT_NAME'] ?? '';
        $relativePath = '';
        
        if ($scriptName && $scriptName !== '/') {
            $parts = explode('/', trim($scriptName, '/'));
            if (!empty($parts[0])) {
                $relativePath = $parts[0];
            }
        }
        
        // If we couldn't get it from SCRIPT_NAME, try REQUEST_URI
        if (empty($relativePath)) {
            $requestUri = $_SERVER['REQUEST_URI'] ?? '';
            if ($requestUri) {
                $parsed = parse_url($requestUri);
                $uriPath = $parsed['path'] ?? '';
                if ($uriPath) {
                    $parts = explode('/', trim($uriPath, '/'));
                    if (!empty($parts[0])) {
                        $relativePath = $parts[0];
                    }
                }
            }
        }
        
        if (!empty($relativePath)) {
            return '/' . $relativePath . '/' . $path;
        } else {
            return '/' . $path;
        }
    }

    /**
     * Include a partial view
     */
    public static function partial($partialName, $data = []) {
        extract($data);
        $partialFile = self::$basePath . '/partials/' . $partialName . '.php';
        
        if (!file_exists($partialFile)) {
            error_log("Partial not found: $partialName");
            return;
        }
        
        require $partialFile;
    }
    
    /**
     * Render a view with layout
     */
    public static function render($viewName, $data = [], $layout = null) {
        extract($data);
        
        // Start output buffering for content
        ob_start();
        
        $viewFile = self::$basePath . '/' . $viewName . '.php';
        if (!file_exists($viewFile)) {
            die("View not found: $viewName");
        }
        
        require $viewFile;
        $content = ob_get_clean();
        
        // If layout is specified, wrap content in layout
        if ($layout) {
            $layoutFile = self::$basePath . '/layouts/' . $layout . '.php';
            if (!file_exists($layoutFile)) {
                die("Layout not found: $layout");
            }
            
            // Make $content available in layout
            require $layoutFile;
        } else {
            echo $content;
        }
    }
    
    /**
     * Escape output
     */
    public static function e($string) {
        return htmlspecialchars($string, ENT_QUOTES, 'UTF-8');
    }
    
    /**
     * Get base URL
     */
    public static function baseUrl($path = '') {
        $baseUrl = str_replace($_SERVER['DOCUMENT_ROOT'], '', dirname(dirname(__DIR__)));
        $baseUrl = str_replace('\\', '/', $baseUrl);
        $baseUrl = rtrim($baseUrl, '/');
        
        return $baseUrl . '/' . ltrim($path, '/');
    }
}

// Initialize on load
View::init();
