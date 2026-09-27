/**
 * Demo Core - Shared state, initialization, and orchestration
 * This module handles demo triggering, state management, and connecting the parts
 */

// Global demo state
let demoTimeout = null;
let demoRunning = false;

// DOM Elements (initialized in initDemo)
let shelf, notchBar, contextMenu, demoTrigger, triggerInner, triggerGlow;
let triggerTitle, triggerSubtitle, theatreBackdrop, confettiContainer;

/**
 * Initialize the demo system
 */
function initDemo() {
    shelf = document.getElementById('shelf');
    const notch = document.getElementById('notch');
    notchBar = notch?.querySelector('.notch-bar');
    contextMenu = document.getElementById('contextMenu');
    demoTrigger = document.getElementById('demoTrigger');
    triggerInner = document.getElementById('triggerInner');
    triggerGlow = document.getElementById('triggerGlow');
    triggerTitle = document.getElementById('triggerTitle');
    triggerSubtitle = document.getElementById('triggerSubtitle');
    theatreBackdrop = document.getElementById('theatreBackdrop');
    confettiContainer = document.getElementById('confettiContainer');

    if (!shelf || !demoTrigger) {
        console.warn('Demo elements not found');
        return;
    }

    setupDemoTrigger();
    setupShelfEvents();
}

/**
 * Setup the hover trigger button with water fill animation
 */
function setupDemoTrigger() {
    let hoverTimer = null;
    const triggerFill = document.getElementById('triggerFill');
    const dropletContainer = document.getElementById('dropletContainer');

    demoTrigger.addEventListener('mouseenter', () => {
        if (demoRunning) return;
        // Skip hover trigger on mobile - only tap works
        if (window.innerWidth < 768) return;

        // Start water fill animation
        if (triggerFill) {
            triggerFill.style.transform = 'scaleY(1)';
        }

        // When fill completes (400ms), trigger droplet and start demo
        hoverTimer = setTimeout(() => {
            if (!demoRunning) {
                triggerDroplet();
                setTimeout(() => startDemo(), 400);
            }
        }, 400);
    });

    demoTrigger.addEventListener('mouseleave', () => {
        if (demoRunning) return;

        // Cancel hover
        if (hoverTimer) {
            clearTimeout(hoverTimer);
            hoverTimer = null;
        }

        // Reset water fill
        resetTriggerFill();
    });

    // Click to quit demo (or start on mobile)
    demoTrigger.addEventListener('click', () => {
        if (demoRunning) {
            stopDemo();
        } else {
            // Mobile: start on tap with fill animation
            if (window.innerWidth < 768) {
                if (triggerFill) triggerFill.style.transform = 'scaleY(1)';
                setTimeout(() => {
                    triggerDroplet();
                    setTimeout(() => startDemo(), 400);
                }, 300);
            }
        }
    });
}

/**
 * Reset the trigger fill effect
 */
function resetTriggerFill() {
    const triggerFill = document.getElementById('triggerFill');
    if (triggerFill) {
        triggerFill.style.transform = 'scaleY(0)';
    }
    if (triggerGlow) {
        triggerGlow.style.opacity = '0';
        triggerGlow.style.boxShadow = '0 0 0px 0px rgba(59, 130, 246, 0)';
    }
    if (triggerInner) {
        triggerInner.style.transform = 'scale(1)';
    }
}

/**
 * Trigger droplet animation that flies up to notch
 */
function triggerDroplet() {
    const dropletContainer = document.getElementById('dropletContainer');
    const notch = document.getElementById('notch');
    if (!dropletContainer || !notch) return;

    // Get positions
    const triggerRect = demoTrigger.getBoundingClientRect();
    const notchRect = notch.getBoundingClientRect();

    // Create subtle droplet
    const droplet = document.createElement('div');
    droplet.style.cssText = `
        position: absolute;
        width: 12px;
        height: 16px;
        left: 50%;
        top: 0;
        transform: translateX(-50%);
        background: linear-gradient(to bottom, rgba(255,255,255,0.8), rgba(100,180,255,0.6));
        border-radius: 50% 50% 50% 50% / 60% 60% 40% 40%;
        box-shadow: 0 0 8px rgba(255,255,255,0.4);
        opacity: 1;
        transition: transform 0.6s cubic-bezier(0.2, 0.8, 0.2, 1), opacity 0.6s ease-out;
    `;
    dropletContainer.appendChild(droplet);

    // Calculate distance to notch (negative = upward)
    const deltaY = notchRect.bottom - triggerRect.top - 20;

    // Animate droplet flying UP (force reflow first)
    droplet.offsetHeight;
    droplet.style.transform = `translateX(-50%) translateY(${deltaY}px)`;
    droplet.style.opacity = '0';

    // Remove after animation
    setTimeout(() => droplet.remove(), 700);
}

