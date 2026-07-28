(() => {
  "use strict";

  let topZ = 50;

  function bringToFront(windowElement) {
    topZ += 1;
    windowElement.style.zIndex = String(topZ);
  }

  function placeWindow(windowElement) {
    const sameId = Array.from(
      document.querySelectorAll(`[data-window-id="${CSS.escape(windowElement.dataset.windowId)}"]`)
    );
    sameId.slice(0, -1).forEach((duplicate) => duplicate.remove());

    const openCount = document.querySelectorAll(".entity-window").length - 1;
    const offset = (openCount % 6) * 28;
    windowElement.style.left = `${Math.max(16, window.innerWidth / 2 - 220 + offset)}px`;
    windowElement.style.top = `${Math.max(84, 112 + offset)}px`;
    bringToFront(windowElement);
    windowElement.querySelector("[data-window-close]")?.focus();
  }

  function initializeWindow(windowElement) {
    if (windowElement.dataset.windowReady === "true") return;
    windowElement.dataset.windowReady = "true";
    placeWindow(windowElement);

    windowElement.addEventListener("pointerdown", () => bringToFront(windowElement));
    windowElement.querySelector("[data-window-close]")?.addEventListener("click", () => {
      windowElement.remove();
    });

    const handle = windowElement.querySelector("[data-window-handle]");
    if (!handle) return;

    handle.addEventListener("pointerdown", (event) => {
      if (event.target.closest("button")) return;
      event.preventDefault();
      bringToFront(windowElement);

      const startX = event.clientX;
      const startY = event.clientY;
      const rect = windowElement.getBoundingClientRect();
      handle.setPointerCapture(event.pointerId);
      windowElement.classList.add("is-dragging");

      const move = (moveEvent) => {
        const width = windowElement.offsetWidth;
        const height = windowElement.offsetHeight;
        const left = Math.min(
          window.innerWidth - Math.min(width, 120),
          Math.max(0, rect.left + moveEvent.clientX - startX)
        );
        const top = Math.min(
          window.innerHeight - Math.min(height, 72),
          Math.max(64, rect.top + moveEvent.clientY - startY)
        );
        windowElement.style.left = `${left}px`;
        windowElement.style.top = `${top}px`;
      };

      const finish = () => {
        windowElement.classList.remove("is-dragging");
        handle.removeEventListener("pointermove", move);
        handle.removeEventListener("pointerup", finish);
        handle.removeEventListener("pointercancel", finish);
      };

      handle.addEventListener("pointermove", move);
      handle.addEventListener("pointerup", finish);
      handle.addEventListener("pointercancel", finish);
    });
  }

  function initializeWithin(root) {
    if (root.matches?.(".entity-window")) initializeWindow(root);
    root.querySelectorAll?.(".entity-window").forEach(initializeWindow);
  }

  document.addEventListener("htmx:after:swap", (event) => initializeWithin(event.detail.elt));
  document.addEventListener("htmx:after:settle", (event) => {
    if (event.detail.elt?.id === "app-main") event.detail.elt.focus({ preventScroll: true });
  });
  document.addEventListener("DOMContentLoaded", () => initializeWithin(document));
  document.addEventListener("keydown", (event) => {
    if (event.key !== "Escape") return;
    const windows = Array.from(document.querySelectorAll(".entity-window"));
    windows.sort((a, b) => Number(b.style.zIndex) - Number(a.style.zIndex));
    windows[0]?.remove();
  });
})();
