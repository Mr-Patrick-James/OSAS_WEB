/**
 * E-OSAS Splash Screen Controller
 * - Shows on first load, hides after animation completes
 * - Uses sessionStorage so it only shows once per session
 *   (remove that check if you want it every page load)
 */
(function () {
    'use strict';

    const SPLASH_ID = 'eosas-splash';
    const SESSION_KEY = 'eosas_splash_shown';
    const HIDE_DELAY_MS = 2400; // time before fade-out starts

    function hideSplash() {
        var splash = document.getElementById(SPLASH_ID);
        if (!splash) return;

        splash.classList.add('splash-hidden');

        // Remove from DOM after transition ends (0.55s)
        setTimeout(function () {
            if (splash && splash.parentNode) {
                splash.parentNode.removeChild(splash);
            }
        }, 600);
    }

    function initSplash() {
        var splash = document.getElementById(SPLASH_ID);
        if (!splash) return;

        // ── Skip if already shown this session ──
        // Comment out these 4 lines to show splash on EVERY load
        if (sessionStorage.getItem(SESSION_KEY)) {
            splash.parentNode && splash.parentNode.removeChild(splash);
            return;
        }
        sessionStorage.setItem(SESSION_KEY, '1');

        // Auto-hide after delay
        setTimeout(hideSplash, HIDE_DELAY_MS);

        // Also hide immediately on tap / click
        splash.addEventListener('click', hideSplash, { once: true });
    }

    // Run as soon as the DOM is ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', initSplash);
    } else {
        initSplash();
    }
})();