/**
 * Trigger confetti burst effect
 */
function triggerConfetti() {
    if (!confettiContainer) return;

    const colors = ['#3B82F6', '#10B981', '#F59E0B', '#EF4444', '#8B5CF6', '#EC4899'];
    const particleCount = 30;

    for (let i = 0; i < particleCount; i++) {
        const particle = document.createElement('div');
        particle.className = 'absolute rounded-full pointer-events-none';
        particle.style.width = (4 + Math.random() * 6) + 'px';
        particle.style.height = particle.style.width;
        particle.style.backgroundColor = colors[Math.floor(Math.random() * colors.length)];
        particle.style.left = '50%';
        particle.style.top = '50%';

        // Random direction
        const angle = (Math.PI * 2 / particleCount) * i + (Math.random() - 0.5);
        const velocity = 80 + Math.random() * 60;
        const vx = Math.cos(angle) * velocity;
        const vy = Math.sin(angle) * velocity;

        confettiContainer.appendChild(particle);

        // Animate
        let x = 0, y = 0, opacity = 1;
        const animate = () => {
            x += vx * 0.02;
            y += vy * 0.02;
            opacity -= 0.03;

            particle.style.transform = `translate(calc(-50% + ${x}px), calc(-50% + ${y}px))`;
            particle.style.opacity = opacity;

            if (opacity > 0) {
                requestAnimationFrame(animate);
            } else {
                particle.remove();
            }
        };
        requestAnimationFrame(animate);
    }
}

/**
 * Start the demo with theatre mode
 */
function startDemo() {
    demoRunning = true;

    // Reset trigger glow
    resetTriggerFill();

    // Enable theatre mode
    enableTheatreMode();

    // Start the shelf demo
    openShelf();
    startShelfDemo();
}

/**
 * Stop the demo and exit theatre mode
 */
function stopDemo() {
    // Stop any running timeouts
    if (demoTimeout) clearTimeout(demoTimeout);
    demoRunning = false;

    // Disable theatre mode
    disableTheatreMode();

    // Close everything
    closeShelf();

    // Reset all demo elements
    resetAllDemoElements();
}

/**
 * Enable theatre mode - fade out everything except demo area
 */
function enableTheatreMode() {
    // Disable scrolling
    document.body.style.overflow = 'hidden';

    // Get the demo section (the section containing macbook-section)
    const macbookSection = document.querySelector('.macbook-section');
    const demoSection = macbookSection?.closest('section');

    // Fade out header
    const header = document.querySelector('header');
    if (header) {
        header.style.transition = 'opacity 0.4s ease-out';
        header.style.opacity = '0';
        header.style.pointerEvents = 'none';
    }

    // Fade out footer
    const footer = document.querySelector('footer');
    if (footer) {
        footer.style.transition = 'opacity 0.4s ease-out';
        footer.style.opacity = '0';
    }

    // Fade out the features grid section (below demo) - target sections after the demo section
    const isolateSection = document.querySelector('section.isolate');
    if (isolateSection) {
        let sibling = isolateSection.nextElementSibling;
        while (sibling) {
            if (sibling.tagName === 'SECTION') {
                sibling.style.transition = 'opacity 0.4s ease-out';
                sibling.style.opacity = '0';
                sibling.style.pointerEvents = 'none';
            }
            sibling = sibling.nextElementSibling;
        }
    }

    // Morph trigger button to "Quit Demo"
    if (triggerTitle) triggerTitle.innerHTML = 'Quit Demo';
    if (triggerSubtitle) triggerSubtitle.textContent = 'Click to exit';
}

/**
 * Disable theatre mode - restore scroll, hide backdrop, restore button
 */
function disableTheatreMode() {
    // Re-enable scrolling
    document.body.style.overflow = '';

    // Get the demo section
    const macbookSection = document.querySelector('.macbook-section');
    const demoSection = macbookSection?.closest('section');

    // Restore header
    const header = document.querySelector('header');
    if (header) {
        header.style.opacity = '1';
        header.style.pointerEvents = '';
    }

    // Restore footer
    const footer = document.querySelector('footer');
    if (footer) {
        footer.style.opacity = '1';
    }

    // Restore all sections in main
    const allSections = document.querySelectorAll('main section');
    allSections.forEach(section => {
        section.style.opacity = '1';
        section.style.pointerEvents = '';
    });

    // Restore trigger button text (with mobile support)
    if (triggerTitle) {
        triggerTitle.innerHTML = `
            <span class="hidden md:inline">Hover here to demo!</span>
            <span class="md:hidden">Tap to demo!</span>
        `;
    }
    if (triggerSubtitle) triggerSubtitle.textContent = 'See PepBox in action';
}

