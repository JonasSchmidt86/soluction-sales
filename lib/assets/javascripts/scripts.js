/*!
    * Start Bootstrap - SB Admin v7.0.5 (https://startbootstrap.com/template/sb-admin)
    * Copyright 2013-2022 Start Bootstrap
    * Licensed under MIT (https://github.com/StartBootstrap/startbootstrap-sb-admin/blob/master/LICENSE)
    */
    // 
// Scripts
// 

window.addEventListener('DOMContentLoaded', event => {

    // Toggle the side navigation
    const sidebarToggle = document.body.querySelector('#sidebarToggle');
    if (sidebarToggle) {
        const sidebar = document.body.querySelector('#layoutSidenav_nav');
        const content = document.body.querySelector('#layoutSidenav_content');
        const desktopViewport = window.matchMedia('(min-width: 992px)');
        let wasDesktopViewport = desktopViewport.matches;

        document.body.classList.remove('sb-sidenav-toggled');

        const updateToggleState = () => {
            const isExpanded = desktopViewport.matches
                ? !document.body.classList.contains('sb-sidenav-toggled')
                : document.body.classList.contains('sb-sidenav-toggled');
            sidebarToggle.setAttribute('aria-expanded', String(isExpanded));
            sidebarToggle.setAttribute('aria-label', isExpanded ? 'Fechar navegação' : 'Abrir navegação');
        };

        const closeSidebar = () => {
            document.body.classList.remove('sb-sidenav-toggled');
            updateToggleState();
        };

        updateToggleState();
        window.addEventListener('resize', () => {
            if (desktopViewport.matches !== wasDesktopViewport) {
                wasDesktopViewport = desktopViewport.matches;
                document.body.classList.remove('sb-sidenav-toggled');
            }
            updateToggleState();
        });

        sidebarToggle.addEventListener('click', event => {
            event.preventDefault();
            document.body.classList.toggle('sb-sidenav-toggled');
            updateToggleState();
        });

        if (sidebar && content) {
            content.addEventListener('click', event => {
                if (!desktopViewport.matches &&
                    document.body.classList.contains('sb-sidenav-toggled') &&
                    event.target === content) {
                    closeSidebar();
                }
            });

            sidebar.addEventListener('click', event => {
                if (!desktopViewport.matches && event.target.closest('a.nav-link')) {
                    closeSidebar();
                }
            });

            document.addEventListener('keydown', event => {
                if (event.key === 'Escape' &&
                    !desktopViewport.matches &&
                    document.body.classList.contains('sb-sidenav-toggled')) {
                    closeSidebar();
                    sidebarToggle.focus();
                }
            });
        }
    }

    const sidebarMenu = document.querySelector('#sidebarMenuAccordion');
    if (sidebarMenu) {
        sidebarMenu.addEventListener('click', event => {
            const toggle = event.target.closest('[data-sidebar-toggle]');
            if (!toggle || !sidebarMenu.contains(toggle)) {
                return;
            }

            const section = sidebarMenu.querySelector(toggle.getAttribute('data-sidebar-toggle'));
            if (!section) {
                return;
            }

            const isOpening = !section.classList.contains('show');
            if (isOpening) {
                sidebarMenu.querySelectorAll('.collapse.show').forEach(openSection => {
                    openSection.classList.remove('show');
                    const openToggle = sidebarMenu.querySelector(
                        `[data-sidebar-toggle="#${openSection.id}"]`
                    );
                    if (openToggle) {
                        openToggle.classList.add('collapsed');
                        openToggle.setAttribute('aria-expanded', 'false');
                    }
                });
            }

            section.classList.toggle('show', isOpening);
            toggle.classList.toggle('collapsed', !isOpening);
            toggle.setAttribute('aria-expanded', String(isOpening));
        });

        const currentPath = window.location.pathname.replace(/\/+$/, '') || '/';
        const activeLink = Array.from(sidebarMenu.querySelectorAll('a.nav-link[href]')).find(link => {
            const linkPath = new URL(link.href, window.location.origin).pathname.replace(/\/+$/, '') || '/';
            return linkPath === currentPath;
        });

        if (activeLink) {
            activeLink.classList.add('active');
            activeLink.setAttribute('aria-current', 'page');

            const section = activeLink.closest('.collapse');
            if (section) {
                section.classList.add('show');
                const toggle = sidebarMenu.querySelector(`[data-sidebar-toggle="#${section.id}"]`);
                if (toggle) {
                    toggle.classList.remove('collapsed');
                    toggle.setAttribute('aria-expanded', 'true');
                }
            }
        }
    }

});