/**
 * Reset all demo elements to initial state
 */
function resetAllDemoElements() {
    // Reset shelf files
    resetShelfFiles();

    // Reset basket
    const basket = document.getElementById('basket');
    if (basket) {
        basket.style.opacity = '0';
        basket.style.transform = 'scale(0.9)';
    }

    // Reset drag cursor
    const dragCursor = document.getElementById('dragCursor');
    if (dragCursor) {
        dragCursor.style.opacity = '0';
    }

    // Reset context menu
    if (contextMenu) {
        contextMenu.style.display = 'none';
    }

    // Reset media elements
    const scrollingTitle = document.getElementById('scrollingTitle');
    const notchMediaContent = document.getElementById('notchMediaContent');
    const expandedPlayer = document.getElementById('expandedPlayer');
    const featureShowcase = document.getElementById('featureShowcase');

    if (scrollingTitle) {
        scrollingTitle.style.opacity = '0';
        scrollingTitle.style.height = '0';
    }
    if (notchMediaContent) {
        notchMediaContent.style.opacity = '0';
    }
    if (expandedPlayer) {
        expandedPlayer.style.opacity = '0';
        expandedPlayer.style.display = 'none';
    }
    if (featureShowcase) {
        featureShowcase.style.display = 'none';
        featureShowcase.style.opacity = '0';
    }

    // Reset notch bar
    if (notchBar) {
        notchBar.style.opacity = '1';
        notchBar.style.width = '200px';
        notchBar.style.borderRadius = '0 0 20px 20px';
    }
}

/**
 * Setup shelf event handlers
 */
function setupShelfEvents() {
    // Close shelf when leaving the shelf area (but NOT during automated demo)
    shelf.addEventListener('mouseleave', () => {
        if (!demoRunning) {
            closeShelf();
        }
    });
}

/**
 * Open the shelf panel with grow animation from notch
 */
function openShelf() {
    // Start from small scale (as if emerging from notch)
    shelf.style.transition = 'none';
    shelf.style.transform = 'translateX(-50%) scaleX(0.3) scaleY(0.1)';
    shelf.style.opacity = '1';
    shelf.style.transformOrigin = 'top center';

    // Hide notch bar
    notchBar.style.opacity = '0';

    // Force reflow to apply initial state
    shelf.offsetHeight;

    // Animate to full size with spring-like easing
    shelf.style.transition = 'transform 0.4s cubic-bezier(0.34, 1.56, 0.64, 1)';
    shelf.style.transform = 'translateX(-50%) scaleX(1) scaleY(1)';
    shelf.style.pointerEvents = 'none';
}

/**
 * Close the shelf panel and stop demo - shrinks back into notch
 */
function closeShelf() {
    // Shrink back into notch (reverse of grow)
    shelf.style.transition = 'transform 0.35s cubic-bezier(0.4, 0, 0.2, 1), opacity 0.25s ease-out';
    shelf.style.transform = 'translateX(-50%) scaleX(0.3) scaleY(0.1)';
    shelf.style.opacity = '0';
    shelf.style.pointerEvents = 'none';

    // Show notch bar
    notchBar.style.opacity = '1';

    // Stop demo and reset
    if (demoTimeout) clearTimeout(demoTimeout);
    demoRunning = false;
    resetShelfFiles();

    // Reset basket and drag cursor
    const basket = document.getElementById('basket');
    const dragCursor = document.getElementById('dragCursor');
    if (basket) {
        basket.style.opacity = '0';
        basket.style.transform = 'scale(0.8)';
    }
    if (dragCursor) {
        dragCursor.style.opacity = '0';
    }
}

/**
 * Close shelf silently (during automated demo transitions)
 * Animates the shelf shrinking back into the notch bar
 */
function closeShelfSilent() {
    // Show notch bar immediately
    if (notchBar) notchBar.style.opacity = '1';

    // Animate shelf shrinking back into notch
    shelf.style.transition = 'all 0.35s cubic-bezier(0.4, 0, 0.2, 1)';
    shelf.style.transform = 'translateX(-50%) scaleX(0.4) scaleY(0.1)';
    shelf.style.opacity = '0';
    shelf.style.borderRadius = '0 0 16px 16px';
}

// Initialize when DOM is ready (handle case where DOM already loaded)
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initDemo);
} else {
    // DOM already loaded, run immediately
    initDemo();
}
